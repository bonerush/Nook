import AppKit
import SwiftUI

/// A plain-text writing surface with exact control over typography and
/// scrollers. SwiftUI's TextEditor keeps re-enabling the NSScrollView scroller
/// on macOS, which draws a dark bar over the paper; this wrapper owns the text
/// view instead, so the writing surface stays quiet at every window size.
struct ScriptTextView: NSViewRepresentable {
    @Binding var text: String

    private let fontSize: CGFloat = 17
    private let lineSpacing: CGFloat = 8

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 14, right: 0)

        let textView = NSTextView()
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 0, height: 3)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.insertionPointColor = NSColor(
            calibratedRed: 0x00 / 255.0,
            green: 0x7A / 255.0,
            blue: 0xFF / 255.0,
            alpha: 1
        )
        textView.setAccessibilityLabel("Script")
        textView.setAccessibilityHelp("Paste or edit the text you will read aloud.")
        textView.delegate = context.coordinator
        textView.string = text
        applyStyle(to: textView)
        context.coordinator.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            applyStyle(to: textView)
            let length = (text as NSString).length
            let safeLocation = min(selection.location, length)
            textView.setSelectedRange(
                NSRange(location: safeLocation, length: min(selection.length, length - safeLocation))
            )
        }
    }

    private func applyStyle(to textView: NSTextView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = 0

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor(
                calibratedRed: 0x1D / 255.0,
                green: 0x1D / 255.0,
                blue: 0x1F / 255.0,
                alpha: 0.92
            ),
            .paragraphStyle: paragraph
        ]

        textView.font = attributes[.font] as? NSFont
        textView.textColor = attributes[.foregroundColor] as? NSColor
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = attributes

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.textStorage?.setAttributes(attributes, range: fullRange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
