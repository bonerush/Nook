import Foundation

public enum PhrasePlanningPrompt {
    public static let version = 1

    public static func build(
        script: SpeechScript,
        budget: PhraseBudget,
        wordsPerMinute: Int
    ) -> String {
        let tokenObjects: [[String: Any]] = script.tokens.map {
            ["id": $0.id, "text": $0.text]
        }
        let tokenData = (try? JSONSerialization.data(
            withJSONObject: tokenObjects,
            options: [.sortedKeys]
        )) ?? Data("[]".utf8)
        let tokenJSON = String(data: tokenData, encoding: .utf8) ?? "[]"

        return """
        You are planning phrase breaks for a teleprompter read aloud at \(wordsPerMinute) WPM.
        Never rewrite, translate, reorder, add, or remove words. The only valid indexes are 0...\(max(0, script.tokens.count - 1)).
        Return JSON only, with this exact shape:
        {"lines":[[START,END,PAUSE_MS],...],"emphasis":[INDEX,...]}
        Rules:
        - Every token index must appear exactly once across the lines, in order.
        - A line may not cross a sentence boundary.
        - Aim for natural spoken phrases, usually 3 to \(budget.maxWords) words.
        - PAUSE_MS is an optional integer from 0 to 400 at the end of a line; use 0 when no extra pause is needed.
        - Emphasis indexes are optional; choose at most three important words.
        - Do not return markdown fences or commentary.

        TOKENS:
        \(tokenJSON)
        """
    }
}
