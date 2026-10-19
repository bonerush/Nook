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
        let reasoningActive = configuration.supportsReasoning
            && configuration.reasoningEnabled
        // Reasoning tokens are part of the completion budget: DeepSeek Flash
        // can emit thousands of reasoning tokens before the JSON. The model's
        // maximum output is 384K, so leave ample room and only charge what is generated.
        let outputBudget: Int
        if reasoningActive {
            outputBudget = max(8_192, min(65_536, script.tokens.count * 64))
        } else {
            outputBudget = max(2_048, min(8_192, script.tokens.count * 12))
        }

        var body: [String: Any] = [
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
        if configuration.supportsReasoning {
            body["thinking"] = [
                "type": reasoningActive ? "enabled" : "disabled"
            ]
            if reasoningActive {
                body["reasoning_effort"] = configuration.reasoningEffort.rawValue
                body["response_format"] = ["type": "json_object"]
            }
        }
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw PhrasePlanningError.invalidResponse
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // Reasoning is slower than a plain completion; stream=false means the
        // first response byte arrives after all reasoning and JSON are done.
        request.timeoutInterval = reasoningActive ? 180 : 60
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
            recordTransportFailure(
                endpoint: endpoint,
                configuration: configuration,
                outputBudget: outputBudget,
                error: error
            )
            throw PhrasePlanningError.timeout
        } catch is CancellationError {
            throw PhrasePlanningError.cancelled
        } catch let error as URLError {
            recordTransportFailure(
                endpoint: endpoint,
                configuration: configuration,
                outputBudget: outputBudget,
                error: error
            )
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
            struct Usage: Decodable {
                let promptTokens: Int?
                let completionTokens: Int?

                enum CodingKeys: String, CodingKey {
                    case promptTokens = "prompt_tokens"
                    case completionTokens = "completion_tokens"
                }
            }

            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                    let reasoningContent: String?

                    enum CodingKeys: String, CodingKey {
                        case content
                        case reasoningContent = "reasoning_content"
                    }
                }
                let message: Message
                let finishReason: String?

                enum CodingKeys: String, CodingKey {
                    case message
                    case finishReason = "finish_reason"
                }
            }
            let choices: [Choice]
            let usage: Usage?
        }

        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let choice = envelope.choices.first else {
                throw PhrasePlanningError.invalidResponse
            }
            if choice.finishReason == "length" {
                recordTruncation(
                    endpoint: endpoint,
                    configuration: configuration,
                    outputBudget: outputBudget,
                    promptTokens: envelope.usage?.promptTokens,
                    completionTokens: envelope.usage?.completionTokens,
                    reasoningCharacters: choice.message.reasoningContent?.count ?? 0,
                    contentCharacters: choice.message.content.count
                )
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

    /// Metadata-only diagnostic for a transport failure. It never records the
    /// script, request headers, response body, or API key.
    private func recordTransportFailure(
        endpoint: URL,
        configuration: LLMConfiguration,
        outputBudget: Int,
        error: URLError
    ) {
        writeDiagnostic(
            "transport-error time=\(ISO8601DateFormatter().string(from: Date())) " +
            "host=\(endpoint.host ?? "?") model=\(configuration.model) " +
            "requested=\(outputBudget) code=\(error.code.rawValue) " +
            "description=\(error.localizedDescription)"
        )
    }

    /// Metadata-only diagnostic. It never records the script, response body,
    /// or API key; it exists so a truncated provider response can be debugged.
    private func recordTruncation(
        endpoint: URL,
        configuration: LLMConfiguration,
        outputBudget: Int,
        promptTokens: Int?,
        completionTokens: Int?,
        reasoningCharacters: Int,
        contentCharacters: Int
    ) {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Nook", isDirectory: true)
        guard let directory else { return }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "time=\(stamp) host=\(endpoint.host ?? "?") model=\(configuration.model) reasoning=\(configuration.reasoningEnabled)/\(configuration.reasoningEffort.rawValue) requested=\(outputBudget) prompt=\(promptTokens ?? -1) completion=\(completionTokens ?? -1) reasoningChars=\(reasoningCharacters) contentChars=\(contentCharacters)\n"
        writeDiagnostic(line.trimmingCharacters(in: .newlines))
    }

    private func writeDiagnostic(_ line: String) {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Nook", isDirectory: true)
        guard let directory else { return }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("ai-debug.log")
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: [.atomic])
        }
    }
}
