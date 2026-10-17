import Foundation

public enum LLMProviderPreset: String, Codable, CaseIterable, Equatable, Hashable {
    case openAI
    case deepSeek
    case openRouter
    case custom

    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        case .openRouter: return "OpenRouter"
        case .custom: return "Custom"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .deepSeek: return "https://api.deepseek.com/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }
}

public struct LLMConfiguration: Codable, Equatable {
    public var preset: LLMProviderPreset
    public var baseURLString: String
    public var model: String

    public init(
        preset: LLMProviderPreset,
        baseURLString: String,
        model: String
    ) {
        self.preset = preset
        self.baseURLString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedComponents: URLComponents? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              ["https", "http"].contains(scheme) else {
            return nil
        }
        // Credentials and query parameters must never be stored in the base
        // URL. They belong in Keychain or in headers, not UserDefaults.
        guard components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }
        if scheme == "http" {
            let local = host == "localhost" || host == "127.0.0.1" || host == "::1"
            guard local else { return nil }
        }
        return components
    }

    public var endpointURL: URL? {
        guard var components = parsedComponents else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            components.path = "/" + path
        } else if path.isEmpty {
            components.path = "/chat/completions"
        } else {
            components.path = "/" + path + "/chat/completions"
        }
        components.query = nil
        components.fragment = nil
        return components.url
    }

    public var isLocalEndpoint: Bool {
        guard let host = parsedComponents?.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    public var isComplete: Bool {
        !model.isEmpty && endpointURL != nil
    }
}

public enum LLMConfigurationStore {
    private static let key = "nook.llm.configuration.v1"

    public static func load(defaults: UserDefaults = .standard) -> LLMConfiguration {
        guard let data = defaults.data(forKey: key),
              let config = try? JSONDecoder().decode(LLMConfiguration.self, from: data) else {
            return LLMConfiguration(preset: .custom, baseURLString: "", model: "")
        }
        // Never surface a legacy URL that may carry embedded credentials.
        if !config.baseURLString.isEmpty, config.endpointURL == nil {
            return LLMConfiguration(preset: .custom, baseURLString: "", model: config.model)
        }
        return config
    }

    @discardableResult
    public static func save(
        _ config: LLMConfiguration,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let hasBaseURL = !config.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasBaseURL, config.endpointURL == nil {
            return false
        }
        guard let data = try? JSONEncoder().encode(config) else {
            return false
        }
        defaults.set(data, forKey: key)
        return true
    }
}
