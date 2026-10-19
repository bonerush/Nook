import AppKit

/// Wires the Carbon global hotkeys and the hover-only bare keys to the editor
/// coordinator. The Carbon manager stays a small, testable object.
@MainActor
final class HotKeyRouter {
    private var manager: GlobalHotKeyManager?
    private var observer: NSObjectProtocol?

    func install(
        panel: TeleprompterController,
        handler: @escaping (NookHotKeyAction) -> Void
    ) {
        let manager = GlobalHotKeyManager()
        manager.install()
        panel.onHoverChanged = { [weak manager] hovering in
            manager?.setHoverActive(hovering)
        }
        self.manager = manager

        observer = NotificationCenter.default.addObserver(
            forName: .nookHotKeyPressed,
            object: nil,
            queue: .main
        ) { notification in
            guard let raw = notification.userInfo?["action"] as? Int,
                  let action = NookHotKeyAction(rawValue: UInt32(raw)) else {
                return
            }
            MainActor.assumeIsolated {
                handler(action)
            }
        }
    }

    func uninstall() {
        manager?.uninstall()
        manager = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}
