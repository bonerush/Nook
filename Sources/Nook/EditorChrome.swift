import SwiftUI

struct EditorActions {
    let start: () -> Void
}

struct EditorTopBar: View {
    @ObservedObject var model: AppModel
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NotchGlyph()

            HStack(spacing: 7) {
                Text("Nook")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(NookColor.textPrimary)
                Text("/")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(NookColor.textTertiary.opacity(0.8))
                Text("Interview script")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(NookColor.textSecondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                LinearSourceBadge(source: model.planSource)

                Button("AI settings") {}
                    .buttonStyle(LinearSecondaryButtonStyle())
                    .disabled(true)
                    .help("AI settings arrive in the next task")

                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Text("Start")
                        Text("⌘↩")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .fixedSize()
                    .padding(.trailing, 1)
                }
                .buttonStyle(LinearPrimaryButtonStyle())
                .disabled(!model.hasContent)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Start the teleprompter (⌘↩)")
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(
            LinearGradient(
                colors: [NookColor.canvas.opacity(0.96), NookColor.canvas.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct EditorStatusBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.planSource == .ai ? NookColor.success : NookColor.textTertiary)
                    .frame(width: 4, height: 4)
                Text(model.planSource == .ai ? "AI PLAN" : "LOCAL")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(NookColor.textSecondary)
            }

            Text(model.speedLabel)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(NookColor.textTertiary)

            Text("≈ \(model.estimatedDurationLabel)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(NookColor.textTertiary)

            Spacer(minLength: 0)

            Text("SAVED")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(NookColor.textTertiary)

            LinearKeycap("⌃⌥Space")
        }
        .padding(.horizontal, 24)
        .frame(height: 30)
        .background(NookColor.canvas.opacity(0.92))
    }
}
