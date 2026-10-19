import SwiftUI

struct EditorToolbar: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    private var isPlanning: Bool {
        if case .planning = model.planningState { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            brand
            Spacer(minLength: 12)
            AIStatusChip(model: model)

            Button {
                model.toggleInspector()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(model.isInspectorVisible ? NookColor.accent : NookColor.textSecondary)
            }
            .buttonStyle(NookIconButtonStyle())
            .help(model.isInspectorVisible ? "Hide inspector (⌥⌘I)" : "Show inspector (⌥⌘I)")
            .accessibilityLabel(model.isInspectorVisible ? "Hide inspector" : "Show inspector")

            Button {
                actions.openAISettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(NookIconButtonStyle())
            .help("AI settings (⌘,)")
            .accessibilityLabel("AI settings")

            startButton
        }
        .padding(.leading, 78)
        .padding(.trailing, 20)
        .frame(height: NookMetrics.toolbarHeight)
        .background(NookChromeBackground())
        .overlay(alignment: .bottom) { NookHairline() }
    }

    private var brand: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(NookColor.accentSoft)
                    .frame(width: 26, height: 26)
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NookColor.accent)
            }

            Text("Nook")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NookColor.textPrimary)

            Rectangle()
                .fill(NookColor.borderStrong)
                .frame(width: 0.5, height: 12)

            Text("Teleprompter")
                .font(NookType.caption)
                .foregroundStyle(NookColor.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var startButton: some View {
        Button {
            if isPlanning {
                model.cancelPlanning()
            } else {
                actions.start()
            }
        } label: {
            HStack(spacing: 7) {
                if isPlanning {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.66)
                        .tint(.white)
                    Text("Phrasing…")
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("Start")
                }
            }
            .frame(minWidth: 74)
            .contentTransition(.opacity)
        }
        .buttonStyle(NookPrimaryButtonStyle())
        .disabled(!model.hasContent && !isPlanning)
        .help(isPlanning ? "Cancel AI planning (Esc)" : "Start the teleprompter (⌘↩)")
        .accessibilityLabel(isPlanning ? "Cancel AI phrasing" : "Start teleprompter")
    }
}

struct AIStatusChip: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var status: (label: String, color: Color, busy: Bool) {
        switch model.planningState {
        case .planning:
            return ("Phrasing…", NookColor.warning, true)
        case .failed:
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
        let status = status
        HStack(spacing: 6) {
            if status.busy {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.64)
                    .tint(status.color)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            }
            Text(status.label)
                .font(NookType.micro)
                .fontWeight(.medium)
                .foregroundStyle(NookColor.textSecondary)
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Capsule(style: .continuous).fill(status.color.opacity(0.08)))
        .overlay(Capsule(style: .continuous).stroke(status.color.opacity(0.16), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI status: \(status.label)")
    }

}
