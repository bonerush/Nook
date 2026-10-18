import SwiftUI

struct EditorActions {
    let start: () -> Void
    let startLocal: () -> Void
    let retryAI: () -> Void
    let openAISettings: () -> Void
}

struct AIStatusView: View {
    @ObservedObject var model: AppModel

    private var status: (label: String, color: Color, planning: Bool) {
        switch model.planningState {
        case .planning:
            return ("AI planning", NookColor.warning, true)
        case .failed(_):
            return ("AI error", NookColor.danger, false)
        case .idle:
            break
        }
        if model.canUseAI {
            return ("AI ready", NookColor.success, false)
        }
        return ("AI not configured", NookColor.textTertiary, false)
    }

    var body: some View {
        HStack(spacing: 6) {
            if status.planning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.72)
                    .tint(status.color)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            }
            Text(status.label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(status.color.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(status.color.opacity(0.15), lineWidth: 0.7)
        )
        .help(status.planning ? "AI is planning phrase breaks" : "AI phrasing status")
    }
}

struct EditorTopBar: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    private var isPlanning: Bool {
        if case .planning = model.planningState { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Script")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NookColor.textPrimary)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                AIStatusView(model: model)

                Button {
                    actions.openAISettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(LinearIconButtonStyle())
                .help("AI settings")
                .accessibilityLabel("AI settings")

                Button {
                    if isPlanning {
                        model.cancelPlanning()
                    } else {
                        actions.start()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isPlanning {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.7)
                                .tint(.white)
                            Text("AI phrasing…")
                        } else {
                            Text("Start")
                        }
                    }
                    .fixedSize()
                    .padding(.trailing, 1)
                }
                .buttonStyle(LinearPrimaryButtonStyle())
                .disabled(!model.hasContent && !isPlanning)
                .help(isPlanning ? "Cancel AI planning (Esc)" : "Start the teleprompter (⌘↩)")
            }
        }
        .padding(.leading, 80)
        .padding(.trailing, 24)
        .frame(height: 52)
        .background(AppleChromeBackground())
    }
}

struct PlanningErrorBanner: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    private var message: String {
        guard case .failed(let failure) = model.planningState else { return "" }
        switch failure {
        case .disabled:
            return "AI is not configured. Local phrasing is ready."
        case .unauthorized:
            return "API key rejected. Check AI settings."
        case .rateLimited:
            return "Rate limited. Try again shortly."
        case .timeout:
            return "AI request timed out. Try again."
        case .network:
            return "AI unavailable. Check your connection."
        case .truncated:
            return "AI response was truncated. Try a shorter script."
        case .server(let code) where code == 400 || code == 404:
            return "Endpoint or model rejected (HTTP \(code))."
        case .server(let code):
            return "Provider error (HTTP \(code))."
        case .invalidResponse, .invalidPlan:
            return "AI returned an unusable plan."
        case .emptyScript:
            return "Add a script first."
        case .tooLong:
            return "Script is too long for AI phrasing."
        case .cancelled:
            return "AI planning was cancelled."
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NookColor.danger)

            Text(message)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(NookColor.textPrimary.opacity(0.82))
                .lineLimit(1)

            Spacer(minLength: 12)

            Button("Retry AI") {
                actions.retryAI()
            }
            .buttonStyle(LinearSecondaryButtonStyle())

            Button("Start locally") {
                actions.startLocal()
            }
            .buttonStyle(LinearSecondaryButtonStyle())

            Button("Settings") {
                actions.openAISettings()
            }
            .buttonStyle(LinearSecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .frame(height: 42)
        .background(NookColor.danger.opacity(0.06))
        .overlay(alignment: .top) { LinearHairline(color: NookColor.danger.opacity(0.16)) }
        .overlay(alignment: .bottom) { LinearHairline(color: NookColor.danger.opacity(0.16)) }
    }
}

struct EditorStatusBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            Text(model.speedLabel)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(NookColor.textTertiary)

            Text("≈ \(model.estimatedDurationLabel)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(NookColor.textTertiary)

            Spacer(minLength: 0)

            LinearKeycap("⌃⌥Space")
        }
        .padding(.horizontal, 24)
        .frame(height: 30)
        .background(NookColor.canvas.opacity(0.92))
    }
}
