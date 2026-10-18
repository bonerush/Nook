import AppKit
import SwiftUI

struct AISettingsOverlay: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 16) {
                header
                providerPresets
                reasoningSection

                settingsField(
                    title: "Base URL",
                    placeholder: "https://your-endpoint/v1",
                    text: $model.aiBaseURLDraft
                )

                settingsField(
                    title: "Model",
                    placeholder: "your model id",
                    text: $model.aiModelDraft
                )

                keyField
                connectionStatus

                Text("At Start, your script is sent to this endpoint for phrasing. Nothing else leaves this Mac.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(NookColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                if let error = model.aiSettingsError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(NookColor.danger)
                }

                HStack(spacing: 8) {
                    Button("Clear key") {
                        model.clearAPIKey()
                    }
                    .buttonStyle(LinearSecondaryButtonStyle())
                    .disabled(!model.hasAPIKey)

                    Spacer(minLength: 8)

                    Button("Test connection") {
                        model.testConnection()
                    }
                    .buttonStyle(LinearSecondaryButtonStyle())
                    .disabled(model.connectionTestState == .testing)

                    Button("Cancel", action: onClose)
                        .buttonStyle(LinearSecondaryButtonStyle())

                    Button("Save") {
                        model.saveAISettings()
                    }
                    .buttonStyle(LinearPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 560)
            .background(NookColor.raised)
            .clipShape(RoundedRectangle(cornerRadius: NookRadius.overlay, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.overlay, style: .continuous)
                    .stroke(NookColor.borderStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 18)
            .overlay(alignment: .topLeading) {
                FirstSettingsFieldFocusBridge()
                    .frame(width: 0, height: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("AI phrasing")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NookColor.textPrimary)
            Text("OPENAI-COMPATIBLE")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(NookColor.textTertiary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(LinearIconButtonStyle())
            .help("Close AI settings")
        }
    }

    private var providerPresets: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Provider")
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(NookColor.textTertiary)

            HStack(spacing: 6) {
                ForEach(LLMProviderPreset.allCases, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private var supportsReasoningDraft: Bool {
        if model.aiPresetDraft == .deepSeek { return true }
        guard let host = URL(string: model.aiBaseURLDraft)?.host?.lowercased() else {
            return false
        }
        return host.contains("deepseek.com")
    }

    @ViewBuilder
    private var reasoningSection: some View {
        if supportsReasoningDraft {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    LinearSectionLabel(title: "Reasoning", accessory: "THINKING MODE")
                    Spacer(minLength: 8)
                    Toggle("", isOn: $model.aiReasoningEnabledDraft)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(NookColor.accent)
                        .controlSize(.mini)
                        .accessibilityLabel("Thinking mode")
                }

                if model.aiReasoningEnabledDraft {
                    HStack(spacing: 6) {
                        ForEach(LLMReasoningEffort.allCases, id: \.self) { effort in
                            reasoningEffortButton(effort)
                        }
                    }
                    Text("The model thinks first; the final answer is still strict JSON.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(NookColor.textTertiary)
                } else {
                    Text("Thinking is disabled. The final answer is still strict JSON.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(NookColor.textTertiary)
                }
            }
        }
    }

    private func reasoningEffortButton(_ effort: LLMReasoningEffort) -> some View {
        let selected = model.aiReasoningEffortDraft == effort
        return Button {
            model.aiReasoningEffortDraft = effort
        } label: {
            Text(effort.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selected ? NookColor.textPrimary : NookColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? NookColor.accentSoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            selected ? NookColor.accent.opacity(0.48) : NookColor.border,
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!model.aiReasoningEnabledDraft)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func presetButton(_ preset: LLMProviderPreset) -> some View {
        let selected = model.aiPresetDraft == preset
        return Button {
            model.aiPresetDraft = preset
            if !preset.defaultBaseURL.isEmpty {
                model.aiBaseURLDraft = preset.defaultBaseURL
            }
        } label: {
            Text(preset.displayName)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(selected ? NookColor.textPrimary : NookColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? NookColor.accentSoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            selected ? NookColor.accent.opacity(0.48) : NookColor.border,
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func settingsField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(NookColor.textTertiary)
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(NookColor.textTertiary)
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)
                }
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(NookColor.textPrimary)
                    .padding(.horizontal, 10)
                    .accessibilityLabel(title)
            }
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.input, style: .continuous)
                    .fill(NookColor.pane)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NookRadius.input, style: .continuous)
                    .stroke(NookColor.border, lineWidth: 0.8)
            )
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("API key")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(NookColor.textTertiary)
                Spacer()
                if model.hasAPIKey {
                    HStack(spacing: 6) {
                        Text("KEY SAVED IN KEYCHAIN")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(NookColor.success.opacity(0.9))
                        if let suffix = model.apiKeySuffix {
                            Text("•••• \(suffix)")
                                .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                                .foregroundStyle(NookColor.textTertiary)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    if model.aiKeyDraft.isEmpty {
                        Text("Paste a key to add or replace")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(NookColor.textTertiary)
                            .padding(.horizontal, 10)
                            .allowsHitTesting(false)
                    }

                    Group {
                        if model.isAPIKeyVisible {
                            TextField("", text: $model.aiKeyDraft)
                        } else {
                            SecureField("", text: $model.aiKeyDraft)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(NookColor.textPrimary)
                    .padding(.horizontal, 10)
                    .accessibilityLabel("API key")
                }
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: NookRadius.input, style: .continuous)
                        .fill(NookColor.pane)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadius.input, style: .continuous)
                        .stroke(NookColor.border, lineWidth: 0.8)
                )

                Button {
                    model.isAPIKeyVisible.toggle()
                } label: {
                    Image(systemName: model.isAPIKeyVisible ? "eye.slash" : "eye")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NookColor.textSecondary)
                        .frame(width: 26, height: 36)
                }
                .buttonStyle(.plain)
                .help(model.isAPIKeyVisible ? "Hide API key" : "Reveal API key while editing")
                .accessibilityLabel(model.isAPIKeyVisible ? "Hide API key" : "Reveal API key")
            }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(connectionColor)
                .frame(width: 5, height: 5)
            Text(connectionText)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(connectionTextColor)
            Spacer()
            if model.llmConfiguration.isLocalEndpoint {
                Text("LOCAL ENDPOINT · KEY OPTIONAL")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(NookColor.textTertiary)
            }
        }
        .frame(height: 18)
    }

