import Foundation

private final class MockPhraseFetcher: PhrasePlanRemoteFetching {
    var raw: String?
    var error: Error?
    var callCount = 0
    var lastConfiguration: LLMConfiguration?

    func fetchPlanText(
        script: SpeechScript,
        budget: PhraseBudget,
        wordsPerMinute: Int,
        configuration: LLMConfiguration,
        apiKey: String
    ) async throws -> String {
        callCount += 1
        lastConfiguration = configuration
        if let error { throw error }
        return raw ?? "{\"lines\":[],\"emphasis\":[]}"
    }
}

private func awaitCoordinatorResult<T>(
    _ operation: @escaping () async -> T
) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: T!
    Task {
        result = await operation()
        semaphore.signal()
    }
    semaphore.wait()
    return result
}

private func coordinator(
    directory: URL,
    fetcher: MockPhraseFetcher
) -> AIPlanningCoordinator {
    let cache = PhrasePlanCache(directory: directory, maxEntries: 4)
    return AIPlanningCoordinator(
        fetcher: fetcher,
        client: OpenAICompatibleClient(),
        cache: cache
    )
}

private let coordinatorConfig = LLMConfiguration(
    preset: .custom,
    baseURLString: "https://example.com/v1",
    model: "coordinator-model"
)

private let coordinatorScript = ScriptTokenizer.tokenize(
    "Hi, I'm Alex. Thank you for taking the time to meet with me today."
)

private let coordinatorOptions = PromptBuildOptions(
    wordsPerMinute: 138,
    fontSize: 30,
    cardWidth: 680
)

private let coordinatorPlanJSON = "{\"lines\":[[0,2,120],[3,8,260],[9,13,0]],\"emphasis\":[4]}"

func runAIPlanningCoordinatorTests() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("nook-coordinator-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    let fetcher = MockPhraseFetcher()
    fetcher.raw = coordinatorPlanJSON
    let service = coordinator(directory: directory, fetcher: fetcher)

    let first = awaitCoordinatorResult {
        await service.prepare(
            script: coordinatorScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: "test-api-key"
        )
    }
    switch first {
    case .fresh(let plan):
        checkEqual(plan.groups.count, 3, "Coordinator parses a fresh AI plan")
        checkEqual(plan.source, .ai, "Coordinator labels fresh plans as AI")
    case .cached:
        check(false, "First fetch must not be reported as cached")
    case .failed(let failure):
        check(false, "Fresh coordinator fetch failed: \(failure)")
    case .disabled:
        check(false, "Fresh coordinator fetch was unexpectedly disabled")
    }
    checkEqual(fetcher.callCount, 1, "Fresh fetch calls the network once")
    checkEqual(fetcher.lastConfiguration?.model, "coordinator-model", "Coordinator uses the configured model")

    let second = awaitCoordinatorResult {
        await service.prepare(
            script: coordinatorScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: "test-api-key"
        )
    }
    switch second {
    case .cached(let plan):
        checkEqual(plan.groups.count, 3, "Second request returns the cached plan")
    case .fresh:
        check(false, "Second request must be served from cache")
    case .failed(let failure):
        check(false, "Cached coordinator fetch failed: \(failure)")
    case .disabled:
        check(false, "Cached coordinator fetch was unexpectedly disabled")
    }
    checkEqual(fetcher.callCount, 1, "Cache hit does not call the network again")

    let emptyScript = ScriptTokenizer.tokenize("   ")
    let empty = awaitCoordinatorResult {
        await service.prepare(
            script: emptyScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: "test-api-key"
        )
    }
    checkEqual(empty, .failed(.emptyScript), "Empty scripts fail before networking")

    let longText = String(repeating: "word ", count: 4_001)
    let longScript = ScriptTokenizer.tokenize(longText)
    let tooLong = awaitCoordinatorResult {
        await service.prepare(
            script: longScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: "test-api-key"
        )
    }
    checkEqual(tooLong, .failed(.tooLong), "Oversized scripts are rejected before networking")

    let disabledConfig = LLMConfiguration(
        preset: .custom,
        baseURLString: "https://example.com/v1",
        model: ""
    )
    let disabled = awaitCoordinatorResult {
        await service.prepare(
            script: coordinatorScript,
            options: coordinatorOptions,
            configuration: disabledConfig,
            apiKey: "test-api-key"
        )
    }
    checkEqual(disabled, .disabled, "Incomplete configuration is disabled")

    let noKey = awaitCoordinatorResult {
        await service.prepare(
            script: coordinatorScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: ""
        )
    }
    checkEqual(noKey, .disabled, "Missing API key is disabled")

    let malformedFetcher = MockPhraseFetcher()
    malformedFetcher.raw = "{\"lines\":[]}"
    let malformedService = coordinator(
        directory: directory.appendingPathComponent("malformed"),
        fetcher: malformedFetcher
    )
    let malformed = awaitCoordinatorResult {
        await malformedService.prepare(
            script: coordinatorScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: "test-api-key"
        )
    }
    checkEqual(malformed, .failed(.invalidPlan), "Malformed plans are rejected")

    let unauthorizedFetcher = MockPhraseFetcher()
    unauthorizedFetcher.error = PhrasePlanningError.unauthorized
    let unauthorizedService = coordinator(
        directory: directory.appendingPathComponent("unauthorized"),
        fetcher: unauthorizedFetcher
    )
    let unauthorized = awaitCoordinatorResult {
        await unauthorizedService.prepare(
            script: coordinatorScript,
            options: coordinatorOptions,
            configuration: coordinatorConfig,
            apiKey: "test-api-key"
        )
    }
    checkEqual(unauthorized, .failed(.unauthorized), "401 maps to unauthorized")
}