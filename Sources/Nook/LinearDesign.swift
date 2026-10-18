import SwiftUI

extension Color {
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

enum NookColor {
    // Apple's light system palette: white paper, graphite labels, one blue
    // accent. No purple tint anywhere in the editor.
    static let canvas = Color.nookHex(0xFFFFFF)
    static let pane = Color.nookHex(0xF5F5F7)
    static let raised = Color.nookHex(0xFFFFFF)
    static let raisedHover = Color.nookHex(0xECECF0)
    static let border = Color.nookHex(0xE5E5EA)
    static let borderStrong = Color.nookHex(0xD1D1D6)
    static let textPrimary = Color.nookHex(0x1D1D1F)
    static let textSecondary = Color.nookHex(0x515154)
    static let textTertiary = Color.nookHex(0x5F5F64)
    static let accent = Color.nookHex(0x007AFF)
    static let accentButton = Color.nookHex(0x0071E3)
    static let accentSoft = Color.nookHex(0x007AFF, opacity: 0.10)
    static let success = Color.nookHex(0x1F7A34)
    static let warning = Color.nookHex(0xB25000)
    static let danger = Color.nookHex(0xD70015)
    static let ink = Color.nookHex(0xFFFFFF)
}

enum NookRadius {
    static let control: CGFloat = 8
    static let input: CGFloat = 9
    static let surface: CGFloat = 10
    static let overlay: CGFloat = 12
}

enum NookSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

struct LinearHairline: View {
    var color: Color = NookColor.border
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

struct LinearSectionLabel: View {
    let title: String
    var accessory: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(NookColor.textPrimary)
            if let accessory {
                Text(accessory)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(NookColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct LinearSourceBadge: View {
    let source: PhrasePlanSource

    private var label: String {
        source == .ai ? "AI plan" : "Local"
    }

    private var color: Color {
        source == .ai ? NookColor.success : NookColor.textTertiary
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(color.opacity(0.16), lineWidth: 0.7)
        )
    }
}

struct LinearKeycap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(NookColor.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(NookColor.pane)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.7)
            )
            .fixedSize()
    }
}

struct LinearCanvasBackground: View {
    var body: some View {
        NookColor.canvas
            .ignoresSafeArea()
    }
}

/// One shared light chrome for the toolbar and the inspector. The white tint
/// keeps both materials on the same lightness instead of letting the default
/// materials turn into two different gray bands.
struct AppleChromeBackground: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(NookColor.canvas.opacity(0.18))
    }
}

struct LinearPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .fill(NookColor.accentButton)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.28 : 0.16), lineWidth: 0.7)
            )
            .brightness(configuration.isPressed ? -0.08 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct LinearIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NookColor.textSecondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? NookColor.raisedHover : Color.clear)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.5)
    }
}

struct LinearSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(NookColor.textPrimary.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .fill(configuration.isPressed ? NookColor.raisedHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.8)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
