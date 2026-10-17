import Foundation

public protocol PhrasePlanRemoteFetching {
    func fetchPlanText(
        script: SpeechScript,
        budget: PhraseBudget,
        wordsPerMinute: Int,
        configuration: LLMConfiguration,
        apiKey: String
    ) async throws -> String
}

extension OpenAICompatibleClient: PhrasePlanRemoteFetching {}

public enum AIPlanFailure: Error, Equatable {
    case disabled
    case unauthorized
    case rateLimited
    case timeout
    case network
    case truncated
    case cancelled
    case server(Int)
    case invalidResponse
    case invalidPlan
    case emptyScript
    case tooLong
}

public enum AIPlanResult: Equatable {
    case disabled
    case cached(PhrasePlan)
    case fresh(PhrasePlan)
    case failed(AIPlanFailure)
}

public final class AIPlanningCoordinator {
    private let fetcher: PhrasePlanRemoteFetching
    private let client: OpenAICompatibleClient
    private let cache: PhrasePlanCache

    public init(
        fetcher: PhrasePlanRemoteFetching,
        client: OpenAICompatibleClient,
        cache: PhrasePlanCache
    ) {
        self.fetcher = fetcher
        self.client = client
        self.cache = cache
    }

    public func prepare(
        script: SpeechScript,
        options: PromptBuildOptions,
        configuration: LLMConfiguration,
        apiKey: String
    ) async -> AIPlanResult {
        guard configuration.isComplete else {
            return .disabled
        }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty || configuration.isLocalEndpoint else {
            return .disabled
        }
        guard !script.tokens.isEmpty else {
            return .failed(.emptyScript)
        }
        guard script.sourceText.count <= 20_000 else {
            return .failed(.tooLong)
        }

        let budget = PhraseBudget.derive(
            fontSize: options.fontSize,
            cardWidth: options.cardWidth
        )
        let cacheKey = PhrasePlanCacheKey(
            model: configuration.model,
            promptVersion: PhrasePlanningPrompt.version,
            scriptHash: PhrasePlanCacheKey.hash(script.sourceText),
            tokenizerVersion: script.tokenizerVersion,
            wordsPerMinute: Int(options.wordsPerMinute.rounded()),
            budgetWords: budget.maxWords,
            budgetCharacters: budget.maxCharacters
        )
        if let cached = cache.load(for: cacheKey) {
            return .cached(cached)
        }

        do {
            let raw = try await fetcher.fetchPlanText(
                script: script,
                budget: budget,
                wordsPerMinute: Int(options.wordsPerMinute.rounded()),
                configuration: configuration,
                apiKey: key
            )
            let plan: PhrasePlan
            do {
                plan = try Self.decodePlan(raw, script: script, budget: budget)
            } catch {
                return .failed(.invalidPlan)
            }
            cache.save(plan, for: cacheKey)
            return .fresh(plan)
        } catch {
            return .failed(Self.map(error))
        }
    }

    public func testConnection(
        configuration: LLMConfiguration,
        apiKey: String,
        sample: SpeechScript,
        wordsPerMinute: Int
    ) async throws {
        let budget = PhraseBudget.derive(fontSize: 30, cardWidth: 680)
        _ = try await client.fetchPlanText(
            script: sample,
            budget: budget,
            wordsPerMinute: wordsPerMinute,
            configuration: configuration,
            apiKey: apiKey
        )
    }

    public static func decodePlan(
        _ raw: String,
        script: SpeechScript,
        budget: PhraseBudget
    ) throws -> PhrasePlan {
        struct Wire: Decodable {
            let lines: [[Int]]
            let emphasis: [Int]?
        }

        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fence = "\u{60}\u{60}\u{60}"
        if text.hasPrefix(fence) {
            var lines = text.components(separatedBy: "\n")
            if !lines.isEmpty { lines.removeFirst() }
            if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix(fence) == true {
                lines.removeLast()
            }
            text = lines.joined(separator: "\n")
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"),
           start <= end {
            text = String(text[start...end])
        }

        guard let data = text.data(using: .utf8),
              let wire = try? JSONDecoder().decode(Wire.self, from: data),
              !wire.lines.isEmpty else {
            throw PhrasePlanIssue.emptyPlan
        }

        var groups: [PhraseGroup] = []
        groups.reserveCapacity(wire.lines.count)
        for line in wire.lines {
            guard line.count == 2 || line.count == 3 else {
                throw PhrasePlanIssue.emptyPlan
            }
            let start = line[0]
            let end = line[1]
            let pause = line.count == 3 ? line[2] : nil
            guard start >= 0, end >= start, end < script.tokens.count else {
                throw PhrasePlanIssue.outOfBounds(max(start, end))
            }
            groups.append(
                PhraseGroup(
                    start: start,
                    end: end,
                    pauseAfterMs: pause
                )
            )
        }
        let rawPlan = PhrasePlan(
            groups: groups,
            emphasis: Set(wire.emphasis ?? []),
            source: .ai
        )
        switch PhrasePlanValidator.validate(rawPlan, against: script, budget: budget) {
        case .success(let normalized):
            return normalized
        case .failure(let issue):
            throw issue
        }
    }

    private static func map(_ error: Error) -> AIPlanFailure {
        if let phraseError = error as? PhrasePlanningError {
            switch phraseError {
            case .notConfigured:
                return .disabled
            case .unauthorized:
                return .unauthorized
            case .rateLimited:
                return .rateLimited
            case .timeout:
                return .timeout
            case .network:
                return .network
            case .truncated:
                return .truncated
            case .cancelled:
                return .cancelled
            case .server(let code):
                return .server(code)
            case .invalidResponse:
                return .invalidResponse
            case .invalidPlan:
                return .invalidPlan
            }
        }
        if error is PhrasePlanIssue {
            return .invalidPlan
        }
        return .invalidResponse
    }
}
