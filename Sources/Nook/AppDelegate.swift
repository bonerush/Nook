import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var engine: PlaybackEngine!
    private var panelController: TeleprompterController!
    private var editorController: EditorWindowController?
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var hotKeyManager: GlobalHotKeyManager!
    private var cancellables = Set<AnyCancellable>()

    private var hotKeyObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?
    private var previousApp: NSRunningApplication?
    private var previewBackdrop: NSWindow?

    private var headerItem: NSMenuItem!
    private var playPauseItem: NSMenuItem!
    private var restartItem: NSMenuItem!
    private var previousItem: NSMenuItem!
    private var nextItem: NSMenuItem!
    private var speedUpItem: NSMenuItem!
    private var speedDownItem: NSMenuItem!
    private var visibilityItem: NSMenuItem!
    private var captureItem: NSMenuItem!

    private let forceVisibleInCapture =
        ProcessInfo.processInfo.environment["NOOK_CAPTURE_VISIBLE"] == "1"
    private let isDemo =
        CommandLine.arguments.contains("--demo")
        || ProcessInfo.processInfo.environment["NOOK_DEMO"] == "1"
    private let isPreviewSample = CommandLine.arguments.contains("--preview-sample")

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        let defaults: UserDefaults
        if isPreviewSample {
            let suite = "app.nook.design-preview"
            defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
        } else {
            defaults = .standard
        }
        model = AppModel(
            defaults: defaults,
            secretStore: isPreviewSample ? PreviewSecretStore() : KeychainStore()
        )
        engine = PlaybackEngine()
        panelController = TeleprompterController(
            model: model,
            engine: engine,
            forceVisibleInCapture: forceVisibleInCapture
        )

        configureMainMenu()
        if !isPreviewSample {
            configureStatusItem()
            installHotKeys()
            observeWorkspace()
        }
        observeScreens()
        observePlayback()

        if isPreviewSample && isDemo {
            installPreviewBackdrop()
        }

        if isDemo {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.panelController.show(autoplay: true)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.openEditor()
            }
        }

        if isPreviewSample && CommandLine.arguments.contains("--preview-ai-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.model.openAISettings()
            }
        }

        if isPreviewSample && isDemo && CommandLine.arguments.contains("--preview-paused") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.engine.pause()
            }
        }

        if isPreviewSample,
           !isDemo,
           CommandLine.arguments.contains("--preview-compact") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.editorController?.window?.setContentSize(
                    NSSize(width: 960, height: 680)
                )
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openEditor()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.uninstall()
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        panelController?.hide(animated: false, pause: true)
        previewBackdrop?.orderOut(nil)
    }

    // MARK: Preview stage

    private func installPreviewBackdrop() {
        guard previewBackdrop == nil else { return }
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
        previewBackdrop = window
    }

    // MARK: Menu bar item

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        updateStatusIcon(playing: false)

        statusMenu = NSMenu(title: "Nook")
        statusMenu.autoenablesItems = false
        statusMenu.delegate = self
        statusMenu.minimumWidth = 250

        headerItem = NSMenuItem(title: "Nook", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        statusMenu.addItem(headerItem)
        statusMenu.addItem(.separator())

        statusMenu.addItem(menuItem("打开编辑器…", action: #selector(openEditorFromMenu)))
        statusMenu.addItem(.separator())

        playPauseItem = menuItem("播放提词", action: #selector(togglePlaybackFromMenu))
        statusMenu.addItem(playPauseItem)
        restartItem = menuItem("重新开始", action: #selector(restartFromMenu))
        statusMenu.addItem(restartItem)
        previousItem = menuItem("上一句", action: #selector(previousLineFromMenu))
        statusMenu.addItem(previousItem)
        nextItem = menuItem("下一句", action: #selector(nextLineFromMenu))
        statusMenu.addItem(nextItem)

        statusMenu.addItem(.separator())

        speedUpItem = menuItem("加快语速  +5 WPM", action: #selector(speedUpFromMenu))
        statusMenu.addItem(speedUpItem)
        speedDownItem = menuItem("放慢语速  −5 WPM", action: #selector(speedDownFromMenu))
        statusMenu.addItem(speedDownItem)

        statusMenu.addItem(.separator())

        visibilityItem = menuItem("隐藏提词窗", action: #selector(toggleVisibilityFromMenu))
        statusMenu.addItem(visibilityItem)
        captureItem = menuItem("屏幕共享时隐藏", action: #selector(toggleCaptureFromMenu))
        statusMenu.addItem(captureItem)

        statusMenu.addItem(.separator())
        statusMenu.addItem(menuItem("退出 Nook", action: #selector(quitFromMenu)))

        statusItem.menu = statusMenu
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusMenu else { return }

        let hasContent = model.hasContent
        let playLabel: String
        if engine.isPlaying {
            playLabel = "暂停提词"
        } else if engine.isFinished {
            playLabel = "从头播放"
        } else if engine.hasStarted {
            playLabel = "继续提词"
        } else {
            playLabel = "播放提词"
        }

        headerItem.title = "Nook   \(Int(model.wordsPerMinute.rounded())) WPM   ·   \(model.estimatedDurationLabel)"
        playPauseItem.title = "\(playLabel)   ⌃⌥Space"
        restartItem.title = "重新开始   ⌃⌥R"
        previousItem.title = "上一句   ⌃⌥←"
        nextItem.title = "下一句   ⌃⌥→"
        speedUpItem.title = "加快语速   +5 WPM   ⌃⌥↑"
        speedDownItem.title = "放慢语速   −5 WPM   ⌃⌥↓"
        visibilityItem.title = panelController.isPresented
            ? "隐藏提词窗   ⌃⌥H"
            : "显示提词窗   ⌃⌥H"

        playPauseItem.isEnabled = hasContent
        restartItem.isEnabled = hasContent
        previousItem.isEnabled = hasContent
        nextItem.isEnabled = hasContent
        speedUpItem.isEnabled = hasContent && model.wordsPerMinute < 200
        speedDownItem.isEnabled = hasContent && model.wordsPerMinute > 90
        visibilityItem.isEnabled = hasContent || panelController.isPresented
        captureItem.state = model.hideFromCapture ? .on : .off
    }

    private func updateStatusIcon(playing: Bool) {
        guard let button = statusItem?.button else { return }
        let symbol = playing ? "waveform" : "text.line.first.and.arrowtriangle.forward"
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: playing ? "Nook 正在提词" : "Nook 刘海提词器"
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
        button.toolTip = playing ? "Nook · 正在提词（⌃⌥Space 暂停）" : "Nook · ⌃⌥Space 播放"
    }

    // MARK: Main menu

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Nook")
        appMenuItem.submenu = appMenu

        appMenu.addItem(menuItem("关于 Nook", action: #selector(showAbout)))
        appMenu.addItem(.separator())

        let openEditorItem = menuItem("打开编辑器…", action: #selector(openEditorFromMenu))
        openEditorItem.keyEquivalent = ","
        openEditorItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(openEditorItem)

        appMenu.addItem(.separator())
        let quitItem = menuItem("退出 Nook", action: #selector(quitFromMenu))
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu

        let undo = NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        undo.keyEquivalentModifierMask = [.command]
        editMenu.addItem(undo)

        let redo = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())

        let cut = NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        cut.keyEquivalentModifierMask = [.command]
        editMenu.addItem(cut)

        let copy = NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        copy.keyEquivalentModifierMask = [.command]
        editMenu.addItem(copy)

        let paste = NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        paste.keyEquivalentModifierMask = [.command]
        editMenu.addItem(paste)

        let selectAll = NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        selectAll.keyEquivalentModifierMask = [.command]
        editMenu.addItem(selectAll)

        let promptMenuItem = NSMenuItem()
        mainMenu.addItem(promptMenuItem)
        let promptMenu = NSMenu(title: "提词")
        promptMenuItem.submenu = promptMenu

        let startItem = menuItem("开始提词", action: #selector(startFromMenu))
        startItem.keyEquivalent = "\r"
        startItem.keyEquivalentModifierMask = [.command]
        promptMenu.addItem(startItem)

        promptMenu.addItem(menuItem("播放 / 暂停   ⌃⌥Space", action: #selector(togglePlaybackFromMenu)))
        promptMenu.addItem(menuItem("重新开始   ⌃⌥R", action: #selector(restartFromMenu)))
        promptMenu.addItem(.separator())
        promptMenu.addItem(menuItem("上一句   ⌃⌥←", action: #selector(previousLineFromMenu)))
        promptMenu.addItem(menuItem("下一句   ⌃⌥→", action: #selector(nextLineFromMenu)))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenuItem.submenu = windowMenu

        let minimize = NSMenuItem(
            title: "最小化",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        minimize.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(minimize)

        let zoom = NSMenuItem(
            title: "缩放",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(zoom)

        let close = NSMenuItem(
            title: "关闭窗口",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        close.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(close)

        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    // MARK: Workspace and screen observation

    private func observeWorkspace() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular,
                  !app.isTerminated else {
                return
            }
            self.previousApp = app
        }
    }

    private func observeScreens() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.panelController.reposition()
        }
    }

    private func observePlayback() {
        engine.$isPlaying
            .removeDuplicates()
            .sink { [weak self] playing in
                self?.updateStatusIcon(playing: playing)
            }
            .store(in: &cancellables)
    }

    private func installHotKeys() {
        hotKeyManager = GlobalHotKeyManager()
        hotKeyManager.install()

        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .nookHotKeyPressed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?["action"] as? Int,
                  let action = NookHotKeyAction(rawValue: UInt32(raw)) else {
                return
            }
            self?.handleHotKey(action)
        }
    }

    private func handleHotKey(_ action: NookHotKeyAction) {
        switch action {
        case .togglePlayback:
            togglePlayback()
        case .previousLine:
            navigateLine(offset: -1)
        case .nextLine:
            navigateLine(offset: 1)
        case .speedUp:
            model.adjustSpeed(by: 5)
        case .speedDown:
            model.adjustSpeed(by: -5)
        case .restart:
            restartPlayback()
        case .togglePanel:
            togglePanelVisibility()
        case .openEditor:
            openEditor()
        }
    }

    // MARK: Actions

    private func openEditor() {
        capturePreviousApplication()
        if panelController.isPresented {
            panelController.hide(animated: true, pause: true)
        }

        let controller: EditorWindowController
        if let existing = editorController {
            controller = existing
        } else {
            let actions = EditorActions(
                start: { [weak self] in self?.startPrompter() },
                startLocal: { [weak self] in self?.startLocalPrompter() },
                retryAI: { [weak self] in self?.startPrompter() },
                openAISettings: { [weak self] in self?.model.openAISettings() }
            )
            let created = EditorWindowController(model: model, actions: actions)
            editorController = created
            controller = created
        }

        controller.showAndFocus()
    }

    private func startPrompter() {
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

    private func startLocalPrompter() {
        guard model.hasContent else {
            NSSound.beep()
            openEditor()
            return
        }
        model.startWithLocalPlan()
        presentPreparedPanel()
    }

    private func presentPreparedPanel() {
        hideEditorWindow()
        panelController.show(autoplay: true)
        reactivatePreviousApplication()
    }

    private func togglePlayback() {
        guard model.hasContent else {
            openEditor()
            return
        }

        if !panelController.isPresented {
            hideEditorWindow()
            panelController.show(autoplay: false)
            engine.play()
            reactivatePreviousApplication()
        } else {
            engine.toggle()
        }
    }

    private func navigateLine(offset: Int) {
        guard model.hasContent else {
            openEditor()
            return
        }

        if !panelController.isPresented {
            hideEditorWindow()
            panelController.show(autoplay: false)
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

    private func restartPlayback() {
        guard model.hasContent else {
            openEditor()
            return
        }

        hideEditorWindow()
        if panelController.isPresented {
            engine.restart(autoPlay: true)
        } else {
            panelController.show(autoplay: true)
        }
        reactivatePreviousApplication()
    }

    private func togglePanelVisibility() {
        if panelController.isPresented {
            panelController.hide()
            return
        }

        guard model.hasContent else {
            openEditor()
            return
        }

        hideEditorWindow()
        panelController.show(autoplay: false)
        reactivatePreviousApplication()
    }

    private func hideEditorWindow() {
        editorController?.window?.orderOut(nil)
    }

    private func capturePreviousApplication() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              front.activationPolicy == .regular,
              !front.isTerminated else {
            return
        }
        previousApp = front
    }

    private func reactivatePreviousApplication() {
        guard let app = previousApp,
              !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        app.activate(options: [])
    }

    // MARK: Menu selectors

    @objc private func openEditorFromMenu() { openEditor() }
    @objc private func startFromMenu() { startPrompter() }
    @objc private func togglePlaybackFromMenu() { togglePlayback() }
    @objc private func restartFromMenu() { restartPlayback() }
    @objc private func previousLineFromMenu() { navigateLine(offset: -1) }
    @objc private func nextLineFromMenu() { navigateLine(offset: 1) }
    @objc private func speedUpFromMenu() { model.adjustSpeed(by: 5) }
    @objc private func speedDownFromMenu() { model.adjustSpeed(by: -5) }
    @objc private func toggleVisibilityFromMenu() { togglePanelVisibility() }

    @objc private func toggleCaptureFromMenu() {
        model.hideFromCapture.toggle()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Nook"
        alert.informativeText = """
        刘海下的小型英文提词器。

        粘贴讲稿后，Nook 会按英文呼吸节奏自动断句；开始后视线停在镜头附近，用进度条掌握节奏。

        ⌃⌥Space  播放 / 暂停
        ⌃⌥← / →  上一句 / 下一句
        ⌃⌥↑ / ↓  语速
        ⌃⌥R      重新开始
        ⌃⌥H      显示 / 隐藏提词窗
        ⌃⌥E      打开编辑器
        """
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
private final class PreviewSecretStore: SecretStore {
    private var value: String?

    func read() throws -> String? {
        value
    }

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
