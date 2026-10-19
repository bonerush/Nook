import SwiftUI

/// A one-line picture of the script's rhythm. Each block is one sentence; the
/// block width follows the sentence duration. This is the only chart in the
/// editor, and it updates with the document.
struct BreathRibbon: View {
    let document: PromptDocument
    let planSource: PhrasePlanSource

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Segment: Identifiable {
        let id: Int
        let duration: Double
    }

    private var segments: [Segment] {
        guard !document.words.isEmpty else { return [] }
        var result: [Segment] = []
        var index = -1
        var sentenceStart = 0.0
        var sentenceEnd = 0.0
        for word in document.words {
            if word.sentenceIndex != index {
                if index >= 0 {
                    result.append(
                        Segment(id: index, duration: max(0.05, sentenceEnd - sentenceStart))
                    )
                }
                index = word.sentenceIndex
                sentenceStart = word.start
                sentenceEnd = word.end
            } else {
                sentenceEnd = max(sentenceEnd, word.end)
            }
        }
        if index >= 0 {
            result.append(
                Segment(id: index, duration: max(0.05, sentenceEnd - sentenceStart))
            )
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                NookSectionLabel(
                    title: "Breath map",
                    accessory: "\(segments.count) sentences"
                )
                Spacer(minLength: 8)
                NookSourceBadge(source: planSource)
            }

            if segments.isEmpty {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(NookColor.border)
                    .frame(height: 5)
            } else if segments.count > 60 {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(NookColor.accent.opacity(0.45))
                    .frame(height: 5)
            } else {
                GeometryReader { proxy in
                    let available = max(0, proxy.size.width - CGFloat(segments.count - 1) * 2)
                    let total = max(0.001, segments.reduce(0) { $0 + $1.duration })
                    HStack(spacing: 2) {
                        ForEach(segments) { segment in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(NookColor.accent.opacity(0.42))
                                .frame(
                                    width: max(2, available * CGFloat(segment.duration / total))
                                )
                        }
                    }
                }
                .frame(height: 5)
                .animation(
                    NookMotion.resolved(NookMotion.document, reduceMotion: reduceMotion),
                    value: document.sentenceCount
                )
            }

            Text("Each block is one sentence. A wider block takes longer to speak.")
                .font(NookType.micro)
                .foregroundStyle(NookColor.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Breath map. \(segments.count) sentences. About \(Int(document.totalDuration.rounded())) seconds."
        )
    }
}
