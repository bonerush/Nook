import SwiftUI

final class InspectorState: ObservableObject {
    @Published var expanded: Set<String> = ["phrasing", "pace", "appearance", "privacy"]

    func toggle(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }
}

struct InspectorPane: View {
    @ObservedObject var model: AppModel

    @ObservedObject private var state = InspectorState()

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
        VStack(spacing: 0) {
            header
            NookHairline()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    phrasingSection
                    paceSection
                    appearanceSection
                    privacySection
                }
                .padding(16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: NookMetrics.inspectorWidth)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: NookRadius.surface, style: .continuous)
                .fill(NookColor.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NookRadius.surface, style: .continuous)
                .stroke(NookColor.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inspector")
                .font(NookType.caption)
                .fontWeight(.semibold)
                .foregroundStyle(NookColor.textPrimary)
            Spacer(minLength: 8)
            Button {
                model.toggleInspector()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(NookIconButtonStyle())
            .help("Hide inspector (⌥⌘I)")
            .accessibilityLabel("Hide inspector")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var hostLabel: String {
        URL(string: model.llmConfiguration.baseURLString)?.host
            ?? model.llmConfiguration.baseURLString
    }

    private var phrasingSection: some View {
        InspectorSection(
            title: "Phrasing",
            accessory: "At start",
            id: "phrasing",
            state: state
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if model.llmConfiguration.isComplete {
                    HStack(spacing: 6) {
                        Text(model.llmConfiguration.model)
                        Text("·")
                        Text(hostLabel)
                    }
                    .font(NookType.mono(9, weight: .regular))
                    .foregroundStyle(NookColor.textTertiary)
                    .lineLimit(1)
                }

                Text(
                    model.canUseAI
                        ? "AI plans the line breaks and pauses at Start. Your text is never rewritten."
                        : "Local line breaker. Configure AI to phrase at Start."
                )
                .font(NookType.micro)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

                Button("Configure AI") {
                    model.openAISettings()
                }
                .buttonStyle(NookSecondaryButtonStyle())
                .help("Configure the OpenAI-compatible endpoint")
            }
        }
    }

    private var paceSection: some View {
        InspectorSection(
            title: "Pace",
            accessory: "Words per minute",
            id: "pace",
            state: state
        ) {
            VStack(alignment: .leading, spacing: 10) {
                PaceSegmentedControl(
                    presets: pacePresets.map {
                        PaceSegmentedControl.Preset(
                            id: $0.id,
                            title: $0.title,
                            wordsPerMinute: $0.wpm
                        )
                    },
                    selectedWordsPerMinute: model.wordsPerMinute
                ) { wpm in
                    model.setSpeed(Double(wpm))
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
                        .font(NookType.mono(10.5))
                        .foregroundStyle(NookColor.textPrimary)
                        .frame(width: 26, alignment: .trailing)
                        .contentTransition(.numericText())
                }

                Text("Natural English reading pace is the default.")
                    .font(NookType.micro)
                    .foregroundStyle(NookColor.textTertiary)
            }
        }
    }

    private var appearanceSection: some View {
        InspectorSection(
            title: "Appearance",
            accessory: "Notch stage",
            id: "appearance",
            state: state
        ) {
            VStack(alignment: .leading, spacing: 12) {
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
    }

    private func sliderRow(
        title: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(NookType.micro)
                    .foregroundStyle(NookColor.textSecondary)
                Spacer()
                Text(value)
                    .font(NookType.mono(9.5))
                    .foregroundStyle(NookColor.textPrimary)
                    .frame(minWidth: 26, alignment: .trailing)
                    .contentTransition(.numericText())
            }
            Slider(value: binding, in: range, step: step)
                .tint(NookColor.accent)
                .accessibilityLabel(title)
                .accessibilityValue(value)
        }
    }

    private var privacySection: some View {
        InspectorSection(
            title: "Privacy",
            accessory: "Screen sharing",
            id: "privacy",
            state: state
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Best-effort capture hiding")
                            .font(NookType.micro)
                            .fontWeight(.medium)
                            .foregroundStyle(NookColor.textPrimary.opacity(0.9))
                        Text("Asks capture tools to skip the panel. Some meeting apps ignore this.")
                            .font(NookType.micro)
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
                    .controlSize(.small)
                    .accessibilityLabel("Best-effort capture hiding")
                }
            }
        }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let accessory: String?
    let id: String
    @ObservedObject var state: InspectorState
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isExpanded: Bool {
        state.expanded.contains(id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(
                    NookMotion.resolved(NookMotion.inspector, reduceMotion: reduceMotion)
                ) {
                    state.toggle(id)
                }
            } label: {
                HStack(spacing: 6) {
                    NookSectionLabel(title: title, accessory: accessory)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(NookColor.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                content
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
