import Foundation

enum ConnectionTestState: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

/// All state owned by the AI settings sheet: provider drafts, the Keychain
/// reference, and the connection test. Keeping it separate means typing in the
/// sheet never invalidates the editor's document pipeline.
@MainActor
final class AISettingsModel: ObservableObject {
    @Published var baseURLDraft: String {
        didSet { invalidateConnectionTest() }
    }
    @Published var modelDraft: String {
        didSet { invalidateConnectionTest() }
    }
    @Published var presetDraft: LLMProviderPreset {
        didSet { invalidateConnectionTest() }
    }
    @Published var reasoningEnabledDraft: Bool {
        didSet { invalidateConnectionTest() }
    }
    @Published var reasoningEffortDraft: LLMReasoningEffort {
        didSet { invalidateConnectionTest() }
    }
    @Published var keyDraft = "" {
        didSet { invalidateConnectionTest() }
    }
    @Published var isKeyVisible = false

    @Published private(set) var configuration: LLMConfiguration
    @Published private(set) var hasAPIKey: Bool
    @Published private(set) var keySuffix: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var testState: ConnectionTestState = .idle

    /// Called after the configuration or the key changes. The editor uses it to
    /// drop a plan that belongs to the old provider.
    var onChange: (() -> Void)?

    private let defaults: UserDefaults
    private let keychain: SecretStore
    private let coordinator: AIPlanningCoordinator
    private var testTask: Task<Void, Never>?
    private var testGeneration = 0

    init(
        defaults: UserDefaults = .standard,
        secretStore: SecretStore = KeychainStore(),
        coordinator: AIPlanningCoordinator
    ) {
        self.defaults = defaults
        self.keychain = secretStore
        self.coordinator = coordinator

        let configuration = LLMConfigurationStore.load(defaults: defaults)
        self.configuration = configuration
        self.baseURLDraft = configuration.baseURLString
        self.modelDraft = configuration.model
        self.presetDraft = configuration.preset
        self.reasoningEnabledDraft = configuration.reasoningEnabled
        self.reasoningEffortDraft = configuration.reasoningEffort

        let storedKey = (try? secretStore.read()) ?? nil
        self.hasAPIKey = storedKey?.isEmpty == false
        self.keySuffix = Self.suffix(of: storedKey)
    }

    var canUseAI: Bool {
        configuration.isComplete && (hasAPIKey || configuration.isLocalEndpoint)
    }

    func readKey() -> String? {
        (try? keychain.read()) ?? nil
    }

    // MARK: Sheet lifecycle

    func open() {
        testTask?.cancel()
        testGeneration += 1
        baseURLDraft = configuration.baseURLString
        modelDraft = configuration.model
        presetDraft = configuration.preset
        reasoningEnabledDraft = configuration.reasoningEnabled
        reasoningEffortDraft = configuration.reasoningEffort
        keyDraft = ""
        errorMessage = nil
        testState = .idle
        isKeyVisible = false
    }

    func close() {
        testTask?.cancel()
        testGeneration += 1
        keyDraft = ""
        errorMessage = nil
        testState = .idle
        isKeyVisible = false
    }

    // MARK: Saving

    /// Saves the endpoint and, when the user typed one, the key. Returns true
    /// only when the sheet can close: endpoint valid and AI usable, or a local
    /// endpoint that needs no key.
    @discardableResult
    func save() -> Bool {
        testTask?.cancel()
        testGeneration += 1
        let next = LLMConfiguration(
            preset: presetDraft,
            baseURLString: baseURLDraft,
            model: modelDraft,
            reasoningEnabled: reasoningEnabledDraft,
            reasoningEffort: reasoningEffortDraft
        )
        guard next.isComplete else {
            errorMessage = "Enter a valid HTTPS Base URL and model."
            return false
        }
        guard LLMConfigurationStore.save(next, defaults: defaults) else {
            errorMessage = "This Base URL is not allowed. Remove credentials and query parameters."
            return false
        }
        configuration = next

        let trimmedKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            do {
                try keychain.save(trimmedKey)
            } catch {
                errorMessage = "Could not save the API key."
                return false
            }
        }
        keyDraft = ""
        refreshKeyState()
        errorMessage = nil
        testState = .idle
        isKeyVisible = false
        onChange?()

        if !hasAPIKey, !configuration.isLocalEndpoint {
            errorMessage = "Endpoint saved. Add an API key to enable AI."
            return false
        }
        return true
    }

    func clearKey() {
        testTask?.cancel()
        testGeneration += 1
        do {
            try keychain.delete()
            let remaining = try keychain.read()
            if let remaining, !remaining.isEmpty {
                hasAPIKey = true
                keySuffix = Self.suffix(of: remaining)
                errorMessage = "Could not remove the key from Keychain."
                return
            }
        } catch {
            errorMessage = "Could not remove the key from Keychain."
            return
        }
        hasAPIKey = false
        keySuffix = nil
        isKeyVisible = false
        keyDraft = ""
        testState = .idle
        errorMessage = nil
        if !configuration.isLocalEndpoint {
            onChange?()
        }
    }

    // MARK: Connection test

    func testConnection() {
        let next = LLMConfiguration(
            preset: presetDraft,
            baseURLString: baseURLDraft,
            model: modelDraft,
            reasoningEnabled: reasoningEnabledDraft,
            reasoningEffort: reasoningEffortDraft
        )
        let draftKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedKey = readKey() ?? ""
        let key = draftKey.isEmpty ? storedKey : draftKey

        guard next.isComplete,
              !key.isEmpty || next.isLocalEndpoint else {
            testState = .failure("Configure a valid endpoint, model, and key.")
            return
        }

        testTask?.cancel()
        testGeneration += 1
        let generation = testGeneration
        testState = .testing
        let sample = ScriptTokenizer.tokenize("Hello. This is a short connection test.")
        testTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.coordinator.testConnection(
                    configuration: next,
                    apiKey: key,
                    sample: sample,
                    wordsPerMinute: 120
                )
                guard generation == self.testGeneration else { return }
                self.testState = .success
            } catch {
                guard generation == self.testGeneration else { return }
                self.testState = .failure(Self.message(for: error))
            }
        }
    }

    // MARK: Helpers

    private func refreshKeyState() {
        let stored = readKey()
        hasAPIKey = stored?.isEmpty == false
        keySuffix = Self.suffix(of: stored)
    }

    private func invalidateConnectionTest() {
        if testState != .idle {
            testState = .idle
        }
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    private static func suffix(of key: String?) -> String? {
        guard let key, !key.isEmpty else { return nil }
        return key.count >= 4 ? String(key.suffix(4)) : "••••"
    }

    private static func message(for error: Error) -> String {
        guard let phraseError = error as? PhrasePlanningError else {
            return "Connection failed. Check the endpoint and model."
        }
        switch phraseError {
        case .unauthorized:
            return "API key rejected."
        case .rateLimited:
            return "Rate limited. Try again shortly."
        case .timeout, .network:
            return "Connection failed. Check the endpoint and network."
        case .truncated:
            return "The test response was truncated."
        case .server(let code):
            return "Connection failed (HTTP \(code))."
        case .notConfigured:
            return "Configure a valid endpoint, model, and key."
        case .cancelled:
            return "Connection test cancelled."
        case .invalidResponse, .invalidPlan:
            return "The endpoint returned an unusable response."
        }
    }
}
