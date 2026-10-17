import Foundation

final class AppModel: ObservableObject {
    private enum Key {
        static let script = "nook.script.v1"
        static let wordsPerMinute = "nook.wordsPerMinute.v1"
        static let fontSize = "nook.fontSize.v1"
        static let cardWidth = "nook.cardWidth.v1"
        static let hideFromCapture = "nook.hideFromCapture.v1"
    }

    @Published var script: String {
        didSet {
            defaults.set(script, forKey: Key.script)
            scheduleDocumentRebuild()
        }
    }

    @Published var wordsPerMinute: Double {
        didSet {
            defaults.set(wordsPerMinute, forKey: Key.wordsPerMinute)
            rebuildDocumentNow()
        }
    }

    @Published var fontSize: Double {
        didSet {
            defaults.set(fontSize, forKey: Key.fontSize)
            rebuildDocumentNow()
        }
    }

    @Published var cardWidth: Double {
        didSet {
            defaults.set(cardWidth, forKey: Key.cardWidth)
            rebuildDocumentNow()
        }
    }

    @Published var hideFromCapture: Bool {
        didSet {
            defaults.set(hideFromCapture, forKey: Key.hideFromCapture)
        }
    }

    @Published private(set) var document: PromptDocument

    private let defaults: UserDefaults
    private var pendingRebuild: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Key.script: SampleScript.interviewIntro,
            Key.wordsPerMinute: 138.0,
            Key.fontSize: 30.0,
            Key.cardWidth: 680.0,
            Key.hideFromCapture: true
        ])

        let loadedScript = defaults.string(forKey: Key.script) ?? SampleScript.interviewIntro
        let loadedWPM = min(200, max(90, defaults.double(forKey: Key.wordsPerMinute)))
        let loadedFont = min(38, max(24, defaults.double(forKey: Key.fontSize)))
        let loadedWidth = min(860, max(600, defaults.double(forKey: Key.cardWidth)))

        self.script = loadedScript
        self.wordsPerMinute = loadedWPM
        self.fontSize = loadedFont
        self.cardWidth = loadedWidth
        self.hideFromCapture = defaults.bool(forKey: Key.hideFromCapture)
        self.document = PromptScriptBuilder.build(
            from: loadedScript,
            options: PromptBuildOptions(
                wordsPerMinute: loadedWPM,
                fontSize: CGFloat(loadedFont),
                cardWidth: CGFloat(loadedWidth)
            )
        )
    }

    deinit {
        pendingRebuild?.cancel()
    }

    // MARK: Derived values

    var buildOptions: PromptBuildOptions {
        PromptBuildOptions(
            wordsPerMinute: wordsPerMinute,
            fontSize: CGFloat(fontSize),
            cardWidth: CGFloat(cardWidth)
        )
    }

    var hasContent: Bool {
        !document.words.isEmpty
    }

    var estimatedDurationLabel: String {
        NookTime.total(document.totalDuration)
    }

    var previewLines: [PromptLine] {
        Array(document.lines.prefix(3))
    }

    var speedLabel: String {
        "\(Int(wordsPerMinute.rounded())) WPM"
    }

    // MARK: Editing

    func rebuildDocumentNow() {
        pendingRebuild?.cancel()
        pendingRebuild = nil

        let next = PromptScriptBuilder.build(from: script, options: buildOptions)
        if next != document {
            document = next
        }
    }

    func loadSample() {
        script = SampleScript.interviewIntro
        rebuildDocumentNow()
    }

    func clearScript() {
        script = ""
        rebuildDocumentNow()
    }

    func setSpeed(_ speed: Double) {
        wordsPerMinute = min(200, max(90, speed.rounded()))
    }

    func adjustSpeed(by delta: Double) {
        setSpeed(wordsPerMinute + delta)
    }

    private func scheduleDocumentRebuild() {
        pendingRebuild?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rebuildDocumentNow()
        }
        pendingRebuild = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: work)
    }
}
