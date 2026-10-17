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

                settingsField(
                    title: "Base URL",
                    placeholder: "https://api.openai.com/v1",
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
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(NookColor.textPrimary)
                .padding(.horizontal, 10)
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
                    Text("KEY SAVED IN KEYCHAIN")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(NookColor.success.opacity(0.8))
                }
            }

            SecureField("Paste a key to add or replace", text: $model.aiKeyDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(NookColor.textPrimary)
                .padding(.horizontal, 10)
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

    private var connectionStatus: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(connectionColor)
                .frame(width: 5, height: 5)
            Text(connectionText)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(NookColor.textSecondary)
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
            return model.hasAPIKey ? "Key saved in Keychain." : "Not configured."
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
            return model.hasAPIKey ? NookColor.success : NookColor.textTertiary
        case .testing:
            return NookColor.warning
        case .success:
            return NookColor.success
        case .failure:
            return NookColor.danger
        }
    }
}
