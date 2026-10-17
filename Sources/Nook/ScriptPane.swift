import SwiftUI

struct ScriptPane: View {
    @ObservedObject var model: AppModel

    private var scriptBinding: Binding<String> {
        Binding(
            get: { model.script },
            set: { model.script = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 24)

            editorSurface
                .frame(maxHeight: .infinity)
                .padding(.top, 16)

            phraseMap
                .padding(.top, 16)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            LinearSectionLabel(title: "Script", accessory: "ENGLISH · AUTO-PHRASED")

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Text("\(model.document.totalWords) words")
                Text("·")
                Text("\(model.document.sentenceCount) sentences")
                Text("·")
                Text(model.estimatedDurationLabel)
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(NookColor.textTertiary)
        }
    }

    private var editorSurface: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: scriptBinding)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(5.5)
                .foregroundStyle(NookColor.textPrimary.opacity(0.9))
                .tint(NookColor.accent)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.script.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your script")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NookColor.textSecondary)
                    Text("Nook will find the breathing points and keep your eyes near the camera.\nA blank line becomes a longer pause.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(NookColor.textTertiary)
                        .lineSpacing(3)
                }
                .padding(.top, 10)
                .padding(.leading, 12)
                .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 220)
    }

    private var phraseMap: some View {
        VStack(alignment: .leading, spacing: 10) {
            LinearHairline()

            HStack(alignment: .center, spacing: 10) {
                LinearSectionLabel(
                    title: "Phrase map",
                    accessory: "FIRST THREE BREATHS"
                )
                Spacer(minLength: 8)
                LinearSourceBadge(source: model.planSource)
            }

            if model.previewLines.isEmpty {
                Text("Type above to preview the first three phrase breaks.")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(NookColor.textTertiary)
                    .frame(height: 46, alignment: .topLeading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.previewLines.enumerated()), id: \.element.id) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(NookColor.textTertiary.opacity(0.7))
                                .frame(width: 18, alignment: .leading)

                            Text(line.text)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(
                                    index == 0
                                        ? NookColor.textPrimary.opacity(0.82)
                                        : NookColor.textSecondary
                                )
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 0)

                            if index == 0 {
                                Text("NEXT")
                                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                    .tracking(0.8)
                                    .foregroundStyle(NookColor.accent.opacity(0.85))
                            }
                        }
                        .frame(height: 22)

                        if index < model.previewLines.count - 1 {
                            LinearHairline(color: NookColor.border.opacity(0.55))
                                .padding(.leading, 30)
                        }
                    }
                }
            }

            Text("AI will refine line breaks and pauses when you start.")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(NookColor.textTertiary)
        }
    }
}
