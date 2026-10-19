import Foundation

func runPreferencesStoreTests() {
    let suite = "app.nook.tests.preferences.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        check(false, "Preferences suite can be created")
        return
    }
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = PreferencesStore(defaults: defaults)
    store.registerDefaults()

    checkEqual(store.script, SampleScript.interviewIntro, "Preferences start with the sample script")
    checkEqual(store.wordsPerMinute, 138, "Preferences default to 138 WPM")
    checkEqual(store.fontSize, 30, "Preferences default to 30 pt type")
    checkEqual(store.cardWidth, 680, "Preferences default to a 680 pt card")
    checkEqual(store.hideFromCapture, true, "Capture hiding is on by default")

    store.script = "Hello there."
    checkEqual(store.script, "Hello there.", "Script round-trips through defaults")
    checkEqual(
        PreferencesStore(defaults: defaults).script,
        "Hello there.",
        "A second store reads the saved script"
    )

    store.wordsPerMinute = 500
    checkEqual(store.wordsPerMinute, 200, "WPM clamps to the upper bound")
    store.wordsPerMinute = 10
    checkEqual(store.wordsPerMinute, 90, "WPM clamps to the lower bound")

    store.fontSize = 100
    checkEqual(store.fontSize, 38, "Type size clamps to the upper bound")
    store.fontSize = 4
    checkEqual(store.fontSize, 24, "Type size clamps to the lower bound")

    store.cardWidth = 1000
    checkEqual(store.cardWidth, 860, "Card width clamps to the upper bound")
    store.cardWidth = 100
    checkEqual(store.cardWidth, 600, "Card width clamps to the lower bound")

    store.hideFromCapture = false
    checkEqual(store.hideFromCapture, false, "Capture hiding persists")
}
