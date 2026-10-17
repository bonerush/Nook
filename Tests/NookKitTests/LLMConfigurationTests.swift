import Foundation

func runLLMConfigurationTests() {
    let config = LLMConfiguration(
        preset: .openAI,
        baseURLString: "https://api.openai.com/v1",
        model: "gpt-4.1-mini"
    )
    checkEqual(
        config.endpointURL?.absoluteString,
        "https://api.openai.com/v1/chat/completions",
        "Endpoint appends chat/completions"
    )
    check(config.isComplete, "Base URL and model complete the configuration")

    let fullEndpoint = LLMConfiguration(
        preset: .custom,
        baseURLString: "https://example.com/v1/chat/completions",
        model: "model"
    )
    checkEqual(
        fullEndpoint.endpointURL?.absoluteString,
        "https://example.com/v1/chat/completions",
        "A full chat/completions endpoint is not appended twice"
    )

    let local = LLMConfiguration(
        preset: .custom,
        baseURLString: "http://127.0.0.1:8080/v1",
        model: "local"
    )
    check(local.endpointURL != nil, "Localhost HTTP is allowed")
    check(local.isComplete, "Localhost config is complete")

    let insecure = LLMConfiguration(
        preset: .custom,
        baseURLString: "http://example.com/v1",
        model: "model"
    )
    check(insecure.endpointURL == nil, "Public HTTP is rejected")
    check(insecure.isComplete == false, "Insecure config is not complete")

    let defaults = UserDefaults(suiteName: "app.nook.llm-tests")!
    defaults.removePersistentDomain(forName: "app.nook.llm-tests")
    LLMConfigurationStore.save(config, defaults: defaults)
    let loaded = LLMConfigurationStore.load(defaults: defaults)
    checkEqual(loaded, config, "Configuration round-trips through UserDefaults")
    let encoded = String(data: try! JSONEncoder().encode(config), encoding: .utf8) ?? ""
    check(!encoded.lowercased().contains("apikey"), "Configuration never contains a key field")

    let unsafe = LLMConfiguration(
        preset: .custom,
        baseURLString: "https://user:secret@example.com/v1?token=leak",
        model: "model"
    )
    check(unsafe.endpointURL == nil, "Userinfo and query credentials are rejected")
    check(unsafe.isComplete == false, "Credential-bearing URL is not usable")
    defaults.removePersistentDomain(forName: "app.nook.llm-tests")
    check(
        LLMConfigurationStore.save(unsafe, defaults: defaults) == false,
        "Unsafe configuration is not persisted"
    )
    check(
        defaults.data(forKey: "nook.llm.configuration.v1") == nil,
        "No unsafe bytes reach UserDefaults"
    )

    let unsafeHTTP = LLMConfiguration(
        preset: .custom,
        baseURLString: "https://example.com/v1?api_key=dynamic",
        model: "model"
    )
    check(unsafeHTTP.endpointURL == nil, "Query parameters are always rejected")

    let service = "app.nook.tests.keychain.\(UUID().uuidString)"
    let store = KeychainStore(service: service, account: "api-key")
    defer { try? store.delete() }
    try! store.save("sk-test-value")
    checkEqual(try! store.read(), "sk-test-value", "Keychain secret round-trips")
    try! store.save("sk-updated")
    checkEqual(try! store.read(), "sk-updated", "Keychain secret updates")
    try! store.delete()
    check(try! store.read() == nil, "Deleted key is absent")
}
