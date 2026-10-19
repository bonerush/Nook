import Foundation

enum AIPlanningState: Equatable {
    case idle
    case planning
    case failed(AIPlanFailure)
}

enum ConnectionTestState: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

enum StartPreparation: Equatable {
    case ready
    case failed
}

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
            invalidateAIPlan()
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
            invalidateAIPlan()
            rebuildDocumentNow()
        }
    }

    @Published var cardWidth: Double {
        didSet {
            defaults.set(cardWidth, forKey: Key.cardWidth)
            invalidateAIPlan()
            rebuildDocumentNow()
        }
    }

    @Published var hideFromCapture: Bool {
        didSet {
            defaults.set(hideFromCapture, forKey: Key.hideFromCapture)
        }
    }

    @Published private(set) var document: PromptDocument
    @Published private(set) var planSource: PhrasePlanSource = .local
    @Published private(set) var activePlan: PhrasePlan? = nil
    @Published private(set) var planningState: AIPlanningState = .idle
    @Published private(set) var planError: AIPlanFailure? = nil

    @Published private(set) var llmConfiguration: LLMConfiguration
    @Published private(set) var hasAPIKey: Bool
    @Published var isAISettingsPresented = false
    @Published var aiBaseURLDraft: String {
        didSet { invalidateConnectionTest() }
    }
    @Published var aiModelDraft: String {
        didSet { invalidateConnectionTest() }
    }
    @Published var aiPresetDraft: LLMProviderPreset {
        didSet { invalidateConnectionTest() }
    }
    @Published var aiReasoningEnabledDraft: Bool {
        didSet { invalidateConnectionTest() }
    }
    @Published var aiReasoningEffortDraft: LLMReasoningEffort {
        didSet { invalidateConnectionTest() }
    }
    @Published var aiKeyDraft: String = "" {
        didSet { invalidateConnectionTest() }
    }
    @Published var isAPIKeyVisible = false
    @Published private(set) var apiKeySuffix: String? = nil
    @Published private(set) var aiSettingsError: String? = nil
    @Published private(set) var connectionTestState: ConnectionTestState = .idle

    private let defaults: UserDefaults
    private let keychain: SecretStore
    private let coordinator: AIPlanningCoordinator
    private var pendingRebuild: DispatchWorkItem?
    private var planningTask: Task<Void, Never>?
    private var planningGeneration = 0

    init(
        defaults: UserDefaults = .standard,
        secretStore: SecretStore = KeychainStore()
    ) {
        self.defaults = defaults
        self.keychain = secretStore

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

        let configuration = LLMConfigurationStore.load(defaults: defaults)
        self.llmConfiguration = configuration
        self.aiBaseURLDraft = configuration.baseURLString
        self.aiModelDraft = configuration.model
        self.aiPresetDraft = configuration.preset
        self.aiReasoningEnabledDraft = configuration.reasoningEnabled
        self.aiReasoningEffortDraft = configuration.reasoningEffort
        let storedKey = (try? secretStore.read()) ?? nil
        self.hasAPIKey = storedKey?.isEmpty == false
        if let storedKey, storedKey.count >= 4 {
            self.apiKeySuffix = String(storedKey.suffix(4))
        }

        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let cacheDirectory = base
            .appendingPathComponent("Nook", isDirectory: true)
            .appendingPathComponent("PhrasePlans", isDirectory: true)
        let cache = PhrasePlanCache(directory: cacheDirectory)
        let client = OpenAICompatibleClient()
        self.coordinator = AIPlanningCoordinator(
            fetcher: client,
            client: client,
            cache: cache
        )

        let initialOptions = PromptBuildOptions(
            wordsPerMinute: loadedWPM,
            fontSize: CGFloat(loadedFont),
            cardWidth: CGFloat(loadedWidth)
        )
        let initialScript = ScriptTokenizer.tokenize(loadedScript)
        let initialPlan = HeuristicPhrasePlanner.makePlan(
            script: initialScript,
            options: initialOptions
        )
        self.document = PromptComposer.makeDocument(
            script: initialScript,
            plan: initialPlan,
            options: initialOptions
        )
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
        llmConfiguration.isComplete && (hasAPIKey || llmConfiguration.isLocalEndpoint)
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

        let plan = activePlan ?? HeuristicPhrasePlanner.makePlan(
            script: parsed,
            options: buildOptions
        )
        let next = PromptComposer.makeDocument(
            script: parsed,
            plan: plan,
            options: buildOptions
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
        wordsPerMinute = min(200, max(90, speed.rounded()))
    }

    func adjustSpeed(by delta: Double) {
        setSpeed(wordsPerMinute + delta)
    }

    // MARK: AI planning

    func prepareForStart(completion: @escaping (StartPreparation) -> Void) {
        guard hasContent else {
            completion(.failed)
            return
        }
        rebuildDocumentNow()

        let key = ((try? keychain.read()) ?? nil) ?? ""
        guard llmConfiguration.isComplete,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || llmConfiguration.isLocalEndpoint else {
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
        let configuration = llmConfiguration

        planningTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.coordinator.prepare(
                script: snapshot,
                options: options,
                configuration: configuration,
                apiKey: key
            )
            if Task.isCancelled { return }
            DispatchQueue.main.async {
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
        let next = PromptComposer.makeDocument(
            script: parsed,
            plan: plan,
            options: buildOptions
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

    // MARK: AI settings

    func openAISettings() {
        aiBaseURLDraft = llmConfiguration.baseURLString
        aiModelDraft = llmConfiguration.model
        aiPresetDraft = llmConfiguration.preset
        aiReasoningEnabledDraft = llmConfiguration.reasoningEnabled
        aiReasoningEffortDraft = llmConfiguration.reasoningEffort
        aiKeyDraft = ""
        aiSettingsError = nil
        connectionTestState = .idle
        isAPIKeyVisible = false
        isAISettingsPresented = true
    }

    func closeAISettings() {
        isAISettingsPresented = false
        aiKeyDraft = ""
        aiSettingsError = nil
        connectionTestState = .idle
        isAPIKeyVisible = false
    }

    func saveAISettings() {
        let configuration = LLMConfiguration(
            preset: aiPresetDraft,
            baseURLString: aiBaseURLDraft,
            model: aiModelDraft,
            reasoningEnabled: aiReasoningEnabledDraft,
            reasoningEffort: aiReasoningEffortDraft
        )
        guard configuration.isComplete else {
            aiSettingsError = "Enter a valid HTTPS Base URL and model."
            return
        }
        guard LLMConfigurationStore.save(configuration, defaults: defaults) else {
            aiSettingsError = "This Base URL is not allowed. Remove credentials and query parameters."
            return
        }
        llmConfiguration = configuration
        let trimmedKey = aiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            do {
                try keychain.save(trimmedKey)
            } catch {
                aiSettingsError = "Could not save the API key."
                return
            }
        }
        aiKeyDraft = ""
        let currentKey: String?
        do {
            currentKey = try keychain.read()
        } catch {
            aiSettingsError = "Could not read the API key from Keychain."
            return
        }
        hasAPIKey = currentKey?.isEmpty == false
        apiKeySuffix = keySuffix(currentKey)
        aiSettingsError = nil
        connectionTestState = .idle
        isAPIKeyVisible = false
        invalidateAIPlan()
        rebuildDocumentNow()

        if !hasAPIKey, !llmConfiguration.isLocalEndpoint {
            aiSettingsError = "Endpoint saved. Add an API key to enable AI."
            return
        }
        isAISettingsPresented = false
    }

    func clearAPIKey() {
        do {
            try keychain.delete()
            let remaining = try keychain.read()
            if let remaining, !remaining.isEmpty {
                hasAPIKey = true
                apiKeySuffix = keySuffix(remaining)
                aiSettingsError = "Could not remove the key from Keychain."
                return
            }
        } catch {
            aiSettingsError = "Could not remove the key from Keychain."
            return
        }
        hasAPIKey = false
        apiKeySuffix = nil
        isAPIKeyVisible = false
        aiKeyDraft = ""
        connectionTestState = .idle
        aiSettingsError = nil
        if !llmConfiguration.isLocalEndpoint {
            invalidateAIPlan()
            rebuildDocumentNow()
        }
    }

    private func keySuffix(_ key: String?) -> String? {
        guard let key, !key.isEmpty else { return nil }
        return key.count >= 4 ? String(key.suffix(4)) : "••••"
    }

    private func invalidateConnectionTest() {
        if connectionTestState != .idle {
            connectionTestState = .idle
        }
        if aiSettingsError != nil {
            aiSettingsError = nil
        }
    }

    func testConnection() {
        let configuration = LLMConfiguration(
            preset: aiPresetDraft,
            baseURLString: aiBaseURLDraft,
            model: aiModelDraft,
            reasoningEnabled: aiReasoningEnabledDraft,
            reasoningEffort: aiReasoningEffortDraft
        )
        let draft = aiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = ((try? keychain.read()) ?? nil) ?? ""
        let key = draft.isEmpty ? stored : draft
        guard configuration.isComplete,
              !key.isEmpty || configuration.isLocalEndpoint else {
            connectionTestState = .failure("Configure a valid endpoint, model, and key.")
            return
        }

        connectionTestState = .testing
        let sample = ScriptTokenizer.tokenize("Hello. This is a short connection test.")
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.coordinator.testConnection(
                    configuration: configuration,
                    apiKey: key,
                    sample: sample,
                    wordsPerMinute: 120
                )
                DispatchQueue.main.async {
                    self.connectionTestState = .success
                }
            } catch {
                let message: String
                if let phraseError = error as? PhrasePlanningError {
                    switch phraseError {
                    case .unauthorized:
                        message = "API key rejected."
                    case .rateLimited:
                        message = "Rate limited. Try again shortly."
                    case .timeout, .network:
                        message = "Connection failed. Check the endpoint and network."
                    case .truncated:
                        message = "The test response was truncated."
                    case .server(let code):
                        message = "Connection failed (HTTP \(code))."
                    case .notConfigured:
                        message = "Configure a valid endpoint, model, and key."
                    case .cancelled:
                        message = "Connection test cancelled."
                    case .invalidResponse, .invalidPlan:
                        message = "The endpoint returned an unusable response."
                    }
                } else {
                    message = "Connection failed. Check the endpoint and model."
                }
                DispatchQueue.main.async {
                    self.connectionTestState = .failure(message)
                }
            }
        }
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
