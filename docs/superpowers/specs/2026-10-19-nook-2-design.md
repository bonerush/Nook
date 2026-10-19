# Nook 2.0 工程设计文稿

- 日期：2026-10-19
- 状态：已实现（2.0.0），独立代码、界面、文档审查通过（pass-with-notes）
- 范围：Nook macOS 菜单栏提词器 2.0
- 版本：1.1.0 → 2.0.0
- 构建约束：macOS 14+、直接 swiftc、无 SwiftPM/Xcode、无第三方依赖、不使用 @State 等宏属性包装器

## 0. 一页纸摘要

Nook 1.1 已经能工作：AI 断句、官方 Liquid Glass、Apple Music 式歌词。但它有三个工程问题。

1. 主界面只是"正确"，还不"动人"。页面是一张白纸，没有层次，没有动效，像一个表单。
2. 代码全部平铺。AppDelegate 690 行，AppModel 552 行。界面、状态、菜单、预览、快捷键混在一起。
3. 文档只有一份 README。新手无法在一小时内建立完整心智模型。

Nook 2.0 做三件事：

- **工程重构**：按 Apple 示例代码的分层方式拆分模块；把应用生命周期、菜单栏、快捷键、窗口、预览拆成独立控制器；把 AI 设置和偏好存储从 AppModel 中抽出；保持行为不变。
- **界面重做**：采用 Pages / Freeform 的"浅色工作室"语言：柔和画布、白色纸张、悬浮检查器、呼吸节奏带；用 Apple 官方弹簧曲线做克制的入场、切换和反馈动效。
- **文档重建**：以"一小时从小白到能改代码"为目标，写 9 篇文档、6 张图；用 ASD-STE100 的等价中文规则写作，并提供自动检查脚本。

## 1. 背景与问题

### 1.1 现状（1.1.0）

| 维度 | 现状 |
| --- | --- |
| 产品 | 英文提词器。AI 只返回 token 索引，不改写原文 |
| 代码量 | 约 5 800 行 Swift（Sources），约 1 100 行检查 |
| 目标 | macOS 14+，菜单栏 app，刘海下方 NSPanel |
| 构建 | scripts/build.sh 直接 swiftc，ad-hoc 签名 |
| 测试 | 自建 TestHarness，535 项检查 |
| 文档 | README 192 行 + 旧 spec/plan |

### 1.2 工程问题（有证据）

