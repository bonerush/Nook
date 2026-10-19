import AppKit
import Foundation
import NaturalLanguage

// MARK: - Builder

public enum PromptScriptBuilder {
    public static func build(
        from rawText: String,
        options: PromptBuildOptions = PromptBuildOptions()
    ) -> PromptDocument {
        let paragraphs = paragraphStrings(from: rawText)
        guard !paragraphs.isEmpty else { return .empty }

        struct SentenceSeed {
            var text: String
            var paragraphIndex: Int
            var isParagraphEnd: Bool
        }

        var sentenceSeeds: [SentenceSeed] = []
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let sentences = splitSentences(in: paragraph)
            for (sentenceIndex, sentence) in sentences.enumerated() {
                sentenceSeeds.append(
                    SentenceSeed(
                        text: sentence,
                        paragraphIndex: paragraphIndex,
                        isParagraphEnd: sentenceIndex == sentences.count - 1
                    )
                )
            }
        }
        guard !sentenceSeeds.isEmpty else { return .empty }

        // Paragraph ends are resolved after sentence merging.
        var paragraphEndSentenceIndices = Set<Int>()
        for index in sentenceSeeds.indices where sentenceSeeds[index].isParagraphEnd {
            paragraphEndSentenceIndices.insert(index)
        }
        // If merging removed the last sentence of a paragraph, the merged sentence
        // is still the paragraph end.
        for index in sentenceSeeds.indices.dropLast() {
            if sentenceSeeds[index].paragraphIndex != sentenceSeeds[index + 1].paragraphIndex {
                paragraphEndSentenceIndices.insert(index)
            }
        }

        struct RawWord {
            let text: String
            let start: TimeInterval
            let end: TimeInterval
            let sentenceIndex: Int
        }

        let font = NSFont.systemFont(ofSize: options.fontSize, weight: .semibold)
        let sentenceTokens: [[String]] = sentenceSeeds.map { tokenize($0.text) }
        var weights: [Double] = []
        var widths: [CGFloat] = []
        for tokens in sentenceTokens {
            for token in tokens {
                weights.append(wordWeight(token))
                widths.append(measure(token, font: font))
            }
        }
        guard !weights.isEmpty else { return .empty }

        let meanWeight = max(0.001, weights.reduce(0, +) / Double(weights.count))
        let baseWordDuration = 60.0 / min(260, max(60, options.wordsPerMinute))

        var rawWords: [RawWord] = []
        rawWords.reserveCapacity(weights.count)
        var cursor = max(0, options.leadIn)
        var flatIndex = 0

        for (sentenceIndex, tokens) in sentenceTokens.enumerated() {
            for tokenIndex in tokens.indices {
                let token = tokens[tokenIndex]
                let duration = max(0.075, baseWordDuration * weights[flatIndex] / meanWeight)
                let start = cursor
                let end = start + duration
                let isSentenceEnd = tokenIndex == tokens.count - 1
                let isParagraphEnd = isSentenceEnd && paragraphEndSentenceIndices.contains(sentenceIndex)
                let pause = pauseAfter(token, isSentenceEnd: isSentenceEnd, isParagraphEnd: isParagraphEnd)
                cursor = end + pause

                rawWords.append(
                    RawWord(
                        text: token,
                        start: start,
                        end: end,
                        sentenceIndex: sentenceIndex
                    )
                )
                flatIndex += 1
            }
        }

        // Build display lines sentence by sentence so a line never crosses a
        // sentence boundary. Timing stays continuous and punctuation-led.
        var rawLineRanges: [Range<Int>] = []
        var rawLineSentenceIndices: [Int] = []
        var rawLineStartsSentence: [Bool] = []
        var globalOffset = 0
        for (sentenceIndex, tokens) in sentenceTokens.enumerated() {
            let sentenceWidths = Array(widths[globalOffset..<(globalOffset + tokens.count)])
            let localRanges = makeLineRanges(
                tokens: tokens,
                widths: sentenceWidths,
                maxWidth: options.availableWidth,
                wordSpacing: options.wordSpacing
            )
            for (localIndex, localRange) in localRanges.enumerated() {
                rawLineRanges.append(
                    (globalOffset + localRange.lowerBound)..<(globalOffset + localRange.upperBound)
                )
                rawLineSentenceIndices.append(sentenceIndex)
                rawLineStartsSentence.append(localIndex == 0)
            }
            globalOffset += tokens.count
        }

