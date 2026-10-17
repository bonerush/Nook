import Foundation

private func planFixture() -> SpeechScript {
    ScriptTokenizer.tokenize("One two three. Four five six.")
}

private func singleSentenceFixture() -> SpeechScript {
    ScriptTokenizer.tokenize("One two three four five six.")
}

func runPhrasePlanTests() {
    let script = planFixture()
    let budget = PhraseBudget(maxWords: 6, maxCharacters: 40)

    let valid = PhrasePlan(
        groups: [
            PhraseGroup(start: 0, end: 2, pauseAfterMs: 120),
            PhraseGroup(start: 3, end: 5, pauseAfterMs: nil)
        ],
        emphasis: [2],
        source: .local
    )
    switch PhrasePlanValidator.validate(valid, against: script, budget: budget) {
    case .success(let normalized):
        checkEqual(normalized.groups.count, 2, "Valid phrase plan keeps groups")
        checkEqual(normalized.groups[0].pauseAfterMs, 120, "Pause is preserved")
        checkEqual(normalized.source, .local, "Source is preserved")
    case .failure(let error):
        check(false, "Valid plan should pass: \(error)")
    }

    let crossSentence = PhrasePlan(
        groups: [PhraseGroup(start: 0, end: 5, pauseAfterMs: nil)],
        emphasis: [],
        source: .ai
    )
    switch PhrasePlanValidator.validate(crossSentence, against: script, budget: budget) {
    case .success(let normalized):
        checkEqual(normalized.groups.count, 2, "Cross-sentence line is split")
        checkEqual(normalized.groups[0].start, 0, "First split starts at zero")
        checkEqual(normalized.groups[1].start, 3, "Second split starts at the second sentence")
    case .failure(let error):
        check(false, "Repairable cross-sentence plan should split: \(error)")
    }

    let overlapping = PhrasePlan(
        groups: [
            PhraseGroup(start: 0, end: 2, pauseAfterMs: nil),
            PhraseGroup(start: 2, end: 5, pauseAfterMs: nil)
        ],
        emphasis: [],
        source: .ai
    )
    switch PhrasePlanValidator.validate(overlapping, against: script, budget: budget) {
    case .success:
        check(false, "Overlap must be rejected")
    case .failure(let error):
        checkEqual(error, .overlapAt(2), "Overlap reports the offending index")
    }

    let missing = PhrasePlan(
        groups: [PhraseGroup(start: 0, end: 2, pauseAfterMs: nil)],
        emphasis: [],
        source: .ai
    )
    switch PhrasePlanValidator.validate(missing, against: script, budget: budget) {
    case .success:
        check(false, "Missing coverage must be rejected")
    case .failure(let error):
        checkEqual(error, .missingIndex(3), "Gap reports the first missing index")
    }

    let outOfBounds = PhrasePlan(
        groups: [PhraseGroup(start: 0, end: 8, pauseAfterMs: nil)],
        emphasis: [],
        source: .ai
    )
    switch PhrasePlanValidator.validate(outOfBounds, against: script, budget: budget) {
    case .success:
        check(false, "Out-of-bounds plan must be rejected")
    case .failure(let error):
        checkEqual(error, .outOfBounds(8), "Out-of-bounds index is reported")
    }

    let single = singleSentenceFixture()
    let orphan = PhrasePlan(
        groups: [
            PhraseGroup(start: 0, end: 0, pauseAfterMs: nil),
            PhraseGroup(start: 1, end: 5, pauseAfterMs: nil)
        ],
        emphasis: [],
        source: .ai
    )
    switch PhrasePlanValidator.validate(orphan, against: single, budget: budget) {
    case .success(let normalized):
        checkEqual(normalized.groups.count, 1, "Single-word orphan merges with its neighbor")
        checkEqual(normalized.groups[0].start, 0, "Merged orphan starts at the beginning")
        checkEqual(normalized.groups[0].end, 5, "Merged orphan covers the sentence")
    case .failure(let error):
        check(false, "Orphan should be repairable: \(error)")
    }

    let pausePlan = PhrasePlan(
        groups: [PhraseGroup(start: 0, end: 5, pauseAfterMs: 9999)],
        emphasis: [99],
        source: .ai
    )
    switch PhrasePlanValidator.validate(pausePlan, against: single, budget: budget) {
    case .success(let normalized):
        checkEqual(normalized.groups[0].pauseAfterMs, 400, "Pause is clamped to 400ms")
        check(normalized.emphasis.isEmpty, "Invalid emphasis indexes are removed")
    case .failure(let error):
        check(false, "Clampable plan should pass: \(error)")
    }

    let empty = ScriptTokenizer.tokenize("   ")
    let emptyPlan = PhrasePlan(groups: [], emphasis: [], source: .ai)
    switch PhrasePlanValidator.validate(emptyPlan, against: empty, budget: budget) {
    case .success:
        check(false, "Empty plans must be rejected")
    case .failure(let error):
        checkEqual(error, .emptyPlan, "Empty plan reports emptyPlan")
    }
}
