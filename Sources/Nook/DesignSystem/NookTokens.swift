import SwiftUI

extension Color {
    /// Build a color from a 24-bit sRGB literal. The app uses a small, fixed
    /// palette so the design tokens stay readable in code review.
    static func nookHex(_ hex: UInt32, opacity: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

/// Apple light palette. One accent color, graphite text, white paper.
/// There is no second hue anywhere in the editor.
enum NookColor {
    // Canvas and surfaces
    static let canvas = Color.nookHex(0xFFFFFF)
    static let canvasTop = Color.nookHex(0xF5F5F7)
    static let canvasBottom = Color.nookHex(0xFAFAFC)
    static let paper = Color.nookHex(0xFFFFFF)
    static let pane = Color.nookHex(0xF5F5F7)
    static let surface = Color.nookHex(0xFFFFFF)
    static let surfaceMuted = Color.nookHex(0xF2F2F4)
    static let raised = Color.nookHex(0xFFFFFF)
    static let raisedHover = Color.nookHex(0xECECF0)

    // Lines
    static let border = Color.nookHex(0xE5E5EA)
    static let borderStrong = Color.nookHex(0xD1D1D6)

    // Text
    static let textPrimary = Color.nookHex(0x1D1D1F)
    static let textSecondary = Color.nookHex(0x515154)
    static let textTertiary = Color.nookHex(0x6E6E73)

    // One accent
    static let accent = Color.nookHex(0x007AFF)
    static let accentButton = Color.nookHex(0x0071E3)
    static let accentPressed = Color.nookHex(0x0063D1)
    static let accentSoft = Color.nookHex(0x007AFF, opacity: 0.10)

    // Status
    static let success = Color.nookHex(0x1F7A34)
    static let warning = Color.nookHex(0xB25000)
    static let danger = Color.nookHex(0xD70015)

    static let ink = Color.nookHex(0xFFFFFF)
}

/// Type scale. The app targets macOS 14, which has no Dynamic Type; sizes come
/// from the system text styles where the platform offers them and from this
/// fixed scale where a document layout needs exact metrics.
enum NookType {
    static let display = Font.system(size: 28, weight: .semibold)
    static let title = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 11, weight: .medium)
    static let micro = Font.system(size: 10, weight: .regular)

    static func mono(_ size: CGFloat = 10.5, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Spacing scale. Every gap in the editor comes from these five values.
enum NookSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum NookRadius {
    static let control: CGFloat = 8
    static let input: CGFloat = 9
    static let surface: CGFloat = 12
    static let overlay: CGFloat = 14
    static let paper: CGFloat = 20
    static let capsule: CGFloat = 999
}

/// Window and layout constants. These values are also the acceptance criteria
/// for the screenshots in docs/05-design-system.md.
enum NookMetrics {
    static let toolbarHeight: CGFloat = 48
    static let statusBarHeight: CGFloat = 28
    static let inspectorWidth: CGFloat = 300
    static let paperMaxWidth: CGFloat = 720
    static let windowMin = CGSize(width: 960, height: 680)
    static let windowDefault = CGSize(width: 1080, height: 740)
}