        var lineIndexForWord = Array(repeating: 0, count: rawWords.count)
        var lines: [PromptLine] = []
        lines.reserveCapacity(rawLineRanges.count)

        for (lineIndex, range) in rawLineRanges.enumerated() {
            for wordIndex in range {
                lineIndexForWord[wordIndex] = lineIndex
            }
            let lineWords = rawWords[range]
            let text = lineWords.map(\.text).joined(separator: " ")
            let startTime = lineWords.first?.start ?? options.leadIn
            let endTime = lineWords.last?.end ?? startTime
            lines.append(
                PromptLine(
                    id: lineIndex,
                    wordRange: range,
                    text: text,
                    startTime: startTime,
                    endTime: endTime,
                    sentenceIndex: rawLineSentenceIndices[lineIndex],
                    startsSentence: rawLineStartsSentence[lineIndex]
                )
            )
        }

        let words: [PromptWord] = rawWords.enumerated().map { index, raw in
            PromptWord(
                id: index,
                text: raw.text,
                start: raw.start,
                end: raw.end,
                lineIndex: lineIndexForWord[index],
                sentenceIndex: raw.sentenceIndex
            )
        }

        let lastEnd = words.last?.end ?? options.leadIn
        let totalDuration = max(lastEnd + options.trailingHold, options.leadIn)

