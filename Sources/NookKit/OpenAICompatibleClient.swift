import Foundation

public enum PhrasePlanningError: Error, Equatable {
    case notConfigured
    case unauthorized
    case rateLimited
    case timeout
    case network
    case truncated
    case cancelled
    case server(Int)
    case invalidResponse
    case invalidPlan
}

public final class OpenAICompatibleClient {
    private let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func fetchPlanText(
        script: SpeechScript,
        budget: PhraseBudget,
        wordsPerMinute: Int,
        configuration: LLMConfiguration,
        apiKey: String
    ) async throws -> String {
        guard let endpoint = configuration.endpointURL else {
            throw PhrasePlanningError.notConfigured
        }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty || configuration.isLocalEndpoint else {
            throw PhrasePlanningError.notConfigured
        }

        let content = PhrasePlanningPrompt.build(
            script: script,
            budget: budget,
            wordsPerMinute: wordsPerMinute
        )
        let outputBudget = max(900, min(4_000, script.tokens.count * 6))
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                [
                    "role": "system",
                    "content": PhrasePlanningPrompt.systemText
                ],
                ["role": "user", "content": content]
            ],
            "temperature": 0.2,
            "max_tokens": outputBudget,
            "stream": false
        ]
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw PhrasePlanningError.invalidResponse
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .timedOut {
            throw PhrasePlanningError.timeout
        } catch is CancellationError {
            throw PhrasePlanningError.cancelled
        } catch let error as URLError {
            if error.code == .cancelled { throw PhrasePlanningError.cancelled }
            throw PhrasePlanningError.network
        } catch {
            throw PhrasePlanningError.invalidResponse
        }

        switch response.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw PhrasePlanningError.unauthorized
        case 429:
            throw PhrasePlanningError.rateLimited
        default:
            throw PhrasePlanningError.server(response.statusCode)
        }

        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
                let finishReason: String?

                enum CodingKeys: String, CodingKey {
                    case message
                    case finishReason = "finish_reason"
                }
            }
            let choices: [Choice]
        }

        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let choice = envelope.choices.first else {
                throw PhrasePlanningError.invalidResponse
            }
            if choice.finishReason == "length" {
                throw PhrasePlanningError.truncated
            }
            let text = choice.message.content
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PhrasePlanningError.invalidResponse
            }
            return text
        } catch let error as PhrasePlanningError {
            throw error
        } catch {
            throw PhrasePlanningError.invalidResponse
        }
    }
}
