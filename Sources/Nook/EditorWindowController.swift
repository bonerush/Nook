import AppKit
import Combine
import SwiftUI

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel, actions: EditorActions) {
        self.model = model

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

        super.init(window: window)
        window.delegate = self

        model.$isAISettingsPresented
            .dropFirst()
            .sink { [weak self] presented in
                guard !presented else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    self?.focusScriptEditor()
                }
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        model.cancelPlanning()
    }

    func showAndFocus() {
        guard let window else { return }

        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // The SwiftUI TextEditor is backed by an NSTextView. Focus it after the
        // first layout pass so the writer can start typing immediately.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.focusScriptEditor()
        }
    }

    private func focusScriptEditor() {
        guard let window,
              let textView = window.contentView?.nookFirstEditableTextView else {
            return
        }
        window.makeFirstResponder(textView)
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
