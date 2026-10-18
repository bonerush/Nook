import Foundation

func runPhrasePlanningPromptTests() {
    let script = ScriptTokenizer.tokenize("Hi, I'm Alex. Thank you for taking the time to meet with me today.")
    let prompt = PhrasePlanningPrompt.build(
        script: script,
        budget: PhraseBudget(maxWords: 6, maxCharacters: 40),
        wordsPerMinute: 138
    )
    check(prompt.contains("Hi,"), "Prompt contains the original source text")
    check(prompt.contains("lines"), "Prompt contains the line schema")
    check(prompt.contains("0...\(script.tokens.count - 1)"), "Prompt states the valid index range")
    check(prompt.contains("Never rewrite"), "Prompt carries the no-rewrite rule")
    check(prompt.contains("\"id\":0"), "Prompt includes stable token ids")
    check(prompt.contains("40 characters"), "Prompt carries the character budget")
    check(prompt.contains("14 tokens"), "Prompt states the token count")
    check(prompt.contains("untrusted data"), "Prompt treats the script as data")
    check(prompt.contains("SENTENCE GROUPS"), "Prompt groups tokens by sentence")
    check(!prompt.contains("TOKENS:"), "Prompt does not duplicate the token table")
    check(
        PhrasePlanningPrompt.systemText.contains("Never rewrite"),
        "System prompt carries the immutable no-rewrite rule"
    )
    checkEqual(PhrasePlanningPrompt.version, 5, "Prompt version is bumped with the contract")
}

private final class MockHTTPTransport: HTTPTransport {
    var capturedRequest: URLRequest?
    var statusCode = 200
    var responseData = Data()
    var error: Error?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

private func awaitResult<T>(
    _ operation: @escaping () async throws -> T
) -> Result<T, Error> {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!
    Task {
        do {
            result = .success(try await operation())
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return result
}

func runOpenAICompatibleClientTests() {
    let script = ScriptTokenizer.tokenize("Hi, I'm Alex. Thank you for taking the time to meet with me today.")
    let budget = PhraseBudget(maxWords: 6, maxCharacters: 40)
    let configuration = LLMConfiguration(
        preset: .custom,
        baseURLString: "https://example.com/v1",
        model: "test-model"
    )

    let transport = MockHTTPTransport()
    let plan = "{\"lines\":[[0,2,120]],\"emphasis\":[]}"
        let envelope: [String: Any] = [
            "choices": [
                ["message": ["content": plan]]
            ]
        ]
        transport.responseData = try! JSONSerialization.data(withJSONObject: envelope)
        let client = OpenAICompatibleClient(transport: transport)

        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .success(let raw):
            checkEqual(raw, plan, "Client returns the assistant content")
            let request = transport.capturedRequest!
            checkEqual(request.httpMethod, "POST", "Client uses POST")
            checkEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-api-key",
                "Client sends bearer key"
            )
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            checkEqual(body["model"] as? String, "test-model", "Client sends the model")
            checkEqual(body["max_tokens"] as? Int, 2_048, "Client caps output tokens")
            checkEqual(body["stream"] as? Bool, false, "Client requests a non-streaming response")
            checkEqual(
                request.value(forHTTPHeaderField: "Content-Type"),
                "application/json",
                "Client sends JSON"
            )
            checkEqual(
                request.url?.absoluteString,
                "https://example.com/v1/chat/completions",
                "Client uses the configured endpoint"
            )
            checkEqual(request.timeoutInterval, 60, "Client uses a 60s timeout")
        case .failure(let error):
            check(false, "Client success path failed: \(error)")
        }

    do {
        let transport = MockHTTPTransport()
        transport.statusCode = 401
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .failure(PhrasePlanningError.unauthorized):
            check(true, "401 maps to unauthorized")
        case .failure(let error):
            check(false, "401 mapped incorrectly: \(error)")
        case .success:
            check(false, "401 must fail")
        }
    }

    do {
        let transport = MockHTTPTransport()
        transport.error = URLError(.timedOut)
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .failure(PhrasePlanningError.timeout):
            check(true, "Timeout maps to timeout")
        case .failure(let error):
            check(false, "Timeout mapped incorrectly: \(error)")
        case .success:
            check(false, "Timeout must fail")
        }
    }

    // Keyless local endpoints are allowed and omit the Authorization header.
    do {
        let transport = MockHTTPTransport()
        let envelope: [String: Any] = [
            "choices": [["message": ["content": plan]]]
        ]
        transport.responseData = try! JSONSerialization.data(withJSONObject: envelope)
        let localConfiguration = LLMConfiguration(
            preset: .custom,
            baseURLString: "http://127.0.0.1:8080/v1",
            model: "local-model"
        )
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: localConfiguration,
                apiKey: ""
            )
        }
        switch result {
        case .success:
            check(
                transport.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil,
                "Keyless local request omits Authorization"
            )
        case .failure(let error):
            check(false, "Keyless local request failed: \(error)")
        }
    }

    do {
        let transport = MockHTTPTransport()
        transport.statusCode = 403
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .failure(PhrasePlanningError.unauthorized):
            check(true, "403 maps to unauthorized")
        case .failure(let error):
            check(false, "403 mapped incorrectly: \(error)")
        case .success:
            check(false, "403 must fail")
        }
    }

    do {
        let transport = MockHTTPTransport()
        transport.statusCode = 429
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .failure(PhrasePlanningError.rateLimited):
            check(true, "429 maps to rateLimited")
        case .failure(let error):
            check(false, "429 mapped incorrectly: \(error)")
        case .success:
            check(false, "429 must fail")
        }
    }

    do {
        let transport = MockHTTPTransport()
        transport.error = URLError(.cannotConnectToHost)
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .failure(PhrasePlanningError.network):
            check(true, "Network failure maps to network")
        case .failure(let error):
            check(false, "Network failure mapped incorrectly: \(error)")
        case .success:
            check(false, "Network failure must fail")
        }
    }

    do {
        let transport = MockHTTPTransport()
        let envelope: [String: Any] = [
            "choices": [
                [
                    "message": ["content": plan],
                    "finish_reason": "length"
                ]
            ]
        ]
        transport.responseData = try! JSONSerialization.data(withJSONObject: envelope)
        let client = OpenAICompatibleClient(transport: transport)
        let result = awaitResult {
            try await client.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: 138,
                configuration: configuration,
                apiKey: "test-api-key"
            )
        }
        switch result {
        case .failure(PhrasePlanningError.truncated):
            check(true, "finish_reason length maps to truncated")
        case .failure(let error):
            check(false, "Truncated response mapped incorrectly: \(error)")
        case .success:
            check(false, "Truncated response must fail")
        }
    }

}
