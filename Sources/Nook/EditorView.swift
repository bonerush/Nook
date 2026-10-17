import AppKit
import SwiftUI

struct EditorView: View {
    @ObservedObject var model: AppModel
    let onStart: () -> Void

    private let settingsWidth: CGFloat = 318
    private let cardRadius: CGFloat = 24

    private struct PacePreset: Identifiable {
        let id: String
        let title: String
        let wpm: Int
    }

    private let presets: [PacePreset] = [
        PacePreset(id: "measured", title: "从容", wpm: 110),
        PacePreset(id: "natural", title: "自然", wpm: 138),
        PacePreset(id: "interview", title: "面试", wpm: 152)
    ]

    var body: some View {
        ZStack {
            NookEditorBackground()

            VStack(spacing: 16) {
                header
                HStack(alignment: .top, spacing: 16) {
                    scriptPanel
                        .layoutPriority(1)
                    settingsPanel
                        .frame(width: settingsWidth)
                }
                .frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 38)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 920, minHeight: 680)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 13) {
            NookLogo(size: 37)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nook")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.35)
                    .foregroundStyle(NookPalette.text)
                Text("刘海提词器 · 英文朗读节奏")
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(0.65)
                    .foregroundStyle(NookPalette.secondaryText)
            }

            Spacer()

