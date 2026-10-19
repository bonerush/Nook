import SwiftUI

/// The desk behind the paper. A very light vertical gradient and a soft white
/// glow at the top keep the window from looking like a flat white rectangle.
struct NookCanvasBackground: View {
    var body: some View {
        LinearGradient(
            colors: [NookColor.canvasTop, NookColor.canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.92), Color.white.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.02),
                startRadius: 20,
                endRadius: 620
            )
        )
        .ignoresSafeArea()
    }
}

/// Shared chrome for the toolbar and inspector. The white tint keeps both
/// materials on the same lightness instead of letting the system materials
/// turn into two different gray bands.
struct NookChromeBackground: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(NookColor.canvas.opacity(0.18))
    }
}
