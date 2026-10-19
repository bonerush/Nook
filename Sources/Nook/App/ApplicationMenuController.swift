import AppKit

/// Builds the application menu. Every toolbar action has a command here, as
/// the macOS toolbars guidance requires. Keyboard equivalents avoid the global
/// Carbon hotkeys so the two systems never double-fire.
@MainActor
final class ApplicationMenuController: NSObject {
    struct Actions {
        let openEditor: () -> Void
        let openAISettings: () -> Void
        let toggleInspector: () -> Void
        let togglePanel: () -> Void
        let start: () -> Void
        let togglePlayback: () -> Void
        let restart: () -> Void
        let previous: () -> Void
        let next: () -> Void
    }

    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        super.init()
    }

    func install() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Nook")
        appMenuItem.submenu = appMenu

        appMenu.addItem(item("关于 Nook", action: #selector(showAbout)))
        appMenu.addItem(.separator())
        appMenu.addItem(
            item(
                "AI 设置…",
                action: #selector(openAISettings),
                key: ",",
                modifiers: [.command]
            )
        )
        appMenu.addItem(
            item(
                "打开编辑器",
                action: #selector(openEditor),
                key: "e",
                modifiers: [.command]
            )
        )
        appMenu.addItem(.separator())

        let quitItem = item("退出 Nook", action: #selector(quit), key: "q", modifiers: [.command])
        appMenu.addItem(quitItem)

        mainMenu.addItem(editMenu())
        mainMenu.addItem(promptMenu())
        mainMenu.addItem(viewMenu())
        let windowItem = windowMenu()
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowItem.submenu
    }

    private func editMenu() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let menu = NSMenu(title: "编辑")
        menuItem.submenu = menu

        let undo = NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        undo.keyEquivalentModifierMask = [.command]
        menu.addItem(undo)

        let redo = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())

        let cut = NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        cut.keyEquivalentModifierMask = [.command]
        menu.addItem(cut)

        let copy = NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        copy.keyEquivalentModifierMask = [.command]
        menu.addItem(copy)

        let paste = NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        paste.keyEquivalentModifierMask = [.command]
        menu.addItem(paste)

        let selectAll = NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        selectAll.keyEquivalentModifierMask = [.command]
        menu.addItem(selectAll)

        return menuItem
    }

    private func promptMenu() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let menu = NSMenu(title: "提词")
        menuItem.submenu = menu

        let start = item("开始提词", action: #selector(start), key: "\r", modifiers: [.command])
        menu.addItem(start)
        menu.addItem(item("播放 / 暂停   ⌃⌥Space", action: #selector(togglePlayback)))
        menu.addItem(item("重新开始   ⌃⌥R", action: #selector(restart)))
        menu.addItem(.separator())
        menu.addItem(item("上一句   ⌃⌥←", action: #selector(previous)))
        menu.addItem(item("下一句   ⌃⌥→", action: #selector(next)))

        return menuItem
    }

    private func viewMenu() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let menu = NSMenu(title: "显示")
        menuItem.submenu = menu

        menu.addItem(
            item(
                "显示 / 隐藏检查器",
                action: #selector(toggleInspector),
                key: "i",
                modifiers: [.command, .option]
            )
        )
        menu.addItem(
            item(
                "显示 / 隐藏提词窗",
                action: #selector(togglePanel),
                key: "h",
                modifiers: [.command, .option]
            )
        )
        menu.addItem(.separator())

        let fullScreen = NSMenuItem(
            title: "进入全屏幕",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(fullScreen)

        return menuItem
    }

    private func windowMenu() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let menu = NSMenu(title: "窗口")
        menuItem.submenu = menu

        let minimize = NSMenuItem(
            title: "最小化",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        minimize.keyEquivalentModifierMask = [.command]
        menu.addItem(minimize)

        let zoom = NSMenuItem(title: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(zoom)
        menu.addItem(.separator())

        let close = NSMenuItem(
            title: "关闭窗口",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        close.keyEquivalentModifierMask = [.command]
        menu.addItem(close)

        return menuItem
    }

    private func item(
        _ title: String,
        action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        menuItem.keyEquivalentModifierMask = modifiers
        return menuItem
    }

    @objc private func openEditor() { actions.openEditor() }
    @objc private func openAISettings() { actions.openAISettings() }
    @objc private func toggleInspector() { actions.toggleInspector() }
    @objc private func togglePanel() { actions.togglePanel() }
    @objc private func start() { actions.start() }
    @objc private func togglePlayback() { actions.togglePlayback() }
    @objc private func restart() { actions.restart() }
    @objc private func previous() { actions.previous() }
    @objc private func next() { actions.next() }
    @objc private func quit() { NSApp.terminate(nil) }

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
