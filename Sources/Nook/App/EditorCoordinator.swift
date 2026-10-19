import AppKit

/// Owns the editor window and the start-to-panel hand-off. It is the single
/// place that knows how the editor, the panel, and the previous application
/// relate to each other.
@MainActor
final class EditorCoordinator {
    private let model: AppModel
    private let engine: PlaybackEngine
    private let panel: TeleprompterController

    private var editorController: EditorWindowController?
    private var previousApp: NSRunningApplication?
    private var hideGeneration = 0
    private var workspaceObserver: NSObjectProtocol?

    init(model: AppModel, engine: PlaybackEngine, panel: TeleprompterController) {
        self.model = model
        self.engine = engine
        self.panel = panel
        installWorkspaceObserver()
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    var actions: EditorActions {
        EditorActions(
            start: { [weak self] in self?.start() },
            startLocal: { [weak self] in self?.startLocal() },
            retryAI: { [weak self] in self?.start() },
            openAISettings: { [weak self] in self?.model.openAISettings() }
        )
    }

    // MARK: Window

    func openEditor() {
        hideGeneration += 1
        editorController?.window?.alphaValue = 1
        capturePreviousApplication()
        if panel.isPresented {
            panel.hide(animated: true, pause: true)
        }

        let controller: EditorWindowController
        if let existing = editorController {
            controller = existing
        } else {
            let created = EditorWindowController(model: model, actions: actions)
            editorController = created
            controller = created
        }

        controller.showAndFocus()
    }

    func hideEditor(animated: Bool = false) {
        hideGeneration += 1
        let generation = hideGeneration
        guard let window = editorController?.window else { return }
        guard animated else {
            window.orderOut(nil)
            discardEditorWindow()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                guard generation == self.hideGeneration else { return }
                window.orderOut(nil)
                window.alphaValue = 1
                self.discardEditorWindow()
            }
        }
    }

    /// The editor is a full SwiftUI tree, so keeping it alive while the panel
    /// runs doubles the app's memory for no benefit. Release it once hidden and
    /// rebuild it on demand; AppModel holds the only state that matters.
    private func discardEditorWindow() {
        guard let controller = editorController else { return }
        editorController = nil
        controller.window?.contentViewController = nil
        controller.close()
    }

    func resizeWindow(to size: CGSize) {
        editorController?.window?.setContentSize(size)
    }

    // MARK: Start flow

    func start() {
        guard !model.isAISettingsPresented else { return }
        if case .planning = model.planningState { return }
        guard model.hasContent else {
            NSSound.beep()
            openEditor()
            return
        }
        model.prepareForStart { [weak self] result in
            guard let self else { return }
            switch result {
            case .ready:
                self.presentPreparedPanel()
            case .failed:
                // If Start was invoked from the menu while the editor was
                // hidden, surface the failure banner instead of looking dead.
                self.openEditor()
            }
        }
    }

    func startLocal() {
        guard model.hasContent else {
            NSSound.beep()
            openEditor()
            return
        }
        model.startWithLocalPlan()
        presentPreparedPanel()
    }

    private func presentPreparedPanel() {
        hideEditor(animated: true)
        panel.show(autoplay: true)
        reactivatePreviousApplication()
    }

    func togglePlayback() {
        guard model.hasContent else {
            openEditor()
            return
        }

        if !panel.isPresented {
            hideEditor(animated: true)
            panel.show(autoplay: false)
            engine.play()
            reactivatePreviousApplication()
        } else {
            engine.toggle()
        }
    }

    func navigate(offset: Int) {
        guard model.hasContent else {
            openEditor()
            return
        }

        if !panel.isPresented {
            hideEditor(animated: true)
            panel.show(autoplay: false)
            if offset < 0 {
                engine.previousLine()
            } else {
                engine.nextLine()
            }
            reactivatePreviousApplication()
        } else if offset < 0 {
            engine.previousLine()
        } else {
            engine.nextLine()
        }
    }

    func restart() {
        guard model.hasContent else {
            openEditor()
            return
        }

        hideEditor(animated: true)
        if panel.isPresented {
            engine.restart(autoPlay: true)
        } else {
            panel.show(autoplay: true)
        }
        reactivatePreviousApplication()
    }

    func togglePanel() {
        if panel.isPresented {
            panel.hide()
            return
        }

        guard model.hasContent else {
            openEditor()
            return
        }

        hideEditor(animated: true)
        panel.show(autoplay: false)
        reactivatePreviousApplication()
    }

    func handleHotKey(_ action: NookHotKeyAction) {
        switch action {
        case .togglePlayback:
            togglePlayback()
        case .previousLine:
            navigate(offset: -1)
        case .nextLine:
            navigate(offset: 1)
        case .speedUp:
            model.adjustSpeed(by: 5)
        case .speedDown:
            model.adjustSpeed(by: -5)
        case .restart:
            restart()
        case .togglePanel:
            togglePanel()
        case .openEditor:
            openEditor()
        }
    }

    // MARK: Previous application

    private func installWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            MainActor.assumeIsolated {
                self?.recordPreviousApplication(app)
            }
        }
    }

    private func recordPreviousApplication(_ app: NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular,
              !app.isTerminated else {
            return
        }
        previousApp = app
    }

    private func capturePreviousApplication() {
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        recordPreviousApplication(front)
    }

    private func reactivatePreviousApplication() {
        guard let app = previousApp,
              !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        app.activate(options: [])
    }
}
