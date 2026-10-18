import Foundation

func runPausePolicyTests() {
    let text = "Hello there. This is a second sentence.\n\nA new paragraph begins here. It continues."
    let script = ScriptTokenizer.tokenize(text)
    let document = PromptScriptBuilder.build(
        from: text,
        options: PromptBuildOptions(wordsPerMinute: 138, fontSize: 30, cardWidth: 680)
    )

    guard let paragraphEnd = script.tokens.first(where: { $0.isParagraphEnd }),
          paragraphEnd.id + 1 < document.words.count else {
        check(false, "Fixture has a paragraph end")
        return
    }
    let paragraphGap = document.words[paragraphEnd.id + 1].start
        - document.words[paragraphEnd.id].end
    check(paragraphGap >= 1.20, "Paragraph breath is at least 1.2s")

    guard let sentenceEnd = script.tokens.first(where: {
        $0.isSentenceEnd && !$0.isParagraphEnd
    }), sentenceEnd.id + 1 < document.words.count else {
        check(false, "Fixture has an intra-paragraph sentence end")
        return
    }
    let sentenceGap = document.words[sentenceEnd.id + 1].start
        - document.words[sentenceEnd.id].end
    check(sentenceGap >= 0.58, "Sentence breath is at least 0.58s")
    check(
        paragraphGap > sentenceGap + 0.50,
        "Paragraph breath is clearly longer than a sentence breath"
    )
}
