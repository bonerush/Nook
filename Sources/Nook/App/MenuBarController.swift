import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    struct Actions {
        let openEditor: () -> Void
        let togglePlayback: () -> Void
        let restart: () -> Void
        let previous: () -> Void
        let next: () -> Void
        let speedUp: () -> Void
        let speedDown: () -> Void
        let togglePanel: () -> Void
        let toggleCapture: () -> Void
        let quit: () -> Void
    }

    private let model: AppModel
    private let engine: PlaybackEngine
    private let panel: TeleprompterController
    private let actions: Actions

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var cancellable: AnyCancellable?

    private var headerItem: NSMenuItem!
    private var playPauseItem: NSMenuItem!
    private var restartItem: NSMenuItem!
    private var previousItem: NSMenuItem!
    private var nextItem: NSMenuItem!
    private var speedUpItem: NSMenuItem!
    private var speedDownItem: NSMenuItem!
    private var visibilityItem: NSMenuItem!
    private var captureItem: NSMenuItem!

    init(
        model: AppModel,
        engine: PlaybackEngine,
        panel: TeleprompterController,
        actions: Actions
    ) {
        self.model = model
        self.engine = engine
        self.panel = panel
        self.actions = actions
        super.init()
    }

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        updateIcon(playing: false)

        statusMenu = NSMenu(title: "Nook")
        statusMenu.autoenablesItems = false
        statusMenu.delegate = self
        statusMenu.minimumWidth = 250

        headerItem = NSMenuItem(title: "Nook", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        statusMenu.addItem(headerItem)
        statusMenu.addItem(.separator())

        statusMenu.addItem(item("打开编辑器…", action: #selector(openEditorAction)))
        statusMenu.addItem(.separator())

        playPauseItem = item("播放提词", action: #selector(togglePlaybackAction))
        statusMenu.addItem(playPauseItem)
        restartItem = item("重新开始", action: #selector(restartAction))
        statusMenu.addItem(restartItem)
        previousItem = item("上一句", action: #selector(previousAction))
        statusMenu.addItem(previousItem)
        nextItem = item("下一句", action: #selector(nextAction))
        statusMenu.addItem(nextItem)

        statusMenu.addItem(.separator())

        speedUpItem = item("加快语速  +5 WPM", action: #selector(speedUpAction))
        statusMenu.addItem(speedUpItem)
        speedDownItem = item("放慢语速  −5 WPM", action: #selector(speedDownAction))
        statusMenu.addItem(speedDownItem)

        statusMenu.addItem(.separator())

        visibilityItem = item("隐藏提词窗", action: #selector(togglePanelAction))
        statusMenu.addItem(visibilityItem)
        captureItem = item("屏幕共享时隐藏", action: #selector(toggleCaptureAction))
        statusMenu.addItem(captureItem)

        statusMenu.addItem(.separator())
        statusMenu.addItem(item("退出 Nook", action: #selector(quitAction)))

        statusItem.menu = statusMenu

        cancellable = engine.$isPlaying
            .removeDuplicates()
            .sink { [weak self] playing in
                MainActor.assumeIsolated {
                    self?.updateIcon(playing: playing)
                }
            }
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
        visibilityItem.title = panel.isPresented
            ? "隐藏提词窗   ⌃⌥H"
            : "显示提词窗   ⌃⌥H"

        playPauseItem.isEnabled = hasContent
        restartItem.isEnabled = hasContent
        previousItem.isEnabled = hasContent
        nextItem.isEnabled = hasContent
        speedUpItem.isEnabled = hasContent && model.wordsPerMinute < 200
        speedDownItem.isEnabled = hasContent && model.wordsPerMinute > 90
        visibilityItem.isEnabled = hasContent || panel.isPresented
        captureItem.state = model.hideFromCapture ? .on : .off
    }

    func updateIcon(playing: Bool) {
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

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openEditorAction() { actions.openEditor() }
    @objc private func togglePlaybackAction() { actions.togglePlayback() }
    @objc private func restartAction() { actions.restart() }
    @objc private func previousAction() { actions.previous() }
    @objc private func nextAction() { actions.next() }
    @objc private func speedUpAction() { actions.speedUp() }
    @objc private func speedDownAction() { actions.speedDown() }
    @objc private func togglePanelAction() { actions.togglePanel() }
    @objc private func toggleCaptureAction() { actions.toggleCapture() }
    @objc private func quitAction() { actions.quit() }
}
