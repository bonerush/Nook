import AppKit
import Foundation

public enum PhraseLayout {
    public static func measure(
        tokens: [SpeechToken],
        range: ClosedRange<Int>,
        fontSize: CGFloat
    ) -> CGFloat {
        guard !tokens.isEmpty, range.lowerBound >= 0, range.upperBound < tokens.count else {
            return 0
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let count = range.upperBound - range.lowerBound + 1
        var width: CGFloat = 0
        for index in range {
            width += ceil((tokens[index].text as NSString).size(withAttributes: [.font: font]).width)
        }
        width += PromptMetrics.wordSpacing(fontSize: fontSize) * CGFloat(max(0, count - 1))
        return width
    }

    public static func split(
        tokens: [SpeechToken],
        range: ClosedRange<Int>,
        fontSize: CGFloat,
        maxWidth: CGFloat
    ) -> [ClosedRange<Int>] {
        guard !tokens.isEmpty, range.lowerBound >= 0, range.upperBound < tokens.count else {
            return []
        }
        guard range.lowerBound < range.upperBound else {
            return [range]
        }
        guard measure(tokens: tokens, range: range, fontSize: fontSize) > maxWidth else {
            return [range]
        }

        var bestIndex: Int?
        var bestScore = -Double.greatestFiniteMagnitude
        for index in range.lowerBound..<range.upperBound {
            let left = range.lowerBound...index
            let leftWidth = measure(tokens: tokens, range: left, fontSize: fontSize)
            guard leftWidth <= maxWidth else { break }

            var score = Double(leftWidth) / Double(max(1, maxWidth)) * 100
            if endsClause(tokens[index].text) {
                score += 1_000
            }
            if index + 1 <= range.upperBound, startsClause(tokens[index + 1].text) {
                score += 200
            }
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        let splitIndex = bestIndex ?? range.lowerBound
        let head = range.lowerBound...splitIndex
        guard splitIndex < range.upperBound else { return [head] }
        let tail = (splitIndex + 1)...range.upperBound
        let tailParts = split(
            tokens: tokens,
            range: tail,
            fontSize: fontSize,
            maxWidth: maxWidth
        )
        return [head] + tailParts
    }

    static func endsClause(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(
            in: CharacterSet(charactersIn: "\"'”’)]}")
        )
        guard let last = trimmed.last else { return false }
        return ",;:.!?—–…".contains(last)
    }

    private static func startsClause(_ text: String) -> Bool {
        let lower = text
            .lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        return [
            "and", "but", "or", "so", "because", "which", "that",
            "to", "of", "for", "with", "in", "on", "at", "as",
            "when", "while", "if", "then", "than", "from"
        ].contains(lower)
    }
}
