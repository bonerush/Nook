import AppKit
import SwiftUI

/// Settings for the OpenAI-compatible phrasing endpoint. It is a focused
/// sheet, not a page: one endpoint, one key, one reasoning switch.
struct AISettingsOverlay: View {
    @ObservedObject var settings: AISettingsModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            card
        }
        .onExitCommand(perform: onClose)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            NookHairline()
            VStack(alignment: .leading, spacing: 18) {
                providerSection
                endpointSection
                keySection
                reasoningSection
                connectionStatus
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)

            footer
        }
        .frame(width: 580)
        .background(
            RoundedRectangle(cornerRadius: NookRadius.overlay, style: .continuous)
                .fill(NookColor.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NookRadius.overlay, style: .continuous)
                .stroke(NookColor.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: 32, x: 0, y: 16)
        .overlay(alignment: .topLeading) {
            FirstSettingsFieldFocusBridge()
                .frame(width: 0, height: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(NookColor.accentSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NookColor.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AI phrasing")
                    .font(NookType.title)
                    .foregroundStyle(NookColor.textPrimary)
                Text("OpenAI-compatible endpoint")
                    .font(NookType.caption)
                    .foregroundStyle(NookColor.textTertiary)
            }

            Spacer(minLength: 12)

            if settings.canUseAI {
                NookChip(text: "Ready", color: NookColor.success)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(NookIconButtonStyle())
            .help("Close AI settings")
            .accessibilityLabel("Close AI settings")
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NookSectionLabel(title: "Provider")
            HStack(spacing: 6) {
                ForEach(LLMProviderPreset.allCases, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: LLMProviderPreset) -> some View {
        let selected = settings.presetDraft == preset
        return Button {
            settings.presetDraft = preset
            if !preset.defaultBaseURL.isEmpty {
                settings.baseURLDraft = preset.defaultBaseURL
            }
        } label: {
            Text(preset.displayName)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(selected ? NookColor.textPrimary : NookColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? NookColor.accentSoft : NookColor.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            selected ? NookColor.accent.opacity(0.45) : Color.clear,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NookSectionLabel(title: "Endpoint", accessory: "HTTPS only")

            settingsField(
                title: "Base URL",
                placeholder: "https://your-endpoint/v1",
                text: $settings.baseURLDraft
            )

            settingsField(
                title: "Model",
                placeholder: "your model id",
                text: $settings.modelDraft
            )
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                NookSectionLabel(title: "API key", accessory: "Keychain only")
                Spacer(minLength: 8)
                if settings.hasAPIKey {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(NookColor.success)
                        Text(settings.keySuffix.map { "•••• \($0)" } ?? "Saved")
                            .font(NookType.mono(9, weight: .regular))
                            .foregroundStyle(NookColor.textTertiary)
                    }
                }
            }

            HStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    if settings.keyDraft.isEmpty {
                        Text("Paste a key to add or replace")
                            .font(NookType.mono(11.5, weight: .regular))
                            .foregroundStyle(NookColor.textTertiary)
                            .padding(.horizontal, 10)
                            .allowsHitTesting(false)
                    }

                    Group {
                        if settings.isKeyVisible {
                            TextField("", text: $settings.keyDraft)
                        } else {
                            SecureField("", text: $settings.keyDraft)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(NookType.mono(11.5, weight: .regular))
                    .foregroundStyle(NookColor.textPrimary)
                    .padding(.horizontal, 10)
                    .accessibilityLabel("API key")
                }
                .frame(height: 36)
                .background(fieldBackground)
                .overlay(fieldBorder)

                Button {
                    settings.isKeyVisible.toggle()
                } label: {
                    Image(systemName: settings.isKeyVisible ? "eye.slash" : "eye")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NookColor.textSecondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
                .help(settings.isKeyVisible ? "Hide API key" : "Reveal API key")
                .accessibilityLabel(settings.isKeyVisible ? "Hide API key" : "Reveal API key")
            }

            Text("Stored in Keychain. Read only to sign requests to this endpoint.")
                .font(NookType.micro)
                .foregroundStyle(NookColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var supportsReasoningDraft: Bool {
        if settings.presetDraft == .deepSeek { return true }
        guard let host = URL(string: settings.baseURLDraft)?.host?.lowercased() else {
            return false
        }
        return host.contains("deepseek.com")
    }

    @ViewBuilder
    private var reasoningSection: some View {
        if supportsReasoningDraft {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    NookSectionLabel(title: "Reasoning", accessory: "Thinking mode")
                    Spacer(minLength: 8)
                    Toggle("", isOn: $settings.reasoningEnabledDraft)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(NookColor.accent)
                        .controlSize(.small)
                        .accessibilityLabel("Thinking mode")
                }

                if settings.reasoningEnabledDraft {
                    HStack(spacing: 6) {
                        ForEach(LLMReasoningEffort.allCases, id: \.self) { effort in
                            reasoningEffortButton(effort)
                        }
                    }
                }

                Text(
                    settings.reasoningEnabledDraft
                        ? "The model thinks first. The final answer is still strict JSON."
                        : "Thinking is disabled. The final answer is still strict JSON."
                )
                .font(NookType.micro)
                .foregroundStyle(NookColor.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: NookRadius.surface, style: .continuous)
                    .fill(NookColor.surfaceMuted.opacity(0.55))
            )
        }
    }

    private func reasoningEffortButton(_ effort: LLMReasoningEffort) -> some View {
        let selected = settings.reasoningEffortDraft == effort
        return Button {
            settings.reasoningEffortDraft = effort
        } label: {
            Text(effort.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selected ? NookColor.textPrimary : NookColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? NookColor.paper : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(selected ? NookColor.border : Color.clear, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!settings.reasoningEnabledDraft)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var connectionStatus: some View {
        HStack(spacing: 7) {
            if settings.testState == .testing {
                NookPulseDot(color: NookColor.warning)
            } else {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 5, height: 5)
            }
            Text(connectionText)
                .font(NookType.micro)
                .foregroundStyle(connectionTextColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if settings.errorMessage != nil {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(NookColor.danger)
                    .accessibilityLabel("Settings error")
            }
        }
        .frame(minHeight: 18, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            NookHairline()
            HStack(spacing: 8) {
                Button("Clear key") {
                    settings.clearKey()
                }
                .buttonStyle(NookSecondaryButtonStyle())
                .disabled(!settings.hasAPIKey)

                Spacer(minLength: 8)

                Button("Test connection") {
                    settings.testConnection()
                }
                .buttonStyle(NookSecondaryButtonStyle())
                .disabled(settings.testState == .testing)

                Button("Cancel", action: onClose)
                    .buttonStyle(NookSecondaryButtonStyle())

                Button("Save") {
                    if settings.save() {
                        onClose()
                    }
                }
                .buttonStyle(NookPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .frame(height: 60)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: NookRadius.input, style: .continuous)
            .fill(NookColor.surfaceMuted.opacity(0.7))
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: NookRadius.input, style: .continuous)
            .stroke(NookColor.border, lineWidth: 0.5)
    }

    private func settingsField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NookType.caption)
                .foregroundStyle(NookColor.textSecondary)
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(NookType.mono(11.5, weight: .regular))
                        .foregroundStyle(NookColor.textTertiary)
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)
                }
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(NookType.mono(11.5, weight: .regular))
                    .foregroundStyle(NookColor.textPrimary)
                    .padding(.horizontal, 10)
                    .accessibilityLabel(title)
            }
            .frame(height: 36)
            .background(fieldBackground)
            .overlay(fieldBorder)
        }
    }

    private var connectionText: String {
        if let error = settings.errorMessage {
            return error
        }
        switch settings.testState {
        case .idle:
            if !settings.keyDraft.isEmpty {
                return "Key entered. Save to store it in Keychain."
            }
            if settings.configuration.isLocalEndpoint, settings.configuration.isComplete {
                return "Local endpoint ready. Key optional."
            }
            if settings.hasAPIKey {
                return "Key saved in Keychain. AI is ready at Start."
            }
            return "Add an API key to enable AI phrasing."
        case .testing:
            return "Testing…"
        case .success:
            return "Connected."
        case .failure(let message):
            return message
        }
    }

    private var connectionColor: Color {
        if settings.errorMessage != nil { return NookColor.danger }
        switch settings.testState {
        case .idle:
            if !settings.keyDraft.isEmpty { return NookColor.warning }
            if settings.hasAPIKey { return NookColor.success }
            if settings.configuration.isLocalEndpoint, settings.configuration.isComplete {
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
        if settings.errorMessage != nil { return NookColor.danger }
        if case .failure = settings.testState {
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
