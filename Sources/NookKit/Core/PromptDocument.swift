import Foundation

// MARK: - Public model

public struct PromptWord: Identifiable, Hashable {
    public let id: Int
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let lineIndex: Int
    public let sentenceIndex: Int

    public var duration: TimeInterval { max(0, end - start) }

    public init(
        id: Int,
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        lineIndex: Int,
        sentenceIndex: Int
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.lineIndex = lineIndex
        self.sentenceIndex = sentenceIndex
    }
}

public struct PromptLine: Identifiable, Hashable {
    public let id: Int
    public let wordRange: Range<Int>
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let sentenceIndex: Int
    public let startsSentence: Bool

    public var wordCount: Int { wordRange.count }
    public var firstWordIndex: Int { wordRange.lowerBound }
    public var lastWordIndex: Int { max(wordRange.lowerBound, wordRange.upperBound - 1) }

    public init(
        id: Int,
        wordRange: Range<Int>,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        sentenceIndex: Int,
        startsSentence: Bool
    ) {
        self.id = id
        self.wordRange = wordRange
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.sentenceIndex = sentenceIndex
        self.startsSentence = startsSentence
    }
}

public struct PromptDocument: Equatable {
    public let words: [PromptWord]
    public let lines: [PromptLine]
    public let totalDuration: TimeInterval
    public let totalWords: Int
    public let sentenceCount: Int
    public let paragraphCount: Int
    public let wordsPerMinute: Double
    public let leadIn: TimeInterval
    public let planSource: PhrasePlanSource

    public var isEmpty: Bool { words.isEmpty }
    public var lineCount: Int { lines.count }

    public init(
        words: [PromptWord],
        lines: [PromptLine],
        totalDuration: TimeInterval,
        totalWords: Int,
        sentenceCount: Int,
        paragraphCount: Int,
        wordsPerMinute: Double,
        leadIn: TimeInterval,
        planSource: PhrasePlanSource = .local
    ) {
        self.words = words
        self.lines = lines
        self.totalDuration = totalDuration
        self.totalWords = totalWords
        self.sentenceCount = sentenceCount
        self.paragraphCount = paragraphCount
        self.wordsPerMinute = wordsPerMinute
        self.leadIn = leadIn
        self.planSource = planSource
    }

    public static let empty = PromptDocument(
        words: [],
        lines: [],
        totalDuration: 0,
        totalWords: 0,
        sentenceCount: 0,
        paragraphCount: 0,
        wordsPerMinute: 0,
        leadIn: 0
    )

    /// The word being spoken at a given elapsed time. During punctuation pauses
    /// the previous word remains highlighted, which keeps the eye anchored.
    public func wordIndex(at elapsed: TimeInterval) -> Int? {
        guard let first = words.first, elapsed >= first.start else { return nil }
        var low = 0
        var high = words.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if words[mid].start <= elapsed {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return max(0, high)
    }

    public func lineIndex(at elapsed: TimeInterval) -> Int {
        guard let wordIndex = wordIndex(at: elapsed), wordIndex < words.count else { return 0 }
        return words[wordIndex].lineIndex
    }

    public func progress(at elapsed: TimeInterval) -> Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, elapsed / totalDuration))
    }
}

// MARK: - Build options

public struct PromptBuildOptions: Equatable {
    public var wordsPerMinute: Double
    public var fontSize: CGFloat
    public var cardWidth: CGFloat
    public var leadIn: TimeInterval
    public var trailingHold: TimeInterval

    public var availableWidth: CGFloat {
        PromptMetrics.availableTextWidth(cardWidth: cardWidth)
    }

    public var wordSpacing: CGFloat {
        PromptMetrics.wordSpacing(fontSize: fontSize)
    }

    public init(
        wordsPerMinute: Double = 138,
        fontSize: CGFloat = 30,
        cardWidth: CGFloat = 720,
        leadIn: TimeInterval = 2.0,
        trailingHold: TimeInterval = 0.4
    ) {
        self.wordsPerMinute = min(240, max(60, wordsPerMinute))
        self.fontSize = fontSize
        self.cardWidth = cardWidth
        self.leadIn = leadIn
        self.trailingHold = trailingHold
    }
}
