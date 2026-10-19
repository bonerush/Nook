import Foundation

public struct SpeechToken: Identifiable, Hashable {
    public let id: Int
    public let text: String
    public let sentenceIndex: Int
    public let paragraphIndex: Int
    public let isSentenceEnd: Bool
    public let isParagraphEnd: Bool

    public init(
        id: Int,
        text: String,
        sentenceIndex: Int,
        paragraphIndex: Int,
        isSentenceEnd: Bool,
        isParagraphEnd: Bool
    ) {
        self.id = id
        self.text = text
        self.sentenceIndex = sentenceIndex
        self.paragraphIndex = paragraphIndex
        self.isSentenceEnd = isSentenceEnd
        self.isParagraphEnd = isParagraphEnd
    }
}

public struct SpeechScript: Equatable {
    public let sourceText: String
    public let tokens: [SpeechToken]
    public let paragraphCount: Int
    public let sentenceCount: Int
    public let tokenizerVersion: Int

    public var tokenCount: Int { tokens.count }
    public var isEmpty: Bool { tokens.isEmpty }
}

public enum ScriptTokenizer {
    public static let version = 1

    public static func tokenize(_ rawText: String) -> SpeechScript {
        let paragraphs = PromptScriptBuilder.paragraphStrings(from: rawText)
        guard !paragraphs.isEmpty else {
            return SpeechScript(
                sourceText: rawText,
                tokens: [],
                paragraphCount: 0,
                sentenceCount: 0,
                tokenizerVersion: version
            )
        }

        var tokens: [SpeechToken] = []
        var sentenceIndex = 0

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let sentences = PromptScriptBuilder.splitSentences(in: paragraph)
            for (localSentenceIndex, sentence) in sentences.enumerated() {
                let sentenceTokens = PromptScriptBuilder.tokenize(sentence)
                for (tokenIndex, token) in sentenceTokens.enumerated() {
                    let isSentenceEnd = tokenIndex == sentenceTokens.count - 1
                    let isParagraphEnd = isSentenceEnd && localSentenceIndex == sentences.count - 1
                    tokens.append(
                        SpeechToken(
                            id: tokens.count,
                            text: token,
                            sentenceIndex: sentenceIndex,
                            paragraphIndex: paragraphIndex,
                            isSentenceEnd: isSentenceEnd,
                            isParagraphEnd: isParagraphEnd
                        )
                    )
                }
                sentenceIndex += 1
            }
        }

        return SpeechScript(
            sourceText: rawText,
            tokens: tokens,
            paragraphCount: paragraphs.count,
            sentenceCount: sentenceIndex,
            tokenizerVersion: version
        )
    }
}
