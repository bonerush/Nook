import Foundation

public enum PhrasePlanningError: Error, Equatable {
    case notConfigured
    case unauthorized
    case rateLimited
    case timeout
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
        guard !key.isEmpty else {
            throw PhrasePlanningError.notConfigured
        }

        let content = PhrasePlanningPrompt.build(
            script: script,
            budget: budget,
            wordsPerMinute: wordsPerMinute
        )
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "system", "content": "You return strict JSON only."],
                ["role": "user", "content": content]
            ],
            "temperature": 0.2,
            "max_tokens": 900
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
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .timedOut {
            throw PhrasePlanningError.timeout
        } catch {
            throw PhrasePlanningError.invalidResponse
        }

        switch response.statusCode {
        case 200..<300:
            break
        case 401:
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
            }
            let choices: [Choice]
        }

        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let text = envelope.choices.first?.message.content,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
