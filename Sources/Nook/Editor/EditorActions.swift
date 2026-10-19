import Foundation

/// The editor's outbound intents. Keeping them in a small value type means the
/// views never reach into the coordinator or the app delegate.
struct EditorActions {
    let start: () -> Void
    let startLocal: () -> Void
    let retryAI: () -> Void
    let openAISettings: () -> Void
}
