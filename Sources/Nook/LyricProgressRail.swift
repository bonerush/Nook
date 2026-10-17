import SwiftUI

struct LyricProgressRail: View {
    @ObservedObject var engine: PlaybackEngine
    let document: PromptDocument

    private var sourceLabel: String {
        document.planSource == .ai ? "AI" : "LOCAL"
    }

    private var phaseLabel: String? {
        switch engine.phase {
        case .ready: return "READY"
        case .finished: return "DONE"
        case .paused: return "PAUSED"
        case .playing, .empty: return nil
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = min(1, max(0, engine.progress))
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.10))
                        .frame(height: 2)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.60), .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * CGFloat(progress), height: 2)
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: NookColor.accent.opacity(0.7), radius: 5)
                        .offset(x: (width - 5) * CGFloat(progress))
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                Text(engine.elapsedLabel)
                    .frame(width: 40, alignment: .leading)

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    Text(sourceLabel)
                    Text("·")
                    Text("\(Int(document.wordsPerMinute.rounded())) WPM")
                    if let phaseLabel {
                        Text("·")
                        Text(phaseLabel)
                    }
                }

                Spacer(minLength: 4)

                Text(engine.remainingLabel)
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.58))
        }
        .frame(height: PromptMetrics.progressAreaHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Reading progress, \(sourceLabel), elapsed \(engine.elapsedLabel), remaining \(engine.remainingLabel)"
        )
    }
}