        return PromptDocument(
            words: words,
            lines: lines,
            totalDuration: totalDuration,
            totalWords: words.count,
            sentenceCount: sentenceSeeds.count,
            paragraphCount: paragraphs.count,
            wordsPerMinute: options.wordsPerMinute,
            leadIn: options.leadIn
        )
    }

    // MARK: Text cleanup

    static func paragraphStrings(from rawText: String) -> [String] {
        let normalized = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var paragraphs: [String] = []
        var buffer: [String] = []

        func flush() {
            guard !buffer.isEmpty else { return }
            let paragraph = buffer.joined(separator: " ")
            if !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                paragraphs.append(paragraph)
            }
            buffer.removeAll(keepingCapacity: true)
        }

        for line in normalized.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
            } else {
                buffer.append(trimmed)
            }
        }
        flush()
        return paragraphs
    }

    static func tokenize(_ sentence: String) -> [String] {
        var tokens: [String] = []

        // A spoken em dash deserves its own beat. Keep it glued to the word
        // before it so the line painter can pause naturally and never begins a
        // phrase with a dangling dash. Unspaced en dashes (2020–2024) stay put.
        for rawToken in sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            let pieces = emDashPieces(rawToken)
            for piece in pieces {
                if piece == "—" {
                    if tokens.indices.last != nil {
                        tokens[tokens.count - 1].append("—")
                    } else {
                        tokens.append("—")
                    }
                } else if piece.hasPrefix("—") {
                    if tokens.indices.last != nil {
                        tokens[tokens.count - 1].append("—")
                    } else {
                        tokens.append("—")
                    }
                    let remainder = String(piece.dropFirst())
                    if !remainder.isEmpty { tokens.append(remainder) }
                } else {
                    tokens.append(piece)
                }
            }
        }
        return tokens
    }

    private static func emDashPieces(_ token: String) -> [String] {
        guard token.contains("—") else { return [token] }
        var pieces: [String] = []
        var current = ""
        for character in token {
            if character == "—" {
                current.append(character)
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    static func splitSentences(in paragraph: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = paragraph
        tokenizer.setLanguage(preferredLanguage(for: paragraph))
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { range, _ in
            let sentence = String(paragraph[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        guard !sentences.isEmpty else { return [] }

        // NLTokenizer is very good at quotes, decimals and ellipses, but it can
        // break after honorifics such as "Dr.". Rejoin those fragments, along
        // with initial sequences like "J. K.".
        var merged: [String] = []
        var index = 0
        while index < sentences.count {
            var current = sentences[index]
            while index + 1 < sentences.count,
                  shouldMergeWithNext(current) {
                index += 1
                current += " " + sentences[index]
            }
            merged.append(current)
            index += 1
        }
        return merged
    }

    private static func preferredLanguage(for text: String) -> NLLanguage {
        var cjk = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value) {
                cjk += 1
            } else if scalar.properties.isAlphabetic {
                latin += 1
            }
        }
        return cjk > latin ? .simplifiedChinese : .english
    }

    private static let titleAbbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "prof", "rev", "hon", "pres", "gov",
        "sen", "rep", "gen", "col", "lt", "sgt", "capt", "cmdr", "fr",
        "st"
    ]

    private static func shouldMergeWithNext(_ sentence: String) -> Bool {
        let stripped = sentence.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'”’)]}"))
        )
        guard stripped.hasSuffix(".") else { return false }
        let words = stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let last = words.last else { return false }

        let bare = last.trimmingCharacters(in: CharacterSet(charactersIn: ".\"'”’)]}"))
            .lowercased()
        if titleAbbreviations.contains(bare) { return true }

        // A sentence consisting only of initials ("J." or "J. K.") is almost
        // certainly the beginning of a name that the tokenizer split.
        let allInitials = words.allSatisfy { word in
            let cleaned = word.trimmingCharacters(in: CharacterSet(charactersIn: ".\"'”’)]}"))
            return cleaned.count == 1 && cleaned.first?.isUppercase == true
        }
        return allInitials
    }

    // MARK: Timing

    private static func syllableCount(_ token: String) -> Int {
        let lettersOnly = token.filter { $0.isLetter }
        guard !lettersOnly.isEmpty else { return 1 }

        // Acronyms are usually spelled out ("A-P-I").
        if lettersOnly.count <= 5, lettersOnly == lettersOnly.uppercased() {
            return lettersOnly.count
        }

        let parts = token.lowercased().split(whereSeparator: { $0 == "-" })
        var total = 0
        for part in parts {
            var groups = 0
            var previousWasVowel = false
            for character in part where character.isLetter {
                let isVowel = "aeiouy".contains(character)
                if isVowel && !previousWasVowel { groups += 1 }
                previousWasVowel = isVowel
            }
            if groups == 0 { groups = 1 }
            if part.hasSuffix("e"), !part.hasSuffix("le"), groups > 1 {
                groups -= 1
            }
            total += groups
        }
        return max(1, total)
    }

    private static func wordWeight(_ token: String) -> Double {
        let letters = token.filter { $0.isLetter || $0.isNumber }
        let characterCount = max(1, letters.count)
        let syllables = syllableCount(token)
        let raw = 0.52 + 0.22 * Double(syllables) + 0.015 * Double(characterCount)
        return min(2.1, max(0.7, raw))
    }

    private static func pauseAfter(
        _ token: String,
        isSentenceEnd: Bool,
        isParagraphEnd: Bool
    ) -> TimeInterval {
        let punctuation = trailingPunctuation(of: token)

        if isSentenceEnd {
            var pause: TimeInterval = 0.62
            if punctuation == "?" || punctuation == "!" { pause = 0.72 }
            if token.contains("…") || token.contains("...") { pause = 0.84 }
            // A paragraph is a complete thought, not just another sentence.
            // Give the reader enough silence to reset before the next thought.
            if isParagraphEnd { pause += 1.0 }
            return pause
        }

        switch punctuation {
        case ",": return 0.16
        case ";", ":": return 0.28
        case "—", "–": return 0.3
        case "…": return 0.46
        default:
            if token.contains("...") { return 0.46 }
            return 0
        }
    }

    private static func trailingPunctuation(of token: String) -> Character? {
        let closing = CharacterSet(charactersIn: "\"'”’»)]}")
        var scalars = token.unicodeScalars
        while let last = scalars.last, closing.contains(last) {
            scalars.removeLast()
        }
        return scalars.last.map(Character.init)
    }

    // MARK: Line building

    private static func measure(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }

    private static func makeLineRanges(
        tokens: [String],
        widths: [CGFloat],
        maxWidth: CGFloat,
        wordSpacing: CGFloat
    ) -> [Range<Int>] {
        guard !tokens.isEmpty else { return [] }
        var ranges: [Range<Int>] = []
        var start = 0

        // Wide screens should not turn the prompter into full-width paragraphs.
        // Twelve words is the upper bound; punctuation and clause boundaries
        // usually create shorter, more speakable groups.
        let maxPhraseWords = 12

        while start < tokens.count {
            var fitEnd = start
            var used = CGFloat.zero
            var scan = start
            while scan < tokens.count, scan - start < maxPhraseWords {
                let addition = widths[scan] + (scan > start ? wordSpacing : 0)
                if fitEnd > start, used + addition > maxWidth { break }
                used += addition
                fitEnd += 1
                scan += 1
            }
            if fitEnd >= tokens.count {
                ranges.append(start..<tokens.count)
                break
            }

            var punctuationBreak = -1
            var connectorBreak = -1
            var strongConnectorBreak = -1
            if fitEnd > start + 1 {
                var runningWidth = CGFloat.zero
                for wordIndex in start..<fitEnd {
                    if wordIndex > start { runningWidth += wordSpacing }
                    runningWidth += widths[wordIndex]
                    let next = wordIndex + 1
                    let ratio = runningWidth / max(1, maxWidth)

                    if next < fitEnd,
                       next - start >= 3,
                       ratio >= 0.32,
                       isClausePunctuation(tokens[wordIndex]) {
                        punctuationBreak = next
                    }
                    if next < fitEnd,
                       ratio >= 0.48,
                       isConnector(tokens[next]) {
                        connectorBreak = next
                        if isStrongConnector(tokens[next]) {
                            strongConnectorBreak = next
                        }
                    }
                }
            }

            var end = fitEnd
            if punctuationBreak > start {
                end = punctuationBreak
            } else if strongConnectorBreak > start {
                end = strongConnectorBreak
            } else if connectorBreak > start {
                end = connectorBreak
            }

            if end <= start { end = min(tokens.count, start + 1) }
            if punctuationBreak < 0, connectorBreak < 0, end > start + 1 {
                let lastWord = cleanedWord(tokens[end - 1])
                if weakLineEnders.contains(lastWord), end - start > 2 {
                    end -= 1
                }
            }

            ranges.append(start..<end)
            start = end
        }
        return ranges
    }

    private static func isClausePunctuation(_ token: String) -> Bool {
        guard let punctuation = trailingPunctuation(of: token) else { return false }
        return ",;:—–".contains(punctuation)
    }

    private static let connectors: Set<String> = [
        // Clause openers.
        "and", "but", "so", "because", "which", "that", "who", "whom",
        "while", "when", "if", "yet", "or", "though", "although",
        // Prepositional / participle openings that make natural breath groups.
        "to", "of", "in", "on", "at", "for", "with", "from", "by",
        "based", "using", "through", "into", "about", "across", "without",
        "over", "under", "after", "before", "as", "like", "than"
    ]

    private static func isConnector(_ token: String) -> Bool {
        connectors.contains(cleanedWord(token))
    }

    private static let strongConnectors: Set<String> = [
        "and", "but", "so", "because", "which", "that", "who", "whom",
        "while", "when", "if", "yet", "or", "though", "although",
        "to", "based", "using", "through", "without", "across", "as",
        "like", "than", "after", "before"
    ]

    private static func isStrongConnector(_ token: String) -> Bool {
        strongConnectors.contains(cleanedWord(token))
    }

    private static let weakLineEnders: Set<String> = [
        "a", "an", "the", "my", "your", "his", "her", "our", "their",
        "this", "that", "these", "those", "to", "of", "in", "on", "at",
        "by", "for", "with", "from", "and", "or", "but", "so", "as",
        "is", "are", "was", "were", "be", "been", "am", "i", "you",
        "we", "they", "he", "she", "it", "very", "really"
    ]

    private static func cleanedWord(_ token: String) -> String {
        token
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            .lowercased()
    }

}
