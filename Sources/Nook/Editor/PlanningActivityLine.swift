import SwiftUI

/// A thin, indeterminate activity line under the toolbar. It runs only while
/// the AI request is in flight. Reduce Motion shows a static segment instead.
struct PlanningActivityLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(NookColor.accentSoft)
                    .frame(height: 1.5)

                if reduceMotion {
                    Rectangle()
                        .fill(NookColor.accent)
                        .frame(width: max(80, width * 0.25), height: 1.5)
                        .offset(x: width * 0.3)
                } else {
                    LinearGradient(
                        colors: [
                            NookColor.accent.opacity(0),
                            NookColor.accent,
                            NookColor.accent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(120, width * 0.24), height: 1.5)
                    .phaseAnimator([false, true]) { bar, phase in
                        bar.offset(x: phase ? width : -width * 0.35)
                    } animation: { _ in
                        .linear(duration: 1.15)
                    }
                }
            }
        }
        .frame(height: 1.5)
        .clipped()
        .accessibilityHidden(true)
    }
}
