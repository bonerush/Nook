import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController {
    private let model: AppModel

    init(model: AppModel, onStart: @escaping () -> Void) {
        self.model = model

        let actions = EditorActions(start: onStart)
        let editorView = EditorView(model: model, actions: actions)
        let hostingController = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: hostingController)

        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "Nook"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.backgroundColor = NSColor(
            calibratedRed: 0.031,
            green: 0.035,
            blue: 0.043,
            alpha: 1
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 960, height: 680)
        window.contentMinSize = NSSize(width: 960, height: 680)
        window.setContentSize(NSSize(width: 1040, height: 720))
        window.center()

        // The Linear shell owns its own chrome and starts at the very top of
        // the window. Hide the native traffic lights so they cannot collide
        // with the wordmark; Close and Minimize remain available in the menus.
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndFocus() {
        guard let window else { return }

        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // The SwiftUI TextEditor is backed by an NSTextView. Focus it after the
        // first layout pass so the writer can start typing immediately.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak window] in
            guard let window, let textView = window.contentView?.nookFirstEditableTextView else {
                return
            }
            window.makeFirstResponder(textView)
        }
    }
}

private extension NSView {
    var nookFirstEditableTextView: NSTextView? {
        if let textView = self as? NSTextView,
           textView.isEditable,
           textView.isSelectable,
           !textView.isHidden {
            return textView
        }

        for subview in subviews {
            if let found = subview.nookFirstEditableTextView {
                return found
            }
        }
        return nil
    }
}
