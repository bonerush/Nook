import Foundation

func runPromptPipelineSmokeTest() {
    let options = PromptBuildOptions(
        wordsPerMinute: 138,
        fontSize: 30,
        cardWidth: 680
    )
    let source = SampleScript.interviewIntro
    let script = ScriptTokenizer.tokenize(source)
    let plan = HeuristicPhrasePlanner.makePlan(script: script, options: options)
    let document = PromptComposer.makeDocument(
        script: script,
        plan: plan,
        options: options
    )
    checkEqual(document.planSource, .local, "Local pipeline labels its document")
    check(document.lines.count > 5, "Local pipeline produces line groups")
    checkEqual(document.words.count, script.tokens.count, "Local pipeline preserves tokens")
    checkEqual(
        document,
        PromptScriptBuilder.build(from: source, options: options),
        "Local pipeline matches the legacy document"
    )
}

func runPromptComposerTests() {
    let options = PromptBuildOptions(
        wordsPerMinute: 138,
        fontSize: 30,
        cardWidth: 680
    )
    let text = "Hi, I'm Alex. Thank you for taking the time to meet with me today."
    let script = ScriptTokenizer.tokenize(text)
    let plan = PhrasePlan(
        groups: [
            PhraseGroup(start: 0, end: 2, pauseAfterMs: 120),
            PhraseGroup(start: 3, end: 8, pauseAfterMs: 260),
            PhraseGroup(start: 9, end: 13, pauseAfterMs: nil)
        ],
        emphasis: [4],
        source: .ai
    )

    let document = PromptComposer.makeDocument(
        script: script,
        plan: plan,
        options: options
    )
    checkEqual(document.words.count, script.tokens.count, "Composer preserves every token")
    checkEqual(document.planSource, .ai, "Composer labels AI plans")
    checkEqual(document.lines.count, 3, "Composer keeps the three AI phrase groups")
    checkEqual(document.lines.first?.text, "Hi, I'm Alex.", "First AI line is respected")
    checkEqual(document.lines.map(\.sentenceIndex), [0, 1, 1], "Lines remain in their sentences")
    check(document.words[0].start >= 1.9, "Lead-in is preserved")
    check(document.totalDuration > document.words.last!.end, "Trailing hold is present")
    checkEqual(document.lines.first?.startsSentence, true, "First line starts a sentence")

    let fallbackPlan = PhrasePlan(
        groups: [
            PhraseGroup(start: 0, end: 2, pauseAfterMs: nil),
            PhraseGroup(start: 2, end: 13, pauseAfterMs: nil)
        ],
        emphasis: [],
        source: .ai
    )
    let fallbackDocument = PromptComposer.makeDocument(
        script: script,
        plan: fallbackPlan,
        options: options
    )
    checkEqual(fallbackDocument.planSource, .local, "Invalid AI plan falls back to local composition")
    checkEqual(fallbackDocument.words.count, script.tokens.count, "Fallback preserves all tokens")

    let heuristic = HeuristicPhrasePlanner.makePlan(script: script, options: options)
    let localDocument = PromptComposer.makeDocument(
        script: script,
        plan: heuristic,
        options: options
    )
    checkEqual(localDocument.planSource, .local, "Heuristic plans remain local")
    checkEqual(
        localDocument.words.map(\.text),
        PromptScriptBuilder.build(from: text, options: options).words.map(\.text),
        "Local composition keeps the legacy word stream"
    )
    checkEqual(
        localDocument,
        PromptScriptBuilder.build(from: text, options: options),
        "Local composition matches the legacy document exactly"
    )

    // A wide-character plan must be measured and split before rendering.
    let wideText = "MMMM MMMM MMMM MMMM MMMM MMMM MMMM MMMM."
    let wideScript = ScriptTokenizer.tokenize(wideText)
    let widePlan = PhrasePlan(
        groups: [PhraseGroup(start: 0, end: 7, pauseAfterMs: nil)],
        emphasis: [],
        source: .ai
    )
    let wideDocument = PromptComposer.makeDocument(
        script: wideScript,
        plan: widePlan,
        options: options
    )
    check(wideDocument.lines.count > 1, "Wide AI line is split by measured width")
    let available = PromptMetrics.availableTextWidth(cardWidth: options.cardWidth)
    for line in wideDocument.lines {
        let width = PhraseLayout.measure(
            tokens: wideScript.tokens,
            range: line.firstWordIndex...line.lastWordIndex,
            fontSize: options.fontSize
        )
        check(width <= available + 2, "Split line fits the real text width")
    }

    // Plan pauses, emphasis, and monotonic timing are part of the contract.
    let pauseText = "One two three four five six."
    let pauseScript = ScriptTokenizer.tokenize(pauseText)
    let pausePlan = PhrasePlan(
        groups: [
            PhraseGroup(start: 0, end: 2, pauseAfterMs: 300),
            PhraseGroup(start: 3, end: 5, pauseAfterMs: 400)
        ],
        emphasis: [1],
        source: .ai
    )
    let paused = PromptComposer.makeDocument(
        script: pauseScript,
        plan: pausePlan,
        options: options
    )
    let gap = paused.words[3].start - paused.words[2].end
    check(gap >= 0.299, "Non-punctuation plan pause is applied")
    for index in 1..<paused.words.count {
        check(paused.words[index].start >= paused.words[index - 1].end, "Timeline is monotonic")
    }
    let baseForPause = PromptScriptBuilder.build(from: pauseText, options: options)
    check(
        paused.words[1].duration > baseForPause.words[1].duration * 1.04,
        "Emphasis stretches the word"
    )
    checkEqual(
        paused.words.map(\.text),
        pauseScript.tokens.map(\.text),
        "Composer preserves the exact token text"
    )
    check(
        paused.totalDuration <= paused.words.last!.end + options.trailingHold + 0.01,
        "Last-line plan pause is ignored"
    )
}
