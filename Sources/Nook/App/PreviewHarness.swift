import AppKit
import Combine
import SwiftUI

/// Owns every preview-only path so the production lifecycle stays readable.
/// Preview mode never reads the user's real defaults, script, or Keychain.
@MainActor
final class PreviewHarness {
    let isPreviewSample: Bool
    let isDemo: Bool
    let captureOverride: Bool

    private var backdrop: NSWindow?
    private var secret = PreviewSecretStore()

    init() {
        isPreviewSample = CommandLine.arguments.contains("--preview-sample")
        isDemo = CommandLine.arguments.contains("--demo")
            || ProcessInfo.processInfo.environment["NOOK_DEMO"] == "1"
        captureOverride = ProcessInfo.processInfo.environment["NOOK_CAPTURE_VISIBLE"] == "1"
    }

    func makeDefaults() -> UserDefaults {
        guard isPreviewSample else { return .standard }
        let suite = "app.nook.design-preview"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func makeSecretStore() -> SecretStore {
        isPreviewSample ? secret : KeychainStore()
    }

    func installBackdropIfNeeded() {
        guard isPreviewSample, isDemo, backdrop == nil else { return }
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else { return }
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .normal
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: PreviewBackdropView())
        window.orderFrontRegardless()
        backdrop = window
    }

    func applyScenario(
        model: AppModel,
        engine: PlaybackEngine,
        panel: TeleprompterController,
        editor: EditorCoordinator
    ) {
        if isDemo {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                panel.show(autoplay: true)
            }
        } else {
            DispatchQueue.main.async {
                editor.openEditor()
            }
        }

        guard isPreviewSample else { return }

        if CommandLine.arguments.contains("--preview-motion") {
            let steps: [(Double, @MainActor @Sendable () -> Void)] = [
                (0.9, { model.toggleInspector() }),
                (1.9, { model.toggleInspector() }),
                (2.9, { model.loadSample() }),
                (3.9, { model.toggleInspector() }),
                (4.7, { model.toggleInspector() })
            ]
            for (delay, action) in steps {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    action()
                }
            }
        }

        if CommandLine.arguments.contains("--preview-start") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                editor.start()
            }
        }

        if CommandLine.arguments.contains("--preview-empty") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                model.clearScript()
            }
        }

        if CommandLine.arguments.contains("--preview-no-inspector") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                model.isInspectorVisible = false
            }
        }

        if CommandLine.arguments.contains("--preview-ai-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                model.openAISettings()
            }
        }

        if isDemo, CommandLine.arguments.contains("--preview-paused") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                engine.pause()
            }
        }

        if !isDemo, CommandLine.arguments.contains("--preview-compact") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                editor.resizeWindow(to: NookMetrics.windowMin)
            }
        }
    }

    func teardown() {
        backdrop?.orderOut(nil)
        backdrop = nil
    }
}

final class PreviewSecretStore: SecretStore {
    private var value: String?

    func read() throws -> String? { value }

    func save(_ value: String) throws {
        self.value = value
    }

    func delete() throws {
        value = nil
    }
}

struct PreviewBackdropView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.13),
                    Color(red: 0.20, green: 0.24, blue: 0.52),
                    Color(red: 0.72, green: 0.40, blue: 0.28),
                    Color(red: 0.05, green: 0.06, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 18) {
                Text("NOOK")
                    .font(.system(size: 128, weight: .black, design: .rounded))
                    .tracking(-6)
                    .foregroundStyle(.white.opacity(0.10))
                Text("OFFICIAL GLASS · LYRIC STAGE")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.24))
            }

            Circle()
                .fill(Color(red: 0.48, green: 0.52, blue: 1.0).opacity(0.45))
                .frame(width: 460, height: 460)
                .blur(radius: 90)
                .offset(x: 330, y: -260)

            Circle()
                .fill(Color(red: 1.0, green: 0.62, blue: 0.36).opacity(0.30))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: -360, y: 210)
        }
        .ignoresSafeArea()
    }
}
