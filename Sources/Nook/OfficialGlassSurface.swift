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
                    .regular.tint(.black.opacity(0.38)),
                    in: .rect(cornerRadius: cornerRadius)
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
