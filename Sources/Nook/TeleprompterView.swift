import SwiftUI

struct TeleprompterView: View {
    @ObservedObject var engine: PlaybackEngine
    @ObservedObject var model: AppModel

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let cornerRadius: CGFloat = 30

    private var fontSize: CGFloat { CGFloat(model.fontSize) }
    private var cardWidth: CGFloat { CGFloat(model.cardWidth) }
    private var cardHeight: CGFloat { PromptMetrics.cardHeight(fontSize: fontSize) }

    var body: some View {
        OfficialGlassSurface(cornerRadius: cornerRadius) {
            ZStack {
                if reduceTransparency {
                    Color.black.opacity(0.90)
                }

                VStack(spacing: PromptMetrics.contentToProgressGap) {
                    KaraokeLyricsView(
                        engine: engine,
                        document: engine.document,
                        fontSize: fontSize
                    )

                    LyricProgressRail(
                        engine: engine,
                        document: engine.document
                    )
                }
                .padding(.horizontal, PromptMetrics.textInset)
                .padding(.top, PromptMetrics.cardTopPadding)
                .padding(.bottom, PromptMetrics.cardBottomPadding)
                .frame(
                    width: cardWidth,
                    height: cardHeight,
                    alignment: .top
                )
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .environment(\.colorScheme, .dark)
    }
}
