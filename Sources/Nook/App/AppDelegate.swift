import AppKit
import Combine
import SwiftUI

/// Composition root. It creates the model, the panel, and the controllers,
/// then gets out of the way. UI behavior lives in the controllers.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preview = PreviewHarness()

    private var model: AppModel!
    private var engine: PlaybackEngine!
    private var panel: TeleprompterController!
    private var editor: EditorCoordinator!
    private var menus: ApplicationMenuController!
    private var menuBar: MenuBarController?
    private var hotKeys: HotKeyRouter?

    private var screenObserver: NSObjectProtocol?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        model = AppModel(
            defaults: preview.makeDefaults(),
            secretStore: preview.makeSecretStore()
        )
        engine = PlaybackEngine()
        panel = TeleprompterController(
            model: model,
            engine: engine,
            forceVisibleInCapture: preview.captureOverride
        )
        editor = EditorCoordinator(model: model, engine: engine, panel: panel)

        installMenus()
        if !preview.isPreviewSample {
            installMenuBar()
            installHotKeys()
        }
        observeScreens()

        if preview.isPreviewSample && preview.isDemo {
            preview.installBackdropIfNeeded()
        }

        preview.applyScenario(model: model, engine: engine, panel: panel, editor: editor)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        editor.openEditor()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.uninstall()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        panel.hide(animated: false, pause: true)
        preview.teardown()
    }

    // MARK: Assembly

    private func installMenus() {
        menus = ApplicationMenuController(
            actions: ApplicationMenuController.Actions(
                openEditor: { [weak self] in self?.editor.openEditor() },
                openAISettings: { [weak self] in self?.model.openAISettings() },
                toggleInspector: { [weak self] in self?.model.toggleInspector() },
                togglePanel: { [weak self] in self?.editor.togglePanel() },
                start: { [weak self] in self?.editor.start() },
                togglePlayback: { [weak self] in self?.editor.togglePlayback() },
                restart: { [weak self] in self?.editor.restart() },
                previous: { [weak self] in self?.editor.navigate(offset: -1) },
                next: { [weak self] in self?.editor.navigate(offset: 1) }
            )
        )
        menus.install()
    }

    private func installMenuBar() {
        let controller = MenuBarController(
            model: model,
            engine: engine,
            panel: panel,
            actions: MenuBarController.Actions(
                openEditor: { [weak self] in self?.editor.openEditor() },
                togglePlayback: { [weak self] in self?.editor.togglePlayback() },
                restart: { [weak self] in self?.editor.restart() },
                previous: { [weak self] in self?.editor.navigate(offset: -1) },
                next: { [weak self] in self?.editor.navigate(offset: 1) },
                speedUp: { [weak self] in self?.model.adjustSpeed(by: 5) },
                speedDown: { [weak self] in self?.model.adjustSpeed(by: -5) },
                togglePanel: { [weak self] in self?.editor.togglePanel() },
                toggleCapture: { [weak self] in self?.model.hideFromCapture.toggle() },
                quit: { NSApp.terminate(nil) }
            )
        )
        controller.install()
        menuBar = controller
    }

    private func installHotKeys() {
        let router = HotKeyRouter()
        router.install(panel: panel) { [weak self] action in
            self?.editor.handleHotKey(action)
        }
        hotKeys = router
    }

    private func observeScreens() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel.reposition()
            }
        }
    }
}
