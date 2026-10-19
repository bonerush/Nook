import AppKit
import Combine
import SwiftUI

@MainActor
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
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.backgroundColor = NSColor(
            calibratedRed: 0xF5 / 255.0,
            green: 0xF5 / 255.0,
            blue: 0xF7 / 255.0,
            alpha: 1
        )
        window.appearance = NSAppearance(named: .aqua)
        window.minSize = NookMetrics.windowMin
        window.contentMinSize = NookMetrics.windowMin
        window.setContentSize(NookMetrics.windowDefault)
        window.center()

        super.init(window: window)
        window.delegate = self

        model.$isAISettingsPresented
            .dropFirst()
            .sink { [weak self] presented in
                guard !presented else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    MainActor.assumeIsolated {
                        self?.focusScriptEditor()
                    }
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
            MainActor.assumeIsolated {
                self?.focusScriptEditor()
            }
        }
    }

    private func focusScriptEditor() {
        guard !model.isAISettingsPresented,
              let window,
              let textView = window.contentView?.nookFirstEditableTextView else {
            return
        }
        window.makeFirstResponder(textView)
        configureScriptScrollView(textView)
    }

    /// SwiftUI's TextEditor does not always honor scrollIndicators(.hidden)
    /// on macOS. The script is a prose surface, so remove the NSScrollView
    /// scroller while keeping trackpad/wheel scrolling intact.
    private func configureScriptScrollView(_ textView: NSTextView) {
        guard let scrollView = textView.enclosingScrollView else { return }
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.horizontalScroller?.alphaValue = 0
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
