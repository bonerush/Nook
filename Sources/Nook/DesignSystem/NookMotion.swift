import SwiftUI

/// Central motion table. Apple's spring presets all run for 0.5 s; the shorter
/// durations below are the perceived hand-off time we want for UI feedback.
/// Each view reads `accessibilityReduceMotion` and passes it to `resolved`.
enum NookMotion {
    static let entrance = Animation.smooth(duration: 0.5)
    static let inspector = Animation.snappy(duration: 0.3)
    static let selection = Animation.snappy(duration: 0.22)
    static let press = Animation.snappy(duration: 0.18)
    static let hover = Animation.smooth(duration: 0.16)
    static let counter = Animation.snappy(duration: 0.28)
    static let document = Animation.snappy(duration: 0.30)
    static let panel = Animation.smooth(duration: 0.42)
    static let handoff = Animation.snappy(duration: 0.20)

    /// Reduce Motion replaces movement with a near-instant fade.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? .linear(duration: 0.01) : animation
    }
}

final class EntranceState: ObservableObject {
    @Published var visible = false
}
