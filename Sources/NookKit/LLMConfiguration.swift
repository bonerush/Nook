import Foundation

public enum LLMProviderPreset: String, Codable, CaseIterable, Equatable {
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

    public var endpointURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              ["https", "http"].contains(scheme) else {
            return nil
        }
        if scheme == "http" {
            let local = host == "localhost" || host == "127.0.0.1" || host == "::1"
            guard local else { return nil }
        }
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
        return config
    }

    public static func save(
        _ config: LLMConfiguration,
        defaults: UserDefaults = .standard
    ) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
    }
}