    private var connectionText: String {
        switch model.connectionTestState {
        case .idle:
            if !model.aiKeyDraft.isEmpty {
                return "Key entered. Save to store it in Keychain."
            }
            if model.llmConfiguration.isLocalEndpoint, model.llmConfiguration.isComplete {
                return "Local endpoint ready. Key optional."
            }
            if model.hasAPIKey, let suffix = model.apiKeySuffix {
                return "Key saved in Keychain (•••• \(suffix))."
            }
            return model.hasAPIKey ? "Key saved in Keychain." : "Add an API key to enable AI."
        case .testing:
            return "Testing…"
        case .success:
            return "Connected."
        case .failure(let message):
            return message
        }
    }

    private var connectionColor: Color {
        switch model.connectionTestState {
        case .idle:
            if !model.aiKeyDraft.isEmpty {
                return NookColor.warning
            }
            if model.hasAPIKey {
                return NookColor.success
            }
            if model.llmConfiguration.isLocalEndpoint, model.llmConfiguration.isComplete {
                return NookColor.success
            }
            return NookColor.textTertiary
        case .testing:
            return NookColor.warning
        case .success:
            return NookColor.success
        case .failure:
            return NookColor.danger
        }
    }

    private var connectionTextColor: Color {
        if case .failure(_) = model.connectionTestState {
            return NookColor.danger
        }
        return NookColor.textSecondary
    }
}

private struct FirstSettingsFieldFocusBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            focusField(from: view, attempt: 0)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func focusField(from view: NSView, attempt: Int) {
        guard attempt < 8 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard let window = view.window else {
                focusField(from: view, attempt: attempt + 1)
                return
            }
            if let field = window.contentView?.firstEditableSettingsTextField {
                window.makeFirstResponder(field)
            } else {
                focusField(from: view, attempt: attempt + 1)
            }
        }
    }
}

private extension NSView {
    var firstEditableSettingsTextField: NSTextField? {
        if let field = self as? NSTextField,
           field.isEditable,
           field.isSelectable,
           !field.isHidden {
            return field
        }
        for subview in subviews {
            if let found = subview.firstEditableSettingsTextField {
                return found
            }
        }
        return nil
    }
}
