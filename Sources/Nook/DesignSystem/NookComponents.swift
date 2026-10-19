import SwiftUI

/// A one-pixel hairline. Use it for separators and panel edges.
struct NookHairline: View {
    var color: Color = NookColor.border

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 0.5)
    }
}

struct NookSectionLabel: View {
    let title: String
    var accessory: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(NookType.caption)
                .fontWeight(.semibold)
                .foregroundStyle(NookColor.textPrimary)
            if let accessory {
                Text(accessory)
                    .font(NookType.micro)
                    .foregroundStyle(NookColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A rounded white card on the light canvas. The shadow is deliberately faint:
/// the paper should look like it rests on the desk, not float above it.
struct NookCard<Content: View>: View {
    var padding: CGFloat = NookSpace.lg
    var radius: CGFloat = NookRadius.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(NookColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

struct NookChip: View {
    let text: String
    var color: Color = NookColor.textTertiary
    var showsDot = true
    var isBusy = false

    var body: some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.68)
                    .tint(color)
            } else if showsDot {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(NookType.micro)
                .fontWeight(.medium)
                .foregroundStyle(NookColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(color.opacity(0.16), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }
}

struct NookSourceBadge: View {
    let source: PhrasePlanSource

    private var label: String { source == .ai ? "AI plan" : "Local" }
    private var color: Color { source == .ai ? NookColor.success : NookColor.textTertiary }

    var body: some View {
        NookChip(text: label, color: color)
    }
}

struct NookKeycap: View {
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
                    .fill(NookColor.surfaceMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.5)
            )
            .fixedSize()
    }
}

/// Primary action: one accent capsule. Press feedback is a 1.5 percent scale
/// and a small brightness drop, both on the system snappy spring.
struct NookPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? NookColor.accentPressed : NookColor.accentButton)
            )
            .brightness(configuration.isPressed ? -0.03 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(NookMotion.press, value: configuration.isPressed)
    }
}

struct NookSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(NookColor.textPrimary.opacity(0.82))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .fill(configuration.isPressed ? NookColor.surfaceMuted : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.control, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(NookMotion.press, value: configuration.isPressed)
    }
}

struct NookIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NookColor.textSecondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? NookColor.surfaceMuted : Color.clear)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.5)
            .animation(NookMotion.press, value: configuration.isPressed)
    }
}

/// A quiet link-style button used inside empty states and banners.
struct NookLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(NookColor.accent)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
