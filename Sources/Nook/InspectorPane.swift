import SwiftUI

struct InspectorPane: View {
    @ObservedObject var model: AppModel

    private struct PacePreset: Identifiable {
        let id: String
        let title: String
        let wpm: Int
    }

    private let pacePresets = [
        PacePreset(id: "measured", title: "Measured", wpm: 110),
        PacePreset(id: "natural", title: "Natural", wpm: 138),
        PacePreset(id: "interview", title: "Interview", wpm: 152)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                phrasingSection
                sectionDivider
                paceSection
                sectionDivider
                appearanceSection
                sectionDivider
                privacySection
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 18)
        }
        .frame(width: 296)
        .background(NookColor.pane.opacity(0.34))
    }

    private var hostLabel: String {
        URL(string: model.llmConfiguration.baseURLString)?.host
            ?? model.llmConfiguration.baseURLString
    }

    private var sectionDivider: some View {
        LinearHairline()
            .padding(.vertical, 18)
    }

    private var phrasingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LinearSectionLabel(title: "Phrasing", accessory: "AT START")

            HStack(spacing: 7) {
                LinearSourceBadge(source: model.planSource)
                Text(model.canUseAI ? "AI phrasing at Start" : "Local line breaker")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(NookColor.textSecondary)
            }

            if model.llmConfiguration.isComplete {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.llmConfiguration.model)
                        .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(NookColor.textSecondary)
                        .lineLimit(1)
                    Text(hostLabel)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(NookColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Text(
                model.canUseAI
                    ? "Line breaks and pauses are planned by AI at Start."
                    : "Local line breaker. Configure AI to phrase at Start."
            )
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(NookColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            Button("Configure AI") {
                model.openAISettings()
            }
            .buttonStyle(LinearSecondaryButtonStyle())
            .help("Configure the OpenAI-compatible endpoint")
        }
    }

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LinearSectionLabel(title: "Pace", accessory: "WORDS PER MINUTE")

            HStack(spacing: 6) {
                ForEach(pacePresets) { preset in
                    paceButton(preset)
                }
            }

            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { model.wordsPerMinute },
                        set: { model.setSpeed($0) }
                    ),
                    in: 90...200,
                    step: 1
                )
                .tint(NookColor.accent)
                .accessibilityLabel("Reading speed")
                .accessibilityValue("\(Int(model.wordsPerMinute.rounded())) words per minute")

                Text("\(Int(model.wordsPerMinute.rounded()))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(NookColor.textPrimary)
                    .frame(width: 30, alignment: .trailing)
            }

            Text("Natural English reading pace is the default.")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(NookColor.textTertiary)
        }
    }

    private func paceButton(_ preset: PacePreset) -> some View {
        let selected = Int(model.wordsPerMinute.rounded()) == preset.wpm
        return Button {
            model.setSpeed(Double(preset.wpm))
        } label: {
            Text(preset.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selected ? NookColor.textPrimary : NookColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 25)
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
        .help("Set \(preset.wpm) words per minute")
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LinearSectionLabel(title: "Appearance", accessory: "NOTCH STAGE")

            sliderRow(
                title: "Type size",
                value: "\(Int(model.fontSize.rounded()))",
                binding: Binding(
                    get: { model.fontSize },
                    set: { model.fontSize = min(38, max(24, $0.rounded())) }
                ),
                range: 24...38,
                step: 1
            )

            sliderRow(
                title: "Panel width",
                value: "\(Int(model.cardWidth.rounded()))",
                binding: Binding(
                    get: { model.cardWidth },
                    set: { model.cardWidth = min(860, max(600, ($0 / 10).rounded() * 10)) }
                ),
                range: 600...860,
                step: 10
            )
        }
    }

    private func sliderRow(
        title: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(NookColor.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(NookColor.textPrimary)
                    .frame(minWidth: 28, alignment: .trailing)
            }
            Slider(value: binding, in: range, step: step)
                .tint(NookColor.accent)
                .accessibilityLabel(title)
                .accessibilityValue(value)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LinearSectionLabel(title: "Privacy", accessory: "SCREEN SHARING")

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hide from screen sharing")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NookColor.textPrimary.opacity(0.88))
                    Text("The notch panel stays invisible to captures while this is on.")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(NookColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.hideFromCapture },
                        set: { model.hideFromCapture = $0 }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(NookColor.accent)
                .controlSize(.mini)
                .accessibilityLabel("Hide from screen sharing")
            }
        }
    }
}
