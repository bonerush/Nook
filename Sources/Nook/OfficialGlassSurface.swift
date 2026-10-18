import SwiftUI

struct OfficialGlassSurface<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(.black.opacity(0.62)),
                    in: .rect(cornerRadius: cornerRadius)
                )
                // The dark lyric scrim and the glass material must share the
                // same rounded outline. Without this outer clip the scrim
                // paints square corners around the rounded glass.
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
        } else {
            ZStack {
                NookVisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow
                )
                Color.black.opacity(0.62)
                content
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
