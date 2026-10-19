import Foundation

/// Typed access to the small set of user preferences Nook stores locally.
/// Values are clamped on read and write so a corrupted defaults file cannot
/// produce an unusable window or prompter.
struct PreferencesStore {
    enum Key {
        static let script = "nook.script.v1"
        static let wordsPerMinute = "nook.wordsPerMinute.v1"
        static let fontSize = "nook.fontSize.v1"
        static let cardWidth = "nook.cardWidth.v1"
        static let hideFromCapture = "nook.hideFromCapture.v1"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Key.script: SampleScript.interviewIntro,
            Key.wordsPerMinute: 138.0,
            Key.fontSize: 30.0,
            Key.cardWidth: 680.0,
            Key.hideFromCapture: true
        ])
    }

    var script: String {
        get { defaults.string(forKey: Key.script) ?? SampleScript.interviewIntro }
        nonmutating set { defaults.set(newValue, forKey: Key.script) }
    }

    var wordsPerMinute: Double {
        get { Self.clamp(defaults.double(forKey: Key.wordsPerMinute), 90, 200) }
        nonmutating set { defaults.set(Self.clamp(newValue, 90, 200), forKey: Key.wordsPerMinute) }
    }

    var fontSize: Double {
        get { Self.clamp(defaults.double(forKey: Key.fontSize), 24, 38) }
        nonmutating set { defaults.set(Self.clamp(newValue, 24, 38), forKey: Key.fontSize) }
    }

    var cardWidth: Double {
        get { Self.clamp(defaults.double(forKey: Key.cardWidth), 600, 860) }
        nonmutating set { defaults.set(Self.clamp(newValue, 600, 860), forKey: Key.cardWidth) }
    }

    var hideFromCapture: Bool {
        get { defaults.bool(forKey: Key.hideFromCapture) }
        nonmutating set { defaults.set(newValue, forKey: Key.hideFromCapture) }
    }

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
