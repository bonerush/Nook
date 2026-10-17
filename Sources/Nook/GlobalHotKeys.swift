import AppKit
import Carbon

extension Notification.Name {
    static let nookHotKeyPressed = Notification.Name("app.nook.hotKeyPressed")
}

enum NookHotKeyAction: UInt32, CaseIterable {
    case togglePlayback = 1
    case previousLine = 2
    case nextLine = 3
    case speedUp = 4
    case speedDown = 5
    case restart = 6
    case togglePanel = 7
    case openEditor = 8

    var keyCode: UInt32 {
        switch self {
        case .togglePlayback: return UInt32(kVK_Space)
        case .previousLine: return UInt32(kVK_LeftArrow)
        case .nextLine: return UInt32(kVK_RightArrow)
        case .speedUp: return UInt32(kVK_UpArrow)
        case .speedDown: return UInt32(kVK_DownArrow)
        case .restart: return UInt32(kVK_ANSI_R)
        case .togglePanel: return UInt32(kVK_ANSI_H)
        case .openEditor: return UInt32(kVK_ANSI_E)
        }
    }

    var shortcutLabel: String {
        switch self {
        case .togglePlayback: return "⌃⌥Space"
        case .previousLine: return "⌃⌥←"
        case .nextLine: return "⌃⌥→"
        case .speedUp: return "⌃⌥↑"
        case .speedDown: return "⌃⌥↓"
        case .restart: return "⌃⌥R"
        case .togglePanel: return "⌃⌥H"
        case .openEditor: return "⌃⌥E"
        }
    }
}

final class GlobalHotKeyManager {
    private static let signature: OSType = 0x4E4F4F4B // 'NOOK'
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var installed = false

    func install() {
        guard !installed else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            nookHotKeyHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        guard handlerStatus == noErr else {
            NSLog("Nook: could not install global hotkey handler (\(handlerStatus))")
            return
        }

        let modifiers = UInt32(controlKey | optionKey)
        for action in NookHotKeyAction.allCases {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.rawValue)
            let status = RegisterEventHotKey(
                action.keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if status == noErr, let hotKeyRef {
                hotKeyRefs.append(hotKeyRef)
            } else {
                NSLog("Nook: could not register \(action.shortcutLabel) (status \(status))")
            }
        }

        installed = true
    }

    func uninstall() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        installed = false
    }

    deinit {
        uninstall()
    }
}

private func nookHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else { return noErr }

    let actionID = hotKeyID.id
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: .nookHotKeyPressed,
            object: nil,
            userInfo: ["action": Int(actionID)]
        )
    }

    return noErr
}
