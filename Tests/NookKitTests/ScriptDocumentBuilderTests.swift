import Foundation

func runScriptDocumentBuilderTests() {
    let options = PromptBuildOptions(wordsPerMinute: 138, fontSize: 30, cardWidth: 680)
    let builder = ScriptDocumentBuilder(options: options)

    let emptyScript = ScriptTokenizer.tokenize("   \n  ")
    let empty = builder.build(script: emptyScript, plan: nil)
    check(empty.isEmpty, "Builder returns an empty document for blank text")

    let script = ScriptTokenizer.tokenize(SampleScript.interviewIntro)
    let local = builder.build(script: script, plan: nil)
    check(local.totalWords > 0, "Builder produces words for the sample script")
    checkEqual(local.planSource, .local, "Builder marks a heuristic plan as local")
    checkEqual(local.wordsPerMinute, 138, "Builder carries the WPM into the document")

    let slowOptions = PromptBuildOptions(wordsPerMinute: 110, fontSize: 30, cardWidth: 680)
    let slow = ScriptDocumentBuilder(options: slowOptions).build(script: script, plan: nil)
    check(slow.totalDuration > local.totalDuration * 1.15, "A slower WPM lengthens the document")

    let smallOptions = PromptBuildOptions(wordsPerMinute: 138, fontSize: 26, cardWidth: 680)
    let small = ScriptDocumentBuilder(options: smallOptions).build(script: script, plan: nil)
    check(small.lines.count != local.lines.count || small.lines != local.lines, "Type size changes line layout")

    let plan = HeuristicPhrasePlanner.makePlan(script: script, options: options)
    let withPlan = builder.build(script: script, plan: plan)
    let composed = PromptComposer.makeDocument(script: script, plan: plan, options: options)
    checkEqual(
        withPlan.words.map(\.text),
        composed.words.map(\.text),
        "Builder preserves the token text for an explicit plan"
    )
    checkEqual(
        withPlan.lines.map(\.text),
        composed.lines.map(\.text),
        "Builder preserves the composer line layout"
    )
    checkEqual(withPlan.planSource, .local, "A heuristic plan stays local")
}
