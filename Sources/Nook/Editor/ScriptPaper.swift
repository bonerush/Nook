import SwiftUI

/// The white sheet on the desk: title, meta, the script itself, and the breath
/// map. Everything inside uses the document metrics, never guesswork.
struct ScriptPaper: View {
    @ObservedObject var model: AppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scriptBinding: Binding<String> {
        Binding(
            get: { model.script },
            set: { model.script = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 36)
                .padding(.top, 26)
                .padding(.bottom, 14)

            editorArea

            if !model.document.words.isEmpty {
                NookHairline()
                    .padding(.horizontal, 36)
                    .padding(.top, 8)

                BreathRibbon(document: model.document, planSource: model.planSource)
                    .padding(.horizontal, 36)
                    .padding(.top, 14)
                    .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: NookRadius.paper, style: .continuous)
                .fill(NookColor.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NookRadius.paper, style: .continuous)
                .stroke(NookColor.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 26, x: 0, y: 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Script")
                    .font(NookType.display)
                    .tracking(-0.4)
                    .foregroundStyle(NookColor.textPrimary)

                Spacer(minLength: 12)

                durationBadge
            }

            HStack(spacing: 7) {
                Text("\(model.document.totalWords) words")
                    .contentTransition(.numericText())
                Text("·")
                Text("\(model.document.sentenceCount) sentences")
                    .contentTransition(.numericText())
                Text("·")
                Text("English · line breaks")
            }
            .font(NookType.caption)
            .foregroundStyle(NookColor.textTertiary)
            .animation(NookMotion.counter, value: model.document.totalWords)
            .animation(NookMotion.counter, value: model.document.sentenceCount)
        }
    }

    private var durationBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 9.5, weight: .medium))
            Text(model.estimatedDurationLabel)
                .font(NookType.mono(10))
                .contentTransition(.numericText())
        }
        .foregroundStyle(NookColor.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(
            Capsule(style: .continuous)
                .fill(NookColor.surfaceMuted)
        )
        .accessibilityLabel("Estimated reading time \(model.estimatedDurationLabel)")
    }

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            ScriptTextView(text: scriptBinding)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.93),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.horizontal, 33)
                .padding(.top, 2)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.script.isEmpty {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            floatingIcon

            VStack(spacing: 6) {
                Text("Paste your script")
                    .font(NookType.title)
                    .foregroundStyle(NookColor.textPrimary)
                Text("Nook splits the text into breath-sized lines. A blank line becomes a longer pause.")
                    .font(NookType.callout)
                    .foregroundStyle(NookColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 340)
            }

            Button("Load sample") {
                model.loadSample()
            }
            .buttonStyle(NookSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
        .allowsHitTesting(true)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var floatingIcon: some View {
        let icon = ZStack {
            Circle()
                .fill(NookColor.accentSoft)
                .frame(width: 60, height: 60)
            Image(systemName: "text.bubble")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(NookColor.accent)
        }

        if reduceMotion {
            icon
        } else {
            icon.phaseAnimator([false, true]) { view, phase in
                view.offset(y: phase ? -3 : 0)
            } animation: { _ in
                .easeInOut(duration: 2.8)
            }
        }
    }
}