            HStack(spacing: 10) {
                NookStatusPill(dotColor: NookPalette.cool, text: "视线对齐镜头")
                HStack(spacing: 7) {
                    NookKeycap("⌃⌥Space")
                    Text("随时播放 / 暂停")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NookPalette.tertiaryText)
                }
                .padding(.leading, 2)
            }
        }
        .frame(height: 44)
    }

    // MARK: Script panel

    private var scriptPanel: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("讲稿")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NookPalette.text)
                    Text("SCRIPT · ENGLISH FIRST")
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(1.45)
                        .foregroundStyle(NookPalette.tertiaryText)
                }

                Spacer()

                Text("\(model.document.totalWords) 词 · \(model.document.sentenceCount) 句")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(NookPalette.tertiaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.035)))
                    .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 0.6))
            }

            editorSurface
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            footerMetrics
            divider

            breathPreview
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .background(NookCardBackground(cornerRadius: cardRadius))
    }

    private var editorSurface: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(.white.opacity(0.065), lineWidth: 0.7)
                )

            TextEditor(text: scriptBinding)
                .font(.system(size: 16.25, weight: .regular))
                .lineSpacing(5.5)
                .foregroundStyle(NookPalette.text.opacity(0.93))
                .tint(NookPalette.warm)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.script.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("粘贴你的英文讲稿")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(NookPalette.secondaryText)
                    Text("Nook 会自动断句、分配呼吸停顿，并把视线留在镜头附近。\n空行会产生更长的停顿。")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(NookPalette.tertiaryText)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 21)
                .padding(.vertical, 22)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .frame(minHeight: 180)
    }

    private var footerMetrics: some View {
        HStack(spacing: 18) {
            metric(icon: "waveform", value: model.estimatedDurationLabel, label: "预计时长")
            metric(icon: "paragraphsign", value: "\(model.document.lineCount)", label: "呼吸组")
            Spacer()
            Label("标点感知节奏", systemImage: "metronome")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NookPalette.tertiaryText)
        }
        .frame(height: 22)
    }

    private func metric(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(NookPalette.warm.opacity(0.7))
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(NookPalette.secondaryText)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(NookPalette.tertiaryText)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(NookPalette.divider)
            .frame(height: 0.7)
    }

    private var breathPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NookSectionLabel(title: "自动断句", accessory: "BREATH GROUPS")
                Spacer()
                Text("实时预览")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(NookPalette.faintText)
            }

            if model.previewLines.isEmpty {
                Text("输入内容后，这里会显示前三组朗读节奏。")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(NookPalette.tertiaryText)
                    .frame(height: 57, alignment: .topLeading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.previewLines.enumerated()), id: \.element.id) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(String(format: "%02d", line.id + 1))
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(NookPalette.faintText)
                                .frame(width: 16, alignment: .leading)

                            Text(line.text)
                                .font(.system(size: 11.75, weight: .medium))
                                .foregroundStyle(index == 0 ? NookPalette.text.opacity(0.88) : NookPalette.secondaryText.opacity(0.78))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 0)
                        }
                        .frame(height: 19)

                        if index < model.previewLines.count - 1 {
                            Rectangle()
                                .fill(.white.opacity(0.035))
                                .frame(height: 0.5)
                        }
                    }
                }
                .frame(height: 57, alignment: .top)
            }
        }
    }

    // MARK: Settings panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("朗读设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NookPalette.text)
                Spacer()
                Text("LIVE CONTROL")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(1.25)
                    .foregroundStyle(NookPalette.tertiaryText)
            }

            pacePresets

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("基础语速")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NookPalette.secondaryText)
                    Spacer()
                    Text(model.speedLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(NookPalette.warm.opacity(0.9))
                }
                Slider(value: speedBinding, in: 90...200, step: 1)
                    .controlSize(.small)
                    .tint(NookPalette.warm)
                    .accessibilityLabel("基础语速，每分钟多少词")
                Text("逗号和句末会自动留白，句子越长越容易被拆成可呼吸的短句。")
                    .font(.system(size: 10, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(NookPalette.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            divider

            VStack(alignment: .leading, spacing: 10) {
                NookSectionLabel(title: "外观", accessory: "FORM")

                sliderRow(
                    label: "字号",
                    value: "\(Int(model.fontSize.rounded())) pt",
                    binding: fontBinding,
                    range: 24...38,
                    step: 1
                )

                sliderRow(
                    label: "面板宽度",
                    value: "\(Int(model.cardWidth.rounded())) pt",
                    binding: widthBinding,
                    range: 600...860,
                    step: 10
                )
            }

            Spacer(minLength: 12)

            divider

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: model.hideFromCapture ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(model.hideFromCapture ? NookPalette.cool : NookPalette.tertiaryText)
                    .frame(width: 17, height: 17)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text("屏幕共享时隐藏")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NookPalette.text.opacity(0.88))
                    Text("录屏与共享画面中不显示提词窗")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(NookPalette.tertiaryText)
                }

                Spacer(minLength: 4)

                Toggle("", isOn: captureBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(NookPalette.warm)
                    .accessibilityLabel("屏幕共享时隐藏提词窗口")
            }

            HStack(spacing: 6) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 9, weight: .medium))
                Text("提词窗默认鼠标穿透，始终不会抢走会议焦点。")
                    .font(.system(size: 9.5, weight: .regular))
            }
            .foregroundStyle(NookPalette.faintText)
            .padding(.top, 1)
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .background(NookCardBackground(cornerRadius: cardRadius))
    }

    private var pacePresets: some View {
        HStack(spacing: 3) {
            ForEach(presets) { preset in
                Button {
                    model.setSpeed(Double(preset.wpm))
                } label: {
                    VStack(spacing: 2) {
                        Text(preset.title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(isSelected(preset) ? NookPalette.warmBright : NookPalette.secondaryText)
                        Text("\(preset.wpm)")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(isSelected(preset) ? NookPalette.warm.opacity(0.7) : NookPalette.faintText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected(preset) ? .white.opacity(0.075) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected(preset) ? NookPalette.warm.opacity(0.22) : .clear, lineWidth: 0.7)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(0.032))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.055), lineWidth: 0.6)
        )
    }

    private func isSelected(_ preset: PacePreset) -> Bool {
        abs(model.wordsPerMinute - Double(preset.wpm)) < 0.5
    }

    private func sliderRow(
        label: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NookPalette.secondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(NookPalette.tertiaryText)
            }
            Slider(value: binding, in: range, step: step)
                .controlSize(.mini)
                .tint(NookPalette.cool)
                .accessibilityLabel(label)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "command")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(NookPalette.warm.opacity(0.7))
                Text("全局快捷键")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.35)
                    .foregroundStyle(NookPalette.tertiaryText)
                Text("⌃⌥Space 播放/暂停   ⌃⌥←/→ 换句   ⌃⌥↑/↓ 语速   ⌃⌥H 隐藏")
                    .font(.system(size: 9.4, weight: .regular, design: .monospaced))
                    .foregroundStyle(NookPalette.secondaryText.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .help("更多快捷键：⌃⌥R 重来 · ⌃⌥E 打开编辑器")

            Spacer()

            Button("载入示例") {
                replaceWithSample()
            }
            .buttonStyle(NookSecondaryButtonStyle())

            Button("清空") {
                clearScript()
            }
            .buttonStyle(NookSecondaryButtonStyle())
            .disabled(model.script.isEmpty)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("开始提词")
                    Text("⌘↩")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(NookPalette.ink.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(NookPalette.ink.opacity(0.08))
                        )
                }
            }
            .buttonStyle(NookPrimaryButtonStyle())
            .disabled(!model.hasContent)
        }
        .frame(height: 44)
    }

    private func replaceWithSample() {
        guard !model.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              model.script != SampleScript.interviewIntro else {
            model.loadSample()
            return
        }

        let alert = NSAlert()
        alert.messageText = "载入示例讲稿？"
        alert.informativeText = "当前讲稿会被替换。此操作不会自动保存旧内容。"
        alert.addButton(withTitle: "载入示例")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            model.loadSample()
        }
    }

    private func clearScript() {
        guard !model.script.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "清空讲稿？"
        alert.informativeText = "这会移除编辑器中的全部内容。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            model.clearScript()
        }
    }

    // MARK: Bindings

    private var scriptBinding: Binding<String> {
        Binding(
            get: { model.script },
            set: { model.script = $0 }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { model.wordsPerMinute },
            set: { model.setSpeed($0) }
        )
    }

    private var fontBinding: Binding<Double> {
        Binding(
            get: { model.fontSize },
            set: { model.fontSize = min(38, max(24, $0.rounded())) }
        )
    }

    private var widthBinding: Binding<Double> {
        Binding(
            get: { model.cardWidth },
            set: { model.cardWidth = min(860, max(600, ($0 / 10).rounded() * 10)) }
        )
    }

    private var captureBinding: Binding<Bool> {
        Binding(
            get: { model.hideFromCapture },
            set: { model.hideFromCapture = $0 }
        )
    }
}
