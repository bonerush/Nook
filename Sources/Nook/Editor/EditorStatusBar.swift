import SwiftUI

struct EditorStatusBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Text(model.speedLabel)
                .contentTransition(.numericText())
                .animation(NookMotion.counter, value: model.wordsPerMinute)

            Text("≈ \(model.estimatedDurationLabel)")
                .contentTransition(.numericText())
                .animation(NookMotion.counter, value: model.estimatedDurationLabel)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                NookKeycap("⌘↩")
                Text("Start")
                NookKeycap("⌃⌥Space")
                Text("Play")
            }
            .font(NookType.micro)
            .foregroundStyle(NookColor.textTertiary)
        }
        .font(NookType.mono(10))
        .foregroundStyle(NookColor.textTertiary)
        .padding(.horizontal, 24)
        .frame(height: NookMetrics.statusBarHeight)
    }
}
