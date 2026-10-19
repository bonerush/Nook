import SwiftUI

/// Three pace presets in a quiet segmented control. The selection pill is a
/// plain rounded rectangle whose offset follows the selected index, so it works
/// without matched geometry or macro-backed state.
struct PaceSegmentedControl: View {
    struct Preset: Identifiable {
        let id: String
        let title: String
        let wordsPerMinute: Int
    }

    let presets: [Preset]
    let selectedWordsPerMinute: Double
    let onSelect: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int? {
        presets.firstIndex { Int(selectedWordsPerMinute.rounded()) == $0.wordsPerMinute }
    }

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 3
            let pillWidth = max(0, (proxy.size.width - inset * 2) / CGFloat(presets.count))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(NookColor.surfaceMuted)

                if let index = selectedIndex {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(NookColor.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(NookColor.border, lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                        .frame(width: pillWidth, height: 24)
                        .offset(x: inset + CGFloat(index) * pillWidth)
                        .animation(
                            NookMotion.resolved(NookMotion.selection, reduceMotion: reduceMotion),
                            value: index
                        )
                }

                HStack(spacing: 0) {
                    ForEach(presets) { preset in
                        Button {
                            onSelect(preset.wordsPerMinute)
                        } label: {
                            Text(preset.title)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(
                                    selectedIndex == presets.firstIndex(where: { $0.id == preset.id })
                                        ? NookColor.textPrimary
                                        : NookColor.textSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(
                            selectedIndex == presets.firstIndex(where: { $0.id == preset.id })
                                ? "Selected"
                                : "Not selected"
                        )
                    }
                }
            }
        }
        .frame(height: 30)
    }
}
