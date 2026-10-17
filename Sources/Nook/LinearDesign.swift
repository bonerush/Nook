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
    static let canvas = Color.nookHex(0x08090B)
    static let pane = Color.nookHex(0x0C0D10)
    static let raised = Color.nookHex(0x141519)
    static let raisedHover = Color.nookHex(0x1A1C21)
    static let border = Color.nookHex(0x23252A)
    static let borderStrong = Color.nookHex(0x2E3138)
    static let textPrimary = Color.nookHex(0xF2F3F5)
    static let textSecondary = Color.nookHex(0x8C9099)
    static let textTertiary = Color.nookHex(0x80848E)
    static let accent = Color.nookHex(0x7C86FF)
    static let accentButton = Color.nookHex(0x5A63E6)
    static let accentSoft = Color.nookHex(0x7C86FF, opacity: 0.14)
    static let success = Color.nookHex(0x69D6A3)
    static let warning = Color.nookHex(0xE7B365)
    static let danger = Color.nookHex(0xFF7A86)
    static let ink = Color.nookHex(0x0D0E11)
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
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(NookColor.textSecondary)
            if let accessory {
                Text(accessory)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(NookColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .textCase(.uppercase)
    }
}

struct LinearSourceBadge: View {
    let source: PhrasePlanSource

    private var label: String {
        source == .ai ? "AI PLAN" : "LOCAL"
    }

    private var color: Color {
        source == .ai ? NookColor.success : NookColor.textTertiary
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.7)
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
                    .fill(NookColor.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.7)
            )
            .fixedSize()
    }
}

struct NotchGlyph: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(NookColor.textPrimary.opacity(0.92))
                .frame(width: 18, height: 10)
            Capsule(style: .continuous)
                .fill(NookColor.canvas)
                .frame(width: 9, height: 4)
                .offset(y: 1)
        }
        .frame(width: 18, height: 12)
        .accessibilityHidden(true)
    }
}

struct LinearCanvasBackground: View {
    var body: some View {
        ZStack {
            NookColor.canvas
            RadialGradient(
                colors: [NookColor.accent.opacity(0.055), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 520
            )
            Canvas { context, size in
                let step: CGFloat = 24
                var path = Path()
                var x: CGFloat = 0
                while x < size.width {
                    var y: CGFloat = 0
                    while y < size.height {
                        path.addEllipse(in: CGRect(x: x, y: y, width: 0.8, height: 0.8))
                        y += step
                    }
                    x += step
                }
                context.fill(path, with: .color(.white.opacity(0.025)))
            }
        }
        .ignoresSafeArea()
    }
}

struct LinearPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .fill(NookColor.accentButton)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.28 : 0.16), lineWidth: 0.7)
            )
            .brightness(configuration.isPressed ? -0.08 : 0)
            .opacity(isEnabled ? 1 : 0.34)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct LinearIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NookColor.textSecondary)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? NookColor.raisedHover : NookColor.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.8)
            )
            .opacity(isEnabled ? 1 : 0.34)
    }
}

struct LinearSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(NookColor.textPrimary.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .fill(configuration.isPressed ? NookColor.raisedHover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.8)
            )
            .opacity(isEnabled ? 1 : 0.34)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
