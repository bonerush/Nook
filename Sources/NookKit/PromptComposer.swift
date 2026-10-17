import Foundation

public enum PromptComposer {
    public static func makeDocument(
        script: SpeechScript,
        plan: PhrasePlan,
        options: PromptBuildOptions
    ) -> PromptDocument {
        let base = PromptScriptBuilder.build(from: script.sourceText, options: options)
        guard !script.tokens.isEmpty,
              base.words.count == script.tokens.count,
              base.words.map(\.text) == script.tokens.map(\.text) else {
            return base
        }

        let budget = PhraseBudget.derive(
            fontSize: options.fontSize,
            cardWidth: options.cardWidth
        )
        guard case .success(let normalized) = PhrasePlanValidator.validate(
            plan,
            against: script,
            budget: budget
        ) else {
            return base
        }
        var laidOutGroups: [PhraseGroup] = []
        for group in normalized.groups {
            let pieces = PhraseLayout.split(
                tokens: script.tokens,
                range: group.start...group.end,
                fontSize: options.fontSize,
                maxWidth: options.availableWidth
            )
            for (index, piece) in pieces.enumerated() {
                laidOutGroups.append(
                    PhraseGroup(
                        start: piece.lowerBound,
                        end: piece.upperBound,
                        pauseAfterMs: index == pieces.count - 1 ? group.pauseAfterMs : nil
                    )
                )
            }
        }
        let laidOut = PhrasePlan(
            groups: laidOutGroups,
            emphasis: normalized.emphasis,
            source: normalized.source
        )
        return composeDocument(
            script: script,
            plan: laidOut,
            base: base,
            options: options
        )
    }

    private static func composeDocument(
        script: SpeechScript,
        plan: PhrasePlan,
        base: PromptDocument,
        options: PromptBuildOptions
    ) -> PromptDocument {
        let words = base.words
        let count = words.count
        var durations: [TimeInterval] = []
        durations.reserveCapacity(count)
        for index in 0..<count {
            var duration = max(0.001, words[index].duration)
            if plan.emphasis.contains(index) {
                duration *= 1.06
            }
            durations.append(duration)
        }

        var basePauses: [TimeInterval] = Array(repeating: 0, count: count)
        if count > 1 {
            for index in 0..<(count - 1) {
                basePauses[index] = max(0, words[index + 1].start - words[index].end)
            }
        }

        var planPauses: [Int: TimeInterval] = [:]
        if plan.groups.count > 1 {
            for group in plan.groups.dropLast() {
                if let milliseconds = group.pauseAfterMs {
                    planPauses[group.end] = TimeInterval(milliseconds) / 1000
                }
            }
        }

        var lineIndexForWord = Array(repeating: 0, count: count)
        for (lineIndex, group) in plan.groups.enumerated() {
            for wordIndex in group.start...group.end {
                lineIndexForWord[wordIndex] = lineIndex
            }
        }

        var newWords: [PromptWord] = []
        newWords.reserveCapacity(count)
        var cursor = max(0, options.leadIn)

        for index in 0..<count {
            let start = cursor
            let duration = durations[index]
            let end = start + duration
            var pause = basePauses[index]
            if index < count - 1, let extra = planPauses[index] {
                pause = max(pause, extra)
            }
            cursor = end + pause
            newWords.append(
                PromptWord(
                    id: index,
                    text: script.tokens[index].text,
                    start: start,
                    end: end,
                    lineIndex: lineIndexForWord[index],
                    sentenceIndex: script.tokens[index].sentenceIndex
                )
            )
        }

        var lines: [PromptLine] = []
        lines.reserveCapacity(plan.groups.count)
        for (lineIndex, group) in plan.groups.enumerated() {
            let range = group.start..<(group.end + 1)
            let lineWords = newWords[range]
            let startsSentence = group.start == 0
                || script.tokens[group.start].sentenceIndex != script.tokens[group.start - 1].sentenceIndex
            lines.append(
                PromptLine(
                    id: lineIndex,
                    wordRange: range,
                    text: lineWords.map(\.text).joined(separator: " "),
                    startTime: lineWords.first?.start ?? 0,
                    endTime: lineWords.last?.end ?? 0,
                    sentenceIndex: script.tokens[group.start].sentenceIndex,
                    startsSentence: startsSentence
                )
            )
        }

        let lastEnd = newWords.last?.end ?? options.leadIn
        let totalDuration = max(lastEnd + options.trailingHold, options.leadIn)
        return PromptDocument(
            words: newWords,
            lines: lines,
            totalDuration: totalDuration,
            totalWords: newWords.count,
            sentenceCount: script.sentenceCount,
            paragraphCount: script.paragraphCount,
            wordsPerMinute: options.wordsPerMinute,
            leadIn: options.leadIn,
            planSource: plan.source
        )
    }
}
