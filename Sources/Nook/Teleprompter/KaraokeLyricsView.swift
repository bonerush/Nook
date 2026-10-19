import SwiftUI

struct KaraokeWordView: View {
    let text: String
    let fontSize: CGFloat
    let progress: Double
    let activeLine: Bool
    let current: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var baseColor: Color {
        activeLine ? .white.opacity(0.68) : .white.opacity(0.86)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .foregroundStyle(baseColor)

            if activeLine {
                Text(text)
                    .foregroundStyle(.white)
                    .mask(
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(
                                    width: proxy.size.width * CGFloat(min(1, max(0, progress))),
                                    alignment: .leading
                                )
                        }
                    )
                    .shadow(color: .white.opacity(0.22), radius: 6)
            }
        }
        .font(.system(size: fontSize, weight: .semibold))
        .tracking(fontSize * -0.006)
        .lineLimit(1)
        .fixedSize()
        .scaleEffect(current && !reduceMotion ? 1.01 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: current)
    }
}

struct KaraokeLyricsView: View {
    @ObservedObject var engine: PlaybackEngine
    let document: PromptDocument
    let fontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let lineHeight = PromptMetrics.lineHeight(fontSize: fontSize)
            let lineGap = PromptMetrics.lineGap(fontSize: fontSize)
            let rowHeight = lineHeight + lineGap
            let focusY = proxy.size.height * 0.48
            let activeLine = engine.currentLineIndex

            if document.lines.isEmpty {
                Text("NO SCRIPT")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: lineGap) {
                    ForEach(document.lines) { line in
                        lyricLine(line, active: line.id == activeLine)
                            .frame(height: lineHeight)
                    }
                }
                .frame(width: proxy.size.width)
                .offset(
                    y: focusY
                        - CGFloat(activeLine) * rowHeight
                        - lineHeight / 2
                )
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.56, dampingFraction: 0.86),
                    value: engine.currentLineIndex
                )
            }
        }
        .clipped()
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.13),
                    .init(color: .black, location: 0.90),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            document.lines.isEmpty
                ? "No script"
                : "Reading line \(engine.currentLineIndex + 1) of \(document.lines.count)"
        )
    }

    @ViewBuilder
    private func lyricLine(_ line: PromptLine, active: Bool) -> some View {
        let distance = line.id - engine.currentLineIndex
        HStack(spacing: PromptMetrics.wordSpacing(fontSize: fontSize)) {
            ForEach(line.wordRange, id: \.self) { index in
                if index < document.words.count {
                    let word = document.words[index]
                    if active {
                        KaraokeWordView(
                            text: word.text,
                            fontSize: fontSize,
                            progress: fillProgress(for: word),
                            activeLine: true,
                            current: engine.currentWordIndex == word.id
                        )
                    } else {
                        Text(word.text)
                            .font(.system(size: fontSize, weight: .semibold))
                            .tracking(fontSize * -0.006)
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(active ? 1 : (distance < 0 ? 0.20 : 0.32))
        .blur(radius: active ? 0 : (distance < 0 ? 0.8 : 0.4))
        .scaleEffect(active || reduceMotion ? 1 : 0.985)
        .shadow(color: .black.opacity(0.35), radius: 2)
        .animation(
            reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.18),
            value: active
        )
    }

    private func fillProgress(for word: PromptWord) -> Double {
        guard let current = engine.currentWordIndex else { return 0 }
        if word.id < current { return 1 }
        if word.id > current { return 0 }
        let duration = max(0.001, word.end - word.start)
        return min(1, max(0, (engine.elapsed - word.start) / duration))
    }
}
