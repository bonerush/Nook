import SwiftUI

struct TeleprompterView: View {
    @ObservedObject var engine: PlaybackEngine
    @ObservedObject var model: AppModel

    private let cornerRadius: CGFloat = 30

    private var fontSize: CGFloat { CGFloat(model.fontSize) }
    private var cardWidth: CGFloat { CGFloat(model.cardWidth) }
    private var cardHeight: CGFloat { PromptMetrics.cardHeight(fontSize: fontSize) }
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        card
            .shadow(color: .black.opacity(0.58), radius: 26, y: 14)
            .shadow(color: NookPalette.warm.opacity(0.055), radius: 46, y: 2)
            .padding(PromptMetrics.windowShadowMargin)
            .frame(
                width: cardWidth + PromptMetrics.windowShadowMargin * 2,
                height: cardHeight + PromptMetrics.windowShadowMargin * 2
            )
            .environment(\.colorScheme, .dark)
    }

    private var card: some View {
        ZStack {
            liquidGlassBackdrop
            readingContent
            topSpecular
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(cardShape)
        .overlay(
            cardShape.stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.38),
                        .white.opacity(0.07),
                        .white.opacity(0.03),
                        NookPalette.warm.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
        )
        .overlay(
            cardShape
                .inset(by: 1.2)
                .stroke(.white.opacity(0.045), lineWidth: 0.6)
        )
        .contentShape(cardShape)
        .accessibilityElement(children: .contain)
    }

    // MARK: Glass

    private var liquidGlassBackdrop: some View {
        GeometryReader { proxy in
            ZStack {
                NookVisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    cornerRadius: cornerRadius
                )

                Color(hex: 0x07080B).opacity(0.51)

                LinearGradient(
                    colors: [
                        .white.opacity(0.07),
                        .clear,
                        NookPalette.cool.opacity(0.025)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NookPalette.cool.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.35
                        )
                    )
                    .frame(width: proxy.size.width * 0.7, height: proxy.size.width * 0.7)
                    .offset(
                        x: proxy.size.width * 0.18,
                        y: -proxy.size.height * 0.48
                    )
                    .blur(radius: 34)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [NookPalette.warm.opacity(0.13), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.3
                        )
                    )
                    .frame(width: proxy.size.width * 0.76, height: proxy.size.height * 0.8)
                    .offset(
                        x: -proxy.size.width * 0.20,
                        y: proxy.size.height * 0.4
                    )
                    .blur(radius: 42)

                NookGrainOverlay(opacity: 0.19)

                LinearGradient(
                    colors: [.black.opacity(0.16), .clear, .black.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(cardShape)
        .allowsHitTesting(false)
    }

    private var topSpecular: some View {
        VStack {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.9), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: cardWidth * 0.33, height: 1)
                .shadow(color: .white.opacity(0.18), radius: 1.5)
                .blur(radius: 0.35)
                .padding(.top, 0.6)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    // MARK: Reading surface

    private var readingContent: some View {
        VStack(spacing: PromptMetrics.contentToProgressGap) {
            lineViewport
            progressPanel
        }
        .padding(.horizontal, PromptMetrics.textInset)
        .padding(.top, PromptMetrics.cardTopPadding)
        .padding(.bottom, PromptMetrics.cardBottomPadding)
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
    }

    private var lineViewport: some View {
        ZStack {
            if engine.document.lines.isEmpty {
                emptyState
            } else {
                scrollingLines
            }
        }
        .frame(height: PromptMetrics.viewportHeight(fontSize: fontSize))
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
    }

    private var scrollingLines: some View {
        GeometryReader { proxy in
            let lineHeight = PromptMetrics.lineHeight(fontSize: fontSize)
            let lineGap = PromptMetrics.lineGap(fontSize: fontSize)
            let rowHeight = lineHeight + lineGap
            let focusY = proxy.size.height * 0.50
            let activeLine = engine.currentLineIndex

            VStack(spacing: lineGap) {
                ForEach(engine.document.lines) { line in
                    lineView(line)
                        .frame(height: lineHeight)
                }
            }
            .frame(width: proxy.size.width)
            .offset(
                y: focusY
                    - CGFloat(activeLine) * rowHeight
                    - lineHeight / 2
            )
            .animation(.easeInOut(duration: 0.42), value: engine.currentLineIndex)
        }
        .allowsHitTesting(false)
    }

    private func lineView(_ line: PromptLine) -> some View {
        let active = line.id == engine.currentLineIndex
        let distance = line.id - engine.currentLineIndex
        let displayOffset = distance < 0 ? 0.24 : 0.40

        return HStack(spacing: PromptMetrics.wordSpacing(fontSize: fontSize)) {
            ForEach(line.wordRange, id: \.self) { wordIndex in
                if wordIndex < engine.document.words.count {
                    wordView(
                        engine.document.words[wordIndex],
                        activeLine: active
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(active ? 1 : displayOffset)
        .blur(radius: active ? 0 : (distance < 0 ? 0.65 : 0.3))
        .scaleEffect(active ? 1 : 0.985)
        .animation(.easeInOut(duration: 0.34), value: engine.currentLineIndex)
    }

    private func wordView(_ word: PromptWord, activeLine: Bool) -> some View {
        let isCurrent = activeLine && engine.currentWordIndex == word.id
        let color = wordColor(for: word, activeLine: activeLine, isCurrent: isCurrent)

        return Text(word.text)
            .font(.system(size: fontSize, weight: .semibold))
            .tracking(fontSize * -0.006)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                NookPalette.warm.opacity(0.20),
                                NookPalette.warm.opacity(0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(NookPalette.warmBright.opacity(0.17), lineWidth: 0.7)
                    )
                    .padding(.horizontal, -7)
                    .padding(.vertical, -2)
                    .opacity(isCurrent ? 1 : 0)
                    .blur(radius: isCurrent ? 0 : 0.5)
            }
            .shadow(
                color: isCurrent ? NookPalette.warm.opacity(0.30) : .clear,
                radius: isCurrent ? 9 : 0
            )
            .animation(.easeOut(duration: 0.13), value: isCurrent)
    }

    private func wordColor(for word: PromptWord, activeLine: Bool, isCurrent: Bool) -> Color {
        if isCurrent {
            return NookPalette.warmBright
        }
        if activeLine {
            guard let current = engine.currentWordIndex else {
                return .white.opacity(0.86)
            }
            return word.id < current ? .white.opacity(0.48) : .white.opacity(0.87)
        }
        return .white.opacity(0.94)
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 17, weight: .light))
            Text("在编辑器里写入你的英文讲稿")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(NookPalette.secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Song-style progress

    private var progressPanel: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = min(1, max(0, engine.progress))

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.075))
                        .frame(height: 3)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [NookPalette.cool.opacity(0.8), NookPalette.warm],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * CGFloat(progress), height: 3)
                        .shadow(color: NookPalette.warm.opacity(0.28), radius: 4)

                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle()
                                .stroke(NookPalette.warm.opacity(0.8), lineWidth: 1.2)
                                .padding(-1.4)
                        )
                        .shadow(color: NookPalette.warm.opacity(0.7), radius: 5)
                        .offset(x: (width - 7) * CGFloat(progress))
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack(spacing: 10) {
                Text(engine.elapsedLabel)
                    .frame(width: 42, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: stateColor.opacity(0.6), radius: 4)

                    Text(engine.phase.label)
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(1.15)

                    Text("·")
                        .opacity(0.55)

                    Text("\(Int(model.wordsPerMinute.rounded())) WPM")
                        .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                        .tracking(0.2)
                }

                Spacer(minLength: 0)

                Text(engine.remainingLabel)
                    .frame(width: 48, alignment: .trailing)
            }
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(NookPalette.secondaryText.opacity(0.84))
        }
        .frame(height: PromptMetrics.progressAreaHeight, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "朗读进度，\(engine.phase.label)，已用时 \(engine.elapsedLabel)，剩余 \(engine.remainingLabel)"
        )
    }

    private var stateColor: Color {
        switch engine.phase {
        case .playing: return NookPalette.warmBright
        case .ready: return NookPalette.cool
        case .paused: return NookPalette.warm.opacity(0.72)
        case .finished: return NookPalette.cool
        case .empty: return .white.opacity(0.2)
        }
    }

}
