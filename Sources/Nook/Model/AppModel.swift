import Combine
import Foundation

enum AIPlanningState: Equatable {
    case idle
    case planning
    case failed(AIPlanFailure)
}

enum StartPreparation: Equatable {
    case ready
    case failed
}

/// The editor's observable state: the script, the timing preferences, the
/// active phrase plan, and the start flow. AI credentials and drafts live in
/// AISettingsModel so typing in the settings sheet cannot invalidate this
/// object's published document.
@MainActor
final class AppModel: ObservableObject {
    @Published var script: String {
        didSet {
            preferences.script = script
            invalidateAIPlan()
            scheduleDocumentRebuild()
        }
    }

    @Published var wordsPerMinute: Double {
        didSet {
            preferences.wordsPerMinute = wordsPerMinute
            scheduleDocumentRebuild(delay: 0.05)
        }
    }

    @Published var fontSize: Double {
        didSet {
            preferences.fontSize = fontSize
            invalidateAIPlan()
            scheduleDocumentRebuild(delay: 0.05)
        }
    }

    @Published var cardWidth: Double {
        didSet {
            preferences.cardWidth = cardWidth
            invalidateAIPlan()
            scheduleDocumentRebuild(delay: 0.05)
        }
    }

    @Published var hideFromCapture: Bool {
        didSet {
            preferences.hideFromCapture = hideFromCapture
        }
    }

    @Published private(set) var document: PromptDocument
    @Published private(set) var planSource: PhrasePlanSource = .local
    @Published private(set) var activePlan: PhrasePlan? = nil
    @Published private(set) var planningState: AIPlanningState = .idle
    @Published private(set) var planError: AIPlanFailure? = nil

    @Published var isAISettingsPresented = false
    @Published var isInspectorVisible = true

    let preferences: PreferencesStore
    let aiSettings: AISettingsModel

    private let coordinator: AIPlanningCoordinator
    private var pendingRebuild: DispatchWorkItem?
    private var planningTask: Task<Void, Never>?
    private var planningGeneration = 0

    init(
        defaults: UserDefaults = .standard,
        secretStore: SecretStore = KeychainStore()
    ) {
        let preferences = PreferencesStore(defaults: defaults)
        preferences.registerDefaults()
        self.preferences = preferences

        self.script = preferences.script
        self.wordsPerMinute = preferences.wordsPerMinute
        self.fontSize = preferences.fontSize
        self.cardWidth = preferences.cardWidth
        self.hideFromCapture = preferences.hideFromCapture

        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let cacheDirectory = base
            .appendingPathComponent("Nook", isDirectory: true)
            .appendingPathComponent("PhrasePlans", isDirectory: true)
        let cache = PhrasePlanCache(directory: cacheDirectory)
        let client = OpenAICompatibleClient()
        let coordinator = AIPlanningCoordinator(
            fetcher: client,
            client: client,
            cache: cache
        )
        self.coordinator = coordinator
        self.aiSettings = AISettingsModel(
            defaults: defaults,
            secretStore: secretStore,
            coordinator: coordinator
        )

        let initialOptions = PromptBuildOptions(
            wordsPerMinute: preferences.wordsPerMinute,
            fontSize: CGFloat(preferences.fontSize),
            cardWidth: CGFloat(preferences.cardWidth)
        )
        let initialScript = ScriptTokenizer.tokenize(preferences.script)
        self.document = ScriptDocumentBuilder(options: initialOptions).build(
            script: initialScript,
            plan: nil
        )

        self.aiSettings.onChange = { [weak self] in
            self?.handleAISettingsChange()
        }
    }

    deinit {
        pendingRebuild?.cancel()
        planningTask?.cancel()
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

    var canUseAI: Bool {
        aiSettings.canUseAI
    }

    var llmConfiguration: LLMConfiguration {
        aiSettings.configuration
    }

    // MARK: Editing

    func rebuildDocumentNow() {
        pendingRebuild?.cancel()
        pendingRebuild = nil

        let parsed = ScriptTokenizer.tokenize(script)
        guard !parsed.isEmpty else {
            if document != .empty {
                document = .empty
            }
            planSource = .local
            return
        }

        let next = ScriptDocumentBuilder(options: buildOptions).build(
            script: parsed,
            plan: activePlan
        )
        if next != document {
            document = next
        }
        planSource = next.planSource
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
        wordsPerMinute = PreferencesStore.clamp(speed.rounded(), 90, 200)
    }

    func adjustSpeed(by delta: Double) {
        setSpeed(wordsPerMinute + delta)
    }

    func toggleInspector() {
        isInspectorVisible.toggle()
    }

    // MARK: AI planning

    func prepareForStart(completion: @escaping (StartPreparation) -> Void) {
        guard hasContent else {
            completion(.failed)
            return
        }
        rebuildDocumentNow()

        let key = aiSettings.readKey() ?? ""
        let configuration = aiSettings.configuration
        guard configuration.isComplete,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || configuration.isLocalEndpoint else {
            startWithLocalPlan()
            completion(.ready)
            return
        }

        planningGeneration += 1
        let generation = planningGeneration
        planningTask?.cancel()
        planningState = .planning
        planError = nil

        let snapshotText = script
        let snapshot = ScriptTokenizer.tokenize(snapshotText)
        let options = buildOptions

        planningTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.coordinator.prepare(
                script: snapshot,
                options: options,
                configuration: configuration,
                apiKey: key
            )
            if Task.isCancelled { return }
            guard self.planningGeneration == generation else { return }
            guard self.script == snapshotText else {
                self.planningState = .idle
                self.planningTask = nil
                completion(.failed)
                return
            }
            self.planningTask = nil
            switch result {
            case .fresh(let plan), .cached(let plan):
                self.activePlan = plan
                self.planSource = .ai
                self.planningState = .idle
                self.planError = nil
                self.rebuildDocumentUsing(plan)
                completion(.ready)
            case .disabled:
                self.startWithLocalPlan()
                completion(.ready)
            case .failed(let failure):
                if failure == .cancelled {
                    self.planningState = .idle
                    return
                }
                self.planningState = .failed(failure)
                self.planError = failure
                completion(.failed)
            }
        }
    }

    func startWithLocalPlan() {
        planningGeneration += 1
        planningTask?.cancel()
        planningTask = nil
        activePlan = nil
        planSource = .local
        planningState = .idle
        planError = nil
        rebuildDocumentNow()
    }

    func cancelPlanning() {
        planningGeneration += 1
        planningTask?.cancel()
        planningTask = nil
        planningState = .idle
        planError = nil
    }

    private func rebuildDocumentUsing(_ plan: PhrasePlan) {
        let parsed = ScriptTokenizer.tokenize(script)
        let next = ScriptDocumentBuilder(options: buildOptions).build(
            script: parsed,
            plan: plan
        )
        document = next
        planSource = next.planSource
    }

    private func invalidateAIPlan() {
        planningGeneration += 1
        planningTask?.cancel()
        planningTask = nil
        activePlan = nil
        planSource = .local
        planningState = .idle
        planError = nil
    }

    private func handleAISettingsChange() {
        invalidateAIPlan()
        rebuildDocumentNow()
    }

    // MARK: AI settings presentation

    func openAISettings() {
        aiSettings.open()
        isAISettingsPresented = true
    }

    func closeAISettings() {
        aiSettings.close()
        isAISettingsPresented = false
    }

    private func scheduleDocumentRebuild(delay: TimeInterval = 0.16) {
        pendingRebuild?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rebuildDocumentNow()
        }
        pendingRebuild = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
