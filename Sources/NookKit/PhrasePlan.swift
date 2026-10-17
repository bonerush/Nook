import Foundation

public enum PhrasePlanSource: String, Codable, Equatable {
    case local
    case ai
}

public struct PhraseGroup: Equatable, Codable {
    public var start: Int
    public var end: Int
    public var pauseAfterMs: Int?

    public init(start: Int, end: Int, pauseAfterMs: Int? = nil) {
        self.start = start
        self.end = end
        self.pauseAfterMs = pauseAfterMs
    }

    public var wordCount: Int { max(0, end - start + 1) }
}

public struct PhrasePlan: Equatable, Codable {
    public var groups: [PhraseGroup]
    public var emphasis: Set<Int>
    public var source: PhrasePlanSource

    public init(
        groups: [PhraseGroup],
        emphasis: Set<Int> = [],
        source: PhrasePlanSource
    ) {
        self.groups = groups
        self.emphasis = emphasis
        self.source = source
    }
}

public struct PhraseBudget: Equatable {
    public var maxWords: Int
    public var maxCharacters: Int

    public init(maxWords: Int = 12, maxCharacters: Int = 48) {
        self.maxWords = max(2, maxWords)
        self.maxCharacters = max(12, maxCharacters)
    }

    public static func derive(fontSize: CGFloat, cardWidth: CGFloat) -> PhraseBudget {
        let usable = max(240, cardWidth - PromptMetrics.textInset * 2)
        let characters = max(18, min(64, Int(usable / max(1, fontSize * 0.52))))
        return PhraseBudget(
            maxWords: max(4, min(12, characters / 4)),
            maxCharacters: characters
        )
    }
}

public enum PhrasePlanIssue: Error, Equatable {
    case emptyPlan
    case outOfBounds(Int)
    case missingIndex(Int)
    case overlapAt(Int)
    case crossesSentence(Int)
    case exceedsWordBudget(Int)
    case exceedsCharacterBudget(Int)
}

public enum PhrasePlanValidator {
    public static func validate(
        _ plan: PhrasePlan,
        against script: SpeechScript,
        budget: PhraseBudget
    ) -> Result<PhrasePlan, PhrasePlanIssue> {
        guard !script.tokens.isEmpty, !plan.groups.isEmpty else {
            return .failure(.emptyPlan)
        }

        // Repair gaps and out-of-order groups before checking coverage. Missing
        // ranges become plain groups; the composer will measure and split them.
        let sortedGroups = plan.groups.sorted { lhs, rhs in
            if lhs.start == rhs.start { return lhs.end < rhs.end }
            return lhs.start < rhs.start
        }
        var covered: [PhraseGroup] = []
        var expectedStart = 0
        for group in sortedGroups {
            guard group.start >= 0, group.end < script.tokens.count, group.start <= group.end else {
                return .failure(.outOfBounds(max(group.start, group.end)))
            }
            if group.start < expectedStart {
                return .failure(.overlapAt(group.start))
            }
            if group.start > expectedStart {
                covered.append(
                    PhraseGroup(
                        start: expectedStart,
                        end: group.start - 1,
                        pauseAfterMs: nil
                    )
                )
            }
            covered.append(group)
            expectedStart = group.end + 1
        }
        if expectedStart < script.tokens.count {
            covered.append(
                PhraseGroup(
                    start: expectedStart,
                    end: script.tokens.count - 1,
                    pauseAfterMs: nil
                )
            )
        }

        // Split groups that cross a sentence boundary. The original pause
        // stays on the last fragment only.
        var repaired: [PhraseGroup] = []
        for group in covered {
            var fragmentStart = group.start
            var previousSentence = script.tokens[fragmentStart].sentenceIndex
            if group.start < group.end {
                for index in (group.start + 1)...group.end {
                    let sentence = script.tokens[index].sentenceIndex
                    if sentence != previousSentence {
                        repaired.append(
                            PhraseGroup(
                                start: fragmentStart,
                                end: index - 1,
                                pauseAfterMs: nil
                            )
                        )
                        fragmentStart = index
                        previousSentence = sentence
                    }
                }
            }
            repaired.append(
                PhraseGroup(
                    start: fragmentStart,
                    end: group.end,
                    pauseAfterMs: group.pauseAfterMs
                )
            )
        }

        // Local plans come from the measured legacy line breaker. Trust their
        // groups; only AI plans get orphan cleanup.
        var merged: [PhraseGroup] = repaired
        if plan.source == .ai {
            var cleaned: [PhraseGroup] = []
            var index = 0
            while index < repaired.count {
                var group = repaired[index]
                if group.wordCount == 1 {
                    if let previous = cleaned.last,
                       previous.end + 1 == group.start,
                       script.tokens[previous.end].sentenceIndex == script.tokens[group.start].sentenceIndex {
                        let combined = combine(previous, group, tokens: script.tokens)
                        if fits(combined, budget: budget, tokens: script.tokens) {
                            cleaned[cleaned.count - 1] = combined
                            index += 1
                            continue
                        }
                    }
                    if index + 1 < repaired.count {
                        let next = repaired[index + 1]
                        if group.end + 1 == next.start,
                           script.tokens[group.start].sentenceIndex == script.tokens[next.start].sentenceIndex {
                            let combined = combine(group, next, tokens: script.tokens)
                            if fits(combined, budget: budget, tokens: script.tokens) {
                                group = combined
                                index += 1
                                cleaned.append(group)
                                index += 1
                                continue
                            }
                        }
                    }
                }
                cleaned.append(group)
                index += 1
            }
            merged = cleaned
        }

        // Clamp pauses and filter emphasis indexes. Invalid emphasis is never
        // fatal; it is simply not part of the plan.
        let clamped = merged.map { group -> PhraseGroup in
            var copy = group
            if let pause = group.pauseAfterMs {
                copy.pauseAfterMs = min(400, max(0, pause))
            }
            return copy
        }
        let validEmphasis = plan.emphasis.filter { $0 >= 0 && $0 < script.tokens.count }
        return .success(
            PhrasePlan(
                groups: clamped,
                emphasis: validEmphasis,
                source: plan.source
            )
        )
    }

    public static func pauseMilliseconds(for token: SpeechToken) -> Int {
        if token.isSentenceEnd {
            return 550
        }
        let trimmed = token.text.trimmingCharacters(
            in: CharacterSet(charactersIn: "\"'”’)]}")
        )
        switch trimmed.last {
        case ",":
            return 180
        case ";", ":":
            return 270
        case "—", "–":
            return 300
        case "…":
            return 420
        default:
            if trimmed.contains("...") { return 420 }
            return 0
        }
    }

    private static func combine(
        _ lhs: PhraseGroup,
        _ rhs: PhraseGroup,
        tokens: [SpeechToken]
    ) -> PhraseGroup {
        PhraseGroup(
            start: lhs.start,
            end: rhs.end,
            pauseAfterMs: rhs.pauseAfterMs
        )
    }

    private static func fits(
        _ group: PhraseGroup,
        budget: PhraseBudget,
        tokens: [SpeechToken]
    ) -> Bool {
        guard group.start >= 0, group.end < tokens.count, group.start <= group.end else {
            return false
        }
        let words = tokens[group.start...group.end]
        let characters = words.map(\.text).joined(separator: " ").count
        return words.count <= budget.maxWords && characters <= budget.maxCharacters
    }
}
