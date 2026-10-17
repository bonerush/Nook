import Foundation

func runPhrasePlanCacheTests() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("nook-cache-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = PhrasePlanCache(directory: directory, maxEntries: 2)
        let source = "One two three. Four five six."
        let baseKey = PhrasePlanCacheKey(
            model: "test-model",
            promptVersion: 1,
            scriptHash: PhrasePlanCacheKey.hash(source),
            tokenizerVersion: ScriptTokenizer.version,
            budgetWords: 6,
            budgetCharacters: 40
        )
        let plan = PhrasePlan(
            groups: [PhraseGroup(start: 0, end: 5, pauseAfterMs: 120)],
            emphasis: [2],
            source: .ai
        )
        check(cache.load(for: baseKey) == nil, "Fresh cache is empty")
        cache.save(plan, for: baseKey)
        checkEqual(cache.load(for: baseKey), plan, "Cached plan round-trips")

        let secondCache = PhrasePlanCache(directory: directory, maxEntries: 2)
        checkEqual(secondCache.load(for: baseKey), plan, "Cached plan survives a new cache instance")

        var otherKey = baseKey
        otherKey.model = "other-model"
        let otherPlan = PhrasePlan(
            groups: [PhraseGroup(start: 0, end: 5, pauseAfterMs: nil)],
            emphasis: [],
            source: .ai
        )
        do {
            let cache = PhrasePlanCache(directory: directory, maxEntries: 1)
            cache.save(plan, for: baseKey)
            Thread.sleep(forTimeInterval: 0.02)
            cache.save(otherPlan, for: otherKey)
            check(cache.load(for: baseKey) == nil, "Cache trims the oldest entry")
            checkEqual(cache.load(for: otherKey), otherPlan, "Cache keeps the newest entry")
            cache.clear()
            check(cache.load(for: otherKey) == nil, "Clear removes cached plans")
        }

        var hashDifferent = baseKey
        hashDifferent.scriptHash = PhrasePlanCacheKey.hash("A different script.")
        check(hashDifferent != baseKey, "Different scripts produce different cache keys")
        var tokenizerDifferent = baseKey
        tokenizerDifferent.tokenizerVersion = ScriptTokenizer.version + 1
        check(tokenizerDifferent != baseKey, "Different tokenizer versions produce different cache keys")
}