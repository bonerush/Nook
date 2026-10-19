import Foundation

public enum HeuristicPhrasePlanner {
    /// Build the stable local plan from the existing measured line breaker.
    /// The legacy builder remains the source of truth for local phrase timing
    /// until the composer migration is complete.
    public static func makePlan(
        script: SpeechScript,
        options: PromptBuildOptions
    ) -> PhrasePlan {
        let base = PromptScriptBuilder.build(from: script.sourceText, options: options)
        guard base.words.count == script.tokens.count else {
            return PhrasePlan(groups: [], source: .local)
        }
        let groups = base.lines.map {
            PhraseGroup(
                start: $0.firstWordIndex,
                end: $0.lastWordIndex,
                pauseAfterMs: nil
            )
        }
        return PhrasePlan(groups: groups, source: .local)
    }
}
