import Foundation

/// Turns a tokenized script plus an optional phrase plan into the timed
/// document that every view reads. When there is no plan, the local heuristic
/// planner supplies one. This type is pure and can be tested without AppKit.
struct ScriptDocumentBuilder {
    let options: PromptBuildOptions

    init(options: PromptBuildOptions) {
        self.options = options
    }

    func build(script: SpeechScript, plan: PhrasePlan?) -> PromptDocument {
        guard !script.isEmpty else { return .empty }
        let resolvedPlan = plan ?? HeuristicPhrasePlanner.makePlan(
            script: script,
            options: options
        )
        return PromptComposer.makeDocument(
            script: script,
            plan: resolvedPlan,
            options: options
        )
    }
}
