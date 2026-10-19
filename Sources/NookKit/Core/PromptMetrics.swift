import AppKit
import Foundation

// MARK: - Shared layout metrics

/// Metrics shared by the timing builder and the SwiftUI teleprompter view.
/// Keeping them in one place means the measured line breaks match what is drawn.
public enum PromptMetrics {
    /// Inset from the liquid-glass card edge to the text.
    public static let textInset: CGFloat = 34
    public static let cardTopPadding: CGFloat = 18
    public static let cardBottomPadding: CGFloat = 14
    public static let contentToProgressGap: CGFloat = 14
    public static let progressAreaHeight: CGFloat = 32
    /// The notch stage is now edge-to-edge glass with no shadow halo.
    public static let windowShadowMargin: CGFloat = 0

    public static func wordSpacing(fontSize: CGFloat) -> CGFloat {
        max(3, (fontSize * 0.23).rounded())
    }

    public static func lineHeight(fontSize: CGFloat) -> CGFloat {
        (fontSize * 1.24).rounded()
    }

    public static func lineGap(fontSize: CGFloat) -> CGFloat {
        max(5, (fontSize * 0.26).rounded())
    }

    public static func viewportHeight(fontSize: CGFloat) -> CGFloat {
        lineHeight(fontSize: fontSize) * 3 + lineGap(fontSize: fontSize) * 2
    }

    public static func cardHeight(fontSize: CGFloat) -> CGFloat {
        cardTopPadding
            + viewportHeight(fontSize: fontSize)
            + contentToProgressGap
            + progressAreaHeight
            + cardBottomPadding
    }

    public static func availableTextWidth(cardWidth: CGFloat) -> CGFloat {
        max(240, cardWidth - textInset * 2)
    }
}