1. **AppDelegate 是上帝对象**（690 行）。它同时负责：应用启动、菜单栏项、主菜单、快捷键、窗口协调、开始流程、屏幕观察、预览舞台、About 面板。
2. **AppModel 承担三种职责**（552 行）：文档构建、偏好持久化、AI 设置与密钥。AI 设置的草稿状态（7 个 @Published）和文档状态无关，却让每次设置输入都触发同一个对象的 objectWillChange。
3. **目录是平的**。Sources/Nook 下 20 个文件同级；DesignSystem 只存在于一个 LinearDesign.swift 中，且命名仍叫 Linear。
4. **构建脚本用通配符摊平编译**（Sources/Nook/*.swift），目录无法分组。测试同样。
5. **重复的视图代码**：状态胶囊、按钮样式、hairline、keycap 被复制到多个文件。
6. **没有动效 token**。唯一动画在提词面板；编辑器交互没有反馈。
7. **可访问性靠零散修饰符**，没有统一策略；Reduce Motion 只在歌词视图处理。
8. **编译有 Sendable 警告**（AppModel 跨 Task 捕获），说明线程边界不清晰。

### 1.3 界面问题

以 1040 × 720 截图（/tmp/nook-editor.png 基线）为准：

- 白纸和白工具栏没有分离，窗口缺少层次。
- 顶栏只有 "Script" 三个字，没有产品识别。
- 右栏像设置表单，不像工作区的一部分。
- 正文下方 40% 是空白，没有利用。
- 所有状态变化都是瞬时的：AI 状态、断句结果、按钮按下都没有过渡。
- 空状态只有两行灰字。
- 强调色只出现在 Start 和滑块，缺少节奏。

### 1.4 文档问题

- README 是"功能清单 + 命令"，不是学习路径。
- 没有架构图、数据流图、状态机图。
- 术语（token、plan、phrase、breath、line、document）没有定义。
- 新读者不知道先读什么、读完后能做什么。
- 没有"如何改一个功能"的操作指南。

## 2. 调研综述

> 调研报告位于 docs/research/。本节只保留对设计有约束力的结论。

### 2.1 Apple 生态工程标准

调研见 [apple-engineering.md](../../research/2026-10-19-apple-engineering.md)。

1. **面板语义**：悬浮提词窗应使用 `NSPanel` + `.nonactivatingPanel` + `becomesKeyOnlyIfNeeded`。点击面板不激活 app，不打断用户正在共享的窗口。
2. **常驻面板是刻意偏离**：HIG 要求 app 不活跃时隐藏 panel。提词器是 HUD，必须在演示时常驻。记录为产品决定，并提供显示/隐藏开关。
3. **菜单完整性**：工具栏上的每个操作都要有菜单命令。主菜单要有 File / Edit / Format / View / Window / Help 的合理子集。
4. **材质语义**：工具栏与侧栏使用系统 material，不叠加自绘白色；非活跃窗口的变暗交给系统。
5. **屏幕共享隐藏是假象**：Apple 文档写明 `NSWindow.SharingType.none` 是 legacy，并明确"不要用它隐藏内容"。当前 README 的承诺必须改写。取舍见 5.10。
6. **Reduce Motion 双入口**：SwiftUI 用 `accessibilityReduceMotion`；AppKit 用 `NSWorkspace.accessibilityDisplayShouldReduceMotion`，并订阅 `accessibilityDisplayOptionsDidChangeNotification`。
7. **无 Xcode 的边界**：ad-hoc 签名、无 notarize、无 asset catalog、无 XCTest。写入 README，不让用户自己发现。
8. **官方示例的共性**：按能力拆 target；没有测试章节。Nook 保持单 target + 自建检查，是合理取舍。

### 2.2 界面与动效语言

调研见 [apple-ui-motion.md](../../research/2026-10-19-apple-ui-motion.md)。

1. **Apple 弹簧预设**（本机实测）：`.smooth` 0.5 s / bounce 0；`.snappy` 0.5 s / bounce 0.15；`.bouncy` 0.5 s / bounce 0.30。三者时长相同，只差回弹。交互反馈用 `.snappy(duration: 0.2–0.3)`，不要默认 0.5 s。
2. **动效是状态解释**，不是装饰。Apple 的规则：只动必要元素，只在状态变化时动，交接用 completion 而不是等 settling。
3. **可读性优先**：正文行宽 64–72 字符，行距 8，字号 17。
4. **本地实测可用性**：macOS 14 可用 `.smooth/.snappy/.bouncy`、`phaseAnimator`、`keyframeAnimator`、`contentTransition(.numericText())`、`symbolEffect`；`glassEffect` 需 26，`MeshGradient` 需 15。`@State` 在纯 swiftc 下确实编不过（StateMacro plugin 缺失），禁令是硬约束。
5. **反面清单**：正文区不用 `.bouncy`；不共享 `matchedGeometryEffect` 的 source；不在 macOS 14 调用 glassEffect。

### 2.3 文档标准

调研见 [ste-docs.md](../../research/2026-10-19-ste-docs.md)。

1. ASD-STE100 Issue 9（2025-01-15）有 53 条规则：操作句 ≤ 20 词，说明句 ≤ 25 词，段落 ≤ 6 句，多词名词 ≤ 3 词，主动语态，一句一指令，禁分号。
2. 没有"完全合规"认证。写作目标是"按等价中文规则编写，并用脚本量化检查"，不声称官方认证。
3. 中文等价阈值（项目约定）：操作句 ≤ 20 汉字，说明句 ≤ 25 汉字，段落 ≤ 6 句，术语变体 = 1，禁"进行/予以/加以 + 名词"。
4. 结构用 Diátaxis：tutorial / how-to / reference / explanation。README 只保留最短成功路径。
5. 图必须可被单独理解：标题、alt 文本、说明；导出 PNG 后人工或 agent 视觉检查文字不重叠。

## 3. 设计原则

1. **行为不变，结构改变**：重构不改产品行为。所有快捷键、鼠标穿透、屏幕共享隐藏、Keychain、缓存键、bundle id 保持。
2. **一个文件一件事**：文件超过 300 行就要问"它是不是两个东西"。
3. **依赖指向内层**：UI → 状态 → 领域 → 基础设施。NookKit 不 import SwiftUI/AppKit 的界面类型。
4. **可测试的纯逻辑**：文档构建、偏好、设置校验都应是纯函数或可注入对象。
5. **原生优先**：能用系统控件、系统材质、系统动效就不自己画。
6. **克制**：一个强调色，两种材质，三种圆角。动效只解释状态变化，不做装饰。
7. **可访问**：键盘可达、VoiceOver 可读、Reduce Motion / Reduce Transparency 生效、对比度达标。

## 4. 目标架构

### 4.1 分层

```text
┌──────────────────────────────────────────────┐
│ Presentation   SwiftUI views + AppKit panels │
│   Editor / Inspector / Settings / Stage      │
├──────────────────────────────────────────────┤
│ Application    controllers, coordinators     │
│   AppDelegate, MenuBar, HotKeys, Window,     │
│   EditorCoordinator, PreviewHarness          │
├──────────────────────────────────────────────┤
│ State          ObservableObject models       │
│   AppModel, AISettingsModel, PlaybackEngine  │
├──────────────────────────────────────────────┤
│ Domain         NookKit (pure Swift)          │
│   tokenizer, plan, layout, composer, AI      │
├──────────────────────────────────────────────┤
│ Infrastructure UserDefaults, Keychain, HTTP, │
│                file cache                    │
└──────────────────────────────────────────────┘
```

### 4.2 模块与目录

```text
Sources/NookKit/
  Core/        SpeechScript, PhrasePlan, PhraseLayout, PromptScript
  Planning/    HeuristicPhrasePlanner, PromptComposer, PhrasePlanningPrompt, AIPlanningCoordinator
  Providers/   LLMConfiguration, HTTPTransport, OpenAICompatibleClient
  Storage/     KeychainStore, PhrasePlanCache

Sources/Nook/
  App/         NookMain, AppDelegate, EditorWindowController, MenuBarController,
               ApplicationMenuController, HotKeyRouter, EditorCoordinator,
               PreviewHarness, GlobalHotKeys
  Model/       AppModel, AISettingsModel, NookTime
  Editor/      EditorView, EditorToolbar, ScriptPaper, ScriptTextView,
               BreathRibbon, InspectorPane, PaceSegmentedControl,
               AISettingsOverlay, PlanningErrorBanner, EditorStatusBar, EditorActions
  DesignSystem/ NookColor, NookType, NookSpace, NookRadius, NookMotion,
               NookComponents (button, chip, card, section, keycap)
  Teleprompter/ TeleprompterController, TeleprompterView, KaraokeLyricsView,
               LyricProgressRail, OfficialGlassSurface, PlaybackEngine
```

### 4.3 关键重构

| 现在 | 之后 | 理由 |
| --- | --- | --- |
| AppDelegate 690 行 | AppDelegate ≤ 150 行 + 6 个控制器 | 单一职责，可测试 |
| AppModel 552 行 | AppModel（文档/播放偏好）+ AISettingsModel（设置）+ PreferencesStore | 隔离无关状态，减少刷新 |
| ai* 草稿 7 个 @Published | AISettingsModel 内部 | 设置输入不再刷新编辑区 |
| 直接读写 UserDefaults | PreferencesStore 协议/结构体 | 可注入 suite，测试安全 |
| 各处散落 Design tokens | DesignSystem 目录 | 一致性与可维护 |
| 视图内魔法数 | NookSpace / NookRadius / NookMotion | 统一节奏 |
| Sources/Nook/*.swift | 递归编译 | 支持子目录 |
| 无动效 | NookMotion + 视图过渡 | 生动但克制 |

### 4.4 状态与数据流

```text
User edits script
  → AppModel.script didSet
  → PreferencesStore.saveScript
  → 0.16 s debounce
  → ScriptDocumentBuilder.build(script, plan, options)
  → PromptDocument (@Published)
  → ScriptWorkspace / BreathRibbon / Inspector metrics

User presses Start
  → EditorCoordinator.start
  → AppModel.prepareForStart
      → AI configured ? AIPlanningCoordinator.prepare : local plan
      → validate → cache → document
  → on ready: panel.show(autoplay)
  → on failure: editor shows banner
```

### 4.5 测试策略

- NookKit 纯逻辑：现有 535 项检查保留，新增 PreferencesStore、ScriptDocumentBuilder、AISettingsModel 校验、文档/动效 token 的纯逻辑检查。
- 视图层：不引入快照框架。用"预览模式 + 截图 + 人工/agent 视觉审查"代替。
- 行为回归：用截图对比 960×680、1040×720、AI 设置、空状态、提词面板 5 个场景。
- 文档检查：scripts/check-docs.py 检查句长、术语、链接、图片 alt、图表文件存在。

## 5. 界面设计：Quiet Studio

### 5.1 方向

参考 Pages 的"纸张 + 画布"、Freeform 的"悬浮工具与检查器"、Notes 的"安静写作"、Music 的"节奏可视化"。

一句话：**把 Nook 从表单变成一张放在浅色桌面上的纸。**

### 5.2 布局

```text
┌───────────────────────────────────────────────────────────────┐
│  ◆ Nook   Teleprompter      ● AI ready   113 words · 1:00  ⚙  ▶ Start │  48
├───────────────────────────────────────────────────────────────┤
│                                                               │
│      ┌─────────────────────────────────────────┐   ┌────────┐ │
│      │  Script                          ⋯      │   │Inspector│ │
│      │  English · line breaks   113 · 7 · 1:00 │   │        │ │
│      │                                         │   │ Pace   │ │
│      │  Hi, I'm [Your Name], and I'm a ...     │   │ ◉◉◉    │ │
│      │                                         │   │        │ │
│      │  Over the past three years, ...         │   │ Look   │ │
│      │                                         │   │        │ │
│      │  ─────────────────────────────────────  │   │ Privacy│ │
│      │  Breath map                    [Local]  │   └────────┘ │
│      │  01  Hi, I'm [Your Name],      ▬▬▬      │              │
│      │  02  and I'm a software engineer ▬▬      │              │
│      │  03  based in Shanghai.         ▬        │              │
│      └─────────────────────────────────────────┘              │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  138 WPM   ≈ 1:00                              ⌃⌥Space  ⌘↩   │  30
└───────────────────────────────────────────────────────────────┘
```

- 画布：系统灰 6（#F5F5F7）到 #FAFAFC 的极淡纵向渐变。
- 纸张：纯白，最大宽度 720，圆角 20，0.5 pt 边框 #E5E5EA，柔和阴影（黑 6%，y=10，blur=30）。
- 顶栏高度 48；正文每行 64–72 个字符。
- 检查器：白色悬浮卡片，圆角 16，与窗口留 12 pt 间距，可收起。
- 顶栏：透明 + system material，底部 hairline 只在需要时出现。
- 状态栏：透明，字号 10.5，monospaced 数字。

### 5.3 颜色

| Token | 值 | 用途 |
| --- | --- | --- |
| canvas | #F5F5F7 → #FAFAFC | 背景 |
| paper | #FFFFFF | 纸张 |
| surface | #FFFFFF | 检查器卡片 |
| surfaceMuted | #F2F2F4 | 行 hover、分段控件槽 |
| border | #E5E5EA | 1 px 分隔 |
| borderStrong | #D1D1D6 | 卡片边缘 |
| textPrimary | #1D1D1F | 正文、标题 |
| textSecondary | #515154 | 标签 |
| textTertiary | #6E6E73 | 辅助（对比度 ≥ 4.7:1） |
| accent | #007AFF | 唯一强调色 |
| accentPressed | #0063D1 | 按下 |
| success | #1F7A34 | AI ready |
| warning | #B25000 | planning |
| danger | #D70015 | error |

不使用紫色、渐变文字、彩色阴影。

### 5.4 字体

| Token | 大小/字重/行高 | 用途 |
| --- | --- | --- |
| display | 28 / semibold / 34，tracking −0.4 | 纸张标题 |
| title | 17 / semibold / 24 | 区块标题 |
| body | 17 / regular / 26（lineSpacing 8） | 正文输入 |
| callout | 13 / regular / 20 | 说明 |
| caption | 11 / medium / 14 | 标签、状态 |
| mono | 10.5 / medium / 14 | 数字、快捷键 |

正文 17（提词面板仍按用户设置 24–38）。

### 5.5 间距与圆角

- 间距：4 / 8 / 12 / 16 / 20 / 24 / 32。
- 圆角：控件 8、卡片 12、纸张 20、胶囊 999。
- 纸张内边距：水平 36、垂直 28。
- 检查器内边距：16。
- 内容最小 960×680（窗口 960×712），默认 1080×740。

### 5.6 组件

1. **NookToolbar**：品牌标记（SF Symbol + 文字）、文档指标（动画数字）、AI 状态胶囊、设置按钮、Start 胶囊按钮。
2. **ScriptPaper**：标题、元信息、TextEditor、空状态、BreathRibbon。
3. **BreathRibbon**：每句一段，段宽按朗读时长，间隙按停顿；hover 显示句子与时长；数据变化时 spring 过渡。
4. **InspectorCard**：可折叠分区（Phrasing / Pace / Appearance / Privacy），分区标题带 chevron 旋转。
5. **NookSegmentedControl**：胶囊选中背景 matchedGeometryEffect。
6. **NookStatusBar**：WPM、预计时长、快捷键提示。
7. **NookChip**：AI 状态、来源标签。
8. **NookButtonStyle**：primary / secondary / ghost / icon。
9. **AISettingsSheet**：material 背景、分组、provider 分段、密钥显隐、底部操作。

### 5.7 动效表

所有动效都读取 `accessibilityReduceMotion`。开启后，位移/缩放改为 0.01 s 的透明度过渡或直接切换。

| 场景 | 曲线 | 感知时长 | 变化 |
| --- | --- | --- | --- |
| 窗口内容入场 | `.smooth(duration: 0.5)` | 0.5 s | 顶栏 y −6、纸张 y +14 + scale 0.995、检查器 x +20，透明度 0→1 |
| 检查器展开/收起 | `.snappy(duration: 0.3)` | 0.3 s | 宽度 0↔300，内容淡入 |
| 分段控件选择 | `.snappy(duration: 0.22)` | 0.22 s | 选中胶囊位移 |
| 计数器变化 | `.snappy(duration: 0.28)` | 0.28 s | numericText 过渡 |
| 按钮按下 | `.snappy(duration: 0.18)` | 0.18 s | scale 0.985，亮度 −3% |
| hover | `.smooth(duration: 0.16)` | 0.16 s | 背景 surfaceMuted，图标 +4% 亮度 |
| AI planning | 循环脉冲 | 1.4 s | 状态点 opacity 0.45↔1 |
| 断句结果更新 | `.snappy(duration: 0.3)` | 0.3 s | 行插入/移除 + 透明度 |
| 空状态浮动 | easeInOut 2.8 s 往返 | 2.8 s | 图标 y ±3 |
| 提词面板入场 | `.smooth(duration: 0.42)` | 0.42 s | scale 0.97→1、y −8→0、opacity |
| AI 规划活动线 | linear | 1.15 s 扫过 |
| 开始成功交接 | `.snappy(duration: 0.2)` | 0.2 s | 编辑器 scale 0.985 + 淡出，然后显示面板 |
| 歌词行切换（保留） | spring(0.56, 0.86) | 0.56 s | 已有 |

原则：

- 输入文字时不触发任何布局动画（只更新计数器和节奏带，且用 0.22 s 以内）。
- 同一时刻最多两个元素移动。
- 不使用无限旋转加载器；planning 用脉冲点 + 文案。

### 5.8 可访问性

- 所有图标按钮有 accessibilityLabel 与 help。
- BreathRibbon 提供 accessibilityLabel（句子数、总时长）。
- 检查器分区可用键盘展开；焦点顺序：工具栏 → 纸张 → 检查器 → 状态栏。
- 对比度：正文 16.1:1，次要 7.6:1，三级 4.8:1。
- Reduce Motion、Reduce Transparency、Increase Contrast 均生效。
- 提词面板保留 VoiceOver 摘要。

### 5.9 性能

- 动画只使用 transform / opacity；避免动画 blur 和 shadow。
- 输入时只重建文档（纯计算），不重建窗口。
- BreathRibbon 用 Canvas 或简单 HStack；句子数 > 200 时降级为单一进度条。
- 不在 body 中创建 Formatter/DateFormatter。

## 6. 文档系统

### 6.1 读者模型

读者是"会一点编程、没看过这个项目的人"。目标：60 分钟能回答 10 个问题。

1. Nook 为谁解决什么问题？
2. 一次开始提词发生了什么？
3. 讲稿文本为什么不会被 AI 改写？
4. 断句计划、文档、歌词三者的关系？
5. 密钥存在哪里？
6. 哪个文件负责哪件事？
7. 如何构建与运行？
8. 如何改语速/断句/界面？
9. 失败时看哪里？
10. 为什么这样设计？

### 6.2 阅读路径（60 分钟）

| 时间 | 文档 | 产出 |
| --- | --- | --- |
| 0–5 | docs/01-what-is-nook.md | 知道产品与用户 |
| 5–15 | docs/02-quick-start.md | 本机跑起来 |
| 15–25 | docs/03-concepts.md | 掌握 12 个术语 |
| 25–40 | docs/04-architecture.md | 画出模块与数据流 |
| 40–50 | docs/05-design-system.md | 知道颜色/字号/动效从哪来 |
| 50–60 | docs/06-development.md | 能改一个小功能并验证 |

其余为参考：07-ai-phrasing、08-troubleshooting、09-code-map。

### 6.3 写作规则（STE 等价中文）

1. 一句一个意思。句子 ≤ 25 个汉字。
2. 用主动语态。少用"被"。
3. 步骤用动词开头。一步一个动作。
4. 术语固定：script、token、phrase plan、breath、panel 只用一个译名（见术语表）。
5. 先结论，后原因。
6. 不用比喻解释机制。比喻只用于产品介绍。
7. 警告单独成段，以"注意："开头。
8. 每篇文档开头写"读完后你能做什么"。
9. 每段不超过 4 句。
10. 图必须有标题、alt 文本、文字说明。

量化验收：

- ≥ 90% 的句子 ≤ 25 字。
- 每篇文档有目的、前置条件、下一步。
- 术语表覆盖率 100%（首次出现链接术语表）。
- 所有内部链接可解析。
- 图表导出为 PNG，文字不重叠（人工/agent 视觉检查）。

### 6.4 文档结构

```text
README.md                       门面：是什么、30 秒开始、文档入口
docs/
  README.md                     一小时路线图 + 文档地图（图）
  01-what-is-nook.md            产品、用户、界面截图
  02-quick-start.md             构建、运行、第一次提词
  03-concepts.md                术语表 + 心智模型（图）
  04-architecture.md            分层、模块、数据流、开始流程（3 图）
  05-design-system.md           颜色、字体、间距、动效、组件
  06-development.md             构建/测试/调试/加功能/发布
  07-ai-phrasing.md             AI 合约、校验、缓存、错误
  08-troubleshooting.md         常见问题
  09-code-map.md                文件地图（表）
  style-guide.md                写作规则与术语
  assets/                       6 张 PNG + drawio 源文件
```

### 6.5 图表清单

| 图 | 类型 | 内容 |
| --- | --- | --- |
| doc-map | 流程图 | 60 分钟阅读路径 |
| architecture | 分层图 | 5 层 + 模块 |
| data-flow | 流程图 | 编辑 → 文档 → 播放 |
| start-sequence | 时序图 | Start → AI → panel |
| ai-state | 状态机 | idle/planning/failed/ready |
| ui-anatomy | 标注图 | 主界面 8 个区域 |
| build-pipeline | 流程图 | swiftc → .app → 安装 |

用 draw.io 生成，导出 2× PNG，检查文字不重叠。

## 7. 实施计划（概览）

详见 docs/superpowers/plans/2026-10-19-nook-2-implementation.md。

1. 基线：测试、截图、备份。
2. 目录与构建：递归编译，移动文件，重命名 Linear → Nook。
3. DesignSystem：tokens、组件、替换旧样式。
4. 状态层：PreferencesStore、AISettingsModel、ScriptDocumentBuilder。
5. 控制器：拆 AppDelegate。
6. 编辑器 UI：工具栏、纸张、节奏带、检查器、空状态、动效。
7. AI 设置与提词面板动效。
8. 文档与图表。
9. 验证与审查。

每个阶段：构建 + 测试 + 截图；关键检查点派独立 subagent 审查。

## 8. 验收标准

### 工程

- ./scripts/test.sh 通过，检查数 ≥ 550，且不低于重构前的 535。
- ./scripts/build.sh 通过，无警告。
- 目录符合 4.2。AppDelegate ≤ 180 行，AppModel ≤ 350 行；UI 组合文件允许到 500 行。
- 无第三方依赖；无 @State/@FocusState/@StateObject。
- API key 不出现在 UserDefaults、日志、截图、仓库。

### 界面

- 内容 960×680（窗口 960×712）与 1080×740 无裁切、无重叠。
- 5 个场景截图通过独立 UI 审查。
- Reduce Motion 下无位移/缩放动画。
- 键盘可完成：输入 → 开始 → 暂停 → 返回。
- 对比度：正文 ≥ 4.5:1，大字 ≥ 3:1。

### 文档

- 9 篇文档 + README 完成，全部链接有效。
- 自动检查 ≥ 80 分。
- 新鲜读者测试 ≥ 8/10。
- 7 张图导出并人工检查无重叠。

## 9. 非目标

- 不加入多讲稿管理、云同步、账号。
- 不做中文分词、语音跟随。
- 不改 AI 合约、缓存键、bundle id。
- 不换构建系统（仍为 swiftc）。
- 不重做图标。

### 5.10 对 Apple 规范的取舍

| 规范 | Nook 的做法 | 理由 |
| --- | --- | --- |
| Panel 在 app 不活跃时隐藏 | 提词窗常驻，用户可 ⌃⌥H 隐藏 | 演示时用户正在用别的 app；这是核心场景 |
| `sharingType = .none` 隐藏录制 | 保留为"尽力而为"；UI 文案改为 "Best-effort capture hiding"；文档写明不能保证 | 会议软件不保证遵守；不能继续承诺"看不见" |
| 菜单栏图标可隐藏 | 暂不提供 | 图标是唯一常驻入口；隐藏后恢复路径不完整，记录为已知偏差 |
| 工具栏每项都有菜单命令 | 补 AI Settings、Inspector、Show/Hide Panel | 一次可完成，符合 HIG |
| 字体随系统放大 | 提词面板 24–38；编辑器依赖系统显示缩放 | macOS 无 Dynamic Type；增加编辑器字号会扩大状态面，留到 2.1 |
| 无 Xcode 工程 | 保持 swiftc | 本机只有 CLT；写入 README 的分发限制 |

### 5.11 屏幕共享隐藏的产品决定

现状：`TeleprompterController` 设置 `sharingType = .none`，README 声称"共享时隐藏"。

事实：Apple 文档把 `.none` 标为 legacy，并明确要求不要用它隐藏内容。`screencapture` 可能遵守，但会议软件可能不遵守。

决定：

1. 代码保留该设置，作为"尽力而为"。
2. UI 文案改为 "Best-effort capture hiding"。
3. README 与 08 文档写明限制：不能保证在所有录制或共享工具中隐藏。
4. 不把"隐身"作为安全承诺。

后续可选方案：录制时降低面板不透明度、模糊正文，或提示用户使用系统级窗口共享选择。2.0 不做。

