import AppKit
import SwiftUI

// MARK: - Palette

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

enum NookPalette {
    static let canvas = Color(hex: 0x08090C)
    static let canvasLift = Color(hex: 0x0C1017)
    static let text = Color(hex: 0xF4F1E9)
    static let secondaryText = Color.white.opacity(0.56)
    static let tertiaryText = Color.white.opacity(0.32)
    static let faintText = Color.white.opacity(0.18)
    static let warm = Color(hex: 0xE9D2A7)
    static let warmBright = Color(hex: 0xFFF0D2)
    static let cool = Color(hex: 0xA5C6E8)
    static let divider = Color.white.opacity(0.075)
    static let cardFill = Color.white.opacity(0.038)
    static let danger = Color(hex: 0xE89A8B)
    static let ink = Color(hex: 0x15120D)
}

// MARK: - Time formatting

enum NookTime {
    static func clock(_ seconds: TimeInterval, rounding: FloatingPointRoundingRule = .down) -> String {
        let value = max(0, seconds.rounded(rounding))
        let total = Int(value)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func remaining(_ seconds: TimeInterval) -> String {
        "−" + clock(seconds, rounding: .up)
    }

    static func total(_ seconds: TimeInterval) -> String {
        clock(seconds, rounding: .up)
    }
}

// MARK: - Backdrop blur

struct NookVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = cornerRadius > 0
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = cornerRadius > 0
    }
}

// MARK: - Brand mark

struct NookLogo: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x2C333F), Color(hex: 0x0C0E12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.30), .white.opacity(0.04), NookPalette.warm.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.45), radius: size * 0.2, y: size * 0.09)

            Capsule(style: .continuous)
                .fill(Color(hex: 0x040507))
                .frame(width: size * 0.46, height: size * 0.155)
                .offset(y: -size * 0.265)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [NookPalette.warmBright, NookPalette.cool],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.34, height: max(1.5, size * 0.05))
                .offset(y: size * 0.16)
                .shadow(color: NookPalette.warm.opacity(0.35), radius: 4)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}


// MARK: - Frost / grain

enum NookTexture {
    /// A small deterministic frosted-glass grain. Static so it never flickers
    /// and costs one tiny tile per frame.
    static let grain: NSImage = {
        let pixelWidth = 160
        let pixelHeight = 160
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelWidth * 4,
            bitsPerPixel: 32
        ) else {
            return NSImage(size: NSSize(width: 1, height: 1))
        }

        var state: UInt64 = 0x9E3779B97F4A7C15
        for y in 0..<pixelHeight {
            for x in 0..<pixelWidth {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let unit = Double((state >> 33) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
                let white = 0.58 + unit * 0.42
                let alpha = 0.04 + unit * 0.22
                bitmap.setColor(
                    NSColor(deviceWhite: CGFloat(white), alpha: CGFloat(alpha)),
                    atX: x,
                    y: y
                )
            }
        }

        let image = NSImage(size: NSSize(width: pixelWidth / 2, height: pixelHeight / 2))
        image.addRepresentation(bitmap)
        return image
    }()
}

struct NookGrainOverlay: View {
    var opacity: Double = 0.16

    var body: some View {
        Image(nsImage: NookTexture.grain)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.softLight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Editor surfaces

struct NookEditorBackground: View {
    var body: some View {
        ZStack {
            NookPalette.canvas

            LinearGradient(
                colors: [Color(hex: 0x0B1119), NookPalette.canvas],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [NookPalette.cool.opacity(0.16), .clear],
                center: UnitPoint(x: 0.10, y: 0.02),
                startRadius: 0,
                endRadius: 720
            )

            RadialGradient(
                colors: [NookPalette.warm.opacity(0.09), .clear],
                center: UnitPoint(x: 0.92, y: 0.96),
                startRadius: 20,
                endRadius: 640
            )

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.34)],
                center: .center,
                startRadius: 260,
                endRadius: 980
            )

            NookGrainOverlay(opacity: 0.11)
        }
        .ignoresSafeArea()
    }
}

struct NookCardBackground: View {
    var cornerRadius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(0.052), .white.opacity(0.021)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            shape.fill(
                LinearGradient(
                    colors: [NookPalette.cool.opacity(0.035), .clear, NookPalette.warm.opacity(0.022)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            shape.stroke(
                LinearGradient(
                    colors: [.white.opacity(0.14), .white.opacity(0.045), NookPalette.warm.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.3), radius: 24, y: 14)
    }
}

// MARK: - Controls

struct NookPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(NookPalette.ink)
            .padding(.horizontal, 17)
            .frame(height: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [NookPalette.warmBright, Color(hex: 0xE3C794)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.62), lineWidth: 0.6)
            )
            .shadow(
                color: NookPalette.warm.opacity(configuration.isPressed ? 0.10 : 0.20),
                radius: 18,
                y: 7
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.34)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct NookSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(NookPalette.text.opacity(0.82))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.09 : 0.045))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.075), lineWidth: 0.7)
            )
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct NookKeycap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(NookPalette.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.white.opacity(0.085), lineWidth: 0.6)
            )
            .fixedSize()
    }
}

struct NookSectionLabel: View {
    let title: String
    var accessory: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(NookPalette.secondaryText)
            if let accessory {
                Text(accessory)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(NookPalette.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .textCase(.uppercase)
    }
}

struct NookStatusPill: View {
    var dotColor: Color = NookPalette.cool
    var text: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .shadow(color: dotColor.opacity(0.7), radius: 4)
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NookPalette.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.035))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 0.6)
        )
    }
}

// MARK: - Small helpers

extension View {
    /// A very light paper-like noise/grid is intentionally avoided here; the
    /// editor relies on depth from light, not decoration.
    func nookCursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
