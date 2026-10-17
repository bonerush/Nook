import Foundation

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
        groups: [PhraseGroup(start: 0, end: 1, pauseAfterMs: nil)],
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
}
