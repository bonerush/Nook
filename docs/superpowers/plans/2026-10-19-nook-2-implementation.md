# Nook 2.0 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 本项目约定：实现由主代理完成，检查点由独立 subagent 审查。

**Goal:** 在不改变产品行为的前提下，重构 Nook 的代码结构，重做主界面视觉与动效，重建一小时可读的中文文档。

**Architecture:** 五层：DesignSystem / Presentation / Application controllers / Observable state / NookKit domain。AppDelegate 拆为菜单栏、菜单、快捷键、编辑器协调、预览五个控制器；AppModel 拆出 AISettingsModel 与 PreferencesStore；构建脚本递归收集源文件。

**Tech Stack:** Swift 5 语言模式、AppKit、SwiftUI、Combine、URLSession、Security、Carbon、NaturalLanguage、直接 swiftc。

**Spec:** docs/superpowers/specs/2026-10-19-nook-2-design.md

## Global Constraints

- 目标 macOS 14+。官方 glassEffect 只在 `if #available(macOS 26.0, *)` 内。
- 不引入 @State、@FocusState、@StateObject、@Observable 等宏属性包装器。
- 不新增第三方依赖；保持直接 swiftc 构建。
- API key 只存 Keychain；不得进入 UserDefaults、日志、缓存、截图、仓库。
- 保持 bundle id `app.nook.teleprompter`；安装替换不得清空用户数据。
- 保持全部快捷键、鼠标穿透、悬停裸键、菜单栏入口、屏幕共享隐藏设置（改为 best-effort 文案）。
- 不自动联网；只在 Start 时请求。
- 每个任务结束：`./scripts/test.sh` 通过、`./scripts/build.sh` 无新增警告、git 提交。
- 截图只用 `--preview-sample` 与隔离 UserDefaults。
- 审查必须由 subagent 完成。

## 文件地图

### 新建

- Sources/Nook/DesignSystem/NookTokens.swift
- Sources/Nook/DesignSystem/NookMotion.swift
- Sources/Nook/DesignSystem/NookComponents.swift
- Sources/Nook/DesignSystem/NookCanvas.swift
- Sources/Nook/Model/PreferencesStore.swift
- Sources/Nook/Model/AISettingsModel.swift
- Sources/Nook/Model/ScriptDocumentBuilder.swift
- Sources/Nook/App/MenuBarController.swift
- Sources/Nook/App/ApplicationMenuController.swift
- Sources/Nook/App/HotKeyRouter.swift
- Sources/Nook/App/EditorCoordinator.swift
- Sources/Nook/App/PreviewHarness.swift
- Sources/Nook/Editor/EditorToolbar.swift
- Sources/Nook/Editor/EditorStatusBar.swift
- Sources/Nook/Editor/PlanningErrorBanner.swift
- Sources/Nook/Editor/BreathRibbon.swift
- Sources/Nook/Editor/InspectorSections.swift
- Sources/Nook/Editor/PaceSegmentedControl.swift
- Tests/NookKitTests/PreferencesStoreTests.swift
- Tests/NookKitTests/ScriptDocumentBuilderTests.swift
- docs/*.md（Task 7）
- docs/assets/*.drawio + *.png（Task 8）
- scripts/check-docs.py（Task 8）

### 修改

- scripts/build.sh, scripts/test.sh（已完成递归收集）
- Sources/Nook/DesignSystem/NookDesign.swift（改名类型、加 tokens）
- Sources/Nook/Model/AppModel.swift（瘦身）
- Sources/Nook/App/AppDelegate.swift（瘦身）
- Sources/Nook/App/EditorWindowController.swift（新尺寸、入场、收起）
- Sources/Nook/Editor/EditorView.swift（新布局）
- Sources/Nook/Editor/ScriptPane.swift（纸张与空状态、节奏带）
- Sources/Nook/Editor/InspectorPane.swift（卡片与折叠）
- Sources/Nook/Editor/AISettingsOverlay.swift（重做）
- Sources/Nook/Teleprompter/TeleprompterController.swift（入场、nonactivating、reduce motion）
- Sources/Nook/Teleprompter/KaraokeLyricsView.swift（固定视图结构）
- Tests/NookKitTests/main.swift（注册新检查）
- README.md（重写）

### 删除

- Sources/Nook/DesignSystem/NookPrimitives.swift（内容并入 NookTokens / NookCanvas）
- Sources/Nook/Editor/EditorChrome.swift（拆为 Toolbar / StatusBar / Banner）
- Sources/Nook/App/GlobalHotKeys.swift（拆为 HotKeyRouter + 原 Carbon 代码保留在同文件？见 Task 4）

---

## Task 0: 基线

- [x] 记录 535 项检查通过。
- [x] 记录 1040×720、960×712、AI 设置截图（/tmp/nook-*.png）。
- [x] 设计文稿与调研报告落盘。

提交：

```bash
git add docs && git commit -m "docs: add Nook 2.0 design and research"
```

## Task 1: 模块目录与递归构建

- [x] `Sources/NookKit/{Core,Planning,Providers,Storage}`
- [x] `Sources/Nook/{App,Model,Editor,DesignSystem,Teleprompter}`
- [x] build.sh / test.sh 用 `find` 收集文件。
- [x] 全部测试通过，构建通过。

提交：`refactor: group sources by module`

## Task 2: 设计系统

**Files:** NookTokens.swift, NookMotion.swift, NookComponents.swift, NookCanvas.swift；删除 NookPrimitives.swift；重命名 Linear* 类型。

**Produces:**

```swift
enum NookColor {
    static let canvasTop: Color      // #F5F5F7
    static let canvasBottom: Color   // #FAFAFC
    static let paper: Color          // #FFFFFF
    static let surface: Color
    static let surfaceMuted: Color   // #F2F2F4
    static let border: Color         // #E5E5EA
    static let borderStrong: Color   // #D1D1D6
    static let textPrimary: Color    // #1D1D1F
    static let textSecondary: Color  // #515154
    static let textTertiary: Color   // #6E6E73
    static let accent: Color         // #007AFF
    static let accentPressed: Color  // #0063D1
    static let success, warning, danger: Color
}

enum NookType {
    static let display: Font = .system(size: 28, weight: .semibold)
    static let title: Font = .system(size: 17, weight: .semibold)
    static let body: Font = .system(size: 17, weight: .regular)
    static let callout: Font = .system(size: 13)
    static let caption: Font = .system(size: 11, weight: .medium)
    static func mono(_ size: CGFloat = 10.5) -> Font
}

enum NookSpace { static let xs, sm, md, lg, xl, xxl: CGFloat } // 4,8,12,16,20,24,32
enum NookRadius { static let control: 8, card: 12, paper: 20; static let capsule: CGFloat = 999 }
enum NookMetrics { static let toolbarHeight: CGFloat = 48; minWindow = CGSize(960, 680); defaultWindow = CGSize(1080, 740); inspectorWidth: CGFloat = 300; paperMaxWidth: CGFloat = 720 }

enum NookMotion {
    static let entrance = Animation.smooth(duration: 0.5)
    static let inspector = Animation.snappy(duration: 0.3)
    static let press = Animation.snappy(duration: 0.18)
    static let hover = Animation.smooth(duration: 0.16)
    static let counter = Animation.snappy(duration: 0.28)
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.01) : animation
    }
}
```

**组件：**

- `NookHairline`（0.5 pt）
- `NookSectionLabel`
- `NookChip`
- `NookKeycap`
- `NookCard`
- `NookPrimaryButtonStyle`、`NookSecondaryButtonStyle`、`NookIconButtonStyle`（按压 .snappy、scale 0.985）
- `NookCanvasBackground`（渐变）
- `NookWindowBackground`

**验收：** 旧类型名不再被引用；构建通过；截图与旧版一致（此任务只换 token，不改布局）。

提交：`refactor: replace Linear design tokens with Nook design system`

## Task 3: 状态层

**Files:** PreferencesStore.swift, AISettingsModel.swift, ScriptDocumentBuilder.swift, AppModel.swift, 新测试。

**PreferencesStore:**

```swift
struct PreferencesStore {
    enum Key { static let script = "nook.script.v1"; /* ... */ }
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard)
    func registerDefaults()
    var script: String { get set }
    var wordsPerMinute: Double { get set } // clamp 90...200
    var fontSize: Double { get set }        // clamp 24...38
    var cardWidth: Double { get set }       // clamp 600...860
    var hideFromCapture: Bool { get set }
}
```

**AISettingsModel:**

```swift
@MainActor
final class AISettingsModel: ObservableObject {
    @Published var baseURLDraft = ""
    @Published var modelDraft = ""
    @Published var presetDraft: LLMProviderPreset
    @Published var reasoningEnabledDraft = true
    @Published var effortDraft: LLMReasoningEffort
    @Published var keyDraft = ""
    @Published var isKeyVisible = false
    @Published private(set) var configuration: LLMConfiguration
    @Published private(set) var hasAPIKey = false
    @Published private(set) var keySuffix: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var testState: ConnectionTestState = .idle
    var canUseAI: Bool { configuration.isComplete && (hasAPIKey || configuration.isLocalEndpoint) }
    var onChange: (() -> Void)?
    func open(); func close(); func save(); func clearKey(); func testConnection(); func readKey() -> String?
}
```

**ScriptDocumentBuilder:**

```swift
struct ScriptDocumentBuilder {
    let options: PromptBuildOptions
    func build(script: SpeechScript, plan: PhrasePlan?) -> PromptDocument
}
```

**AppModel 瘦身后：**

- 保留：script, wordsPerMinute, fontSize, cardWidth, hideFromCapture, document, planSource, activePlan, planningState, planError, isAISettingsPresented
- 持有：`let aiSettings: AISettingsModel`、`let preferences: PreferencesStore`
- `canUseAI` 转发到 aiSettings。
- 设置保存后通过 `aiSettings.onChange` 失效 plan 并重建文档。

**测试（新增 ≥ 20 项）：**

- PreferencesStore：默认值、越界 clamp、写入后读回、脚本持久化。
- ScriptDocumentBuilder：空脚本 → empty；nil plan → local；有 plan → ai；WPM 影响时长。
- AISettingsModel：无效 URL 拒绝；缺少 key 的 local endpoint 可保存；保存后回调触发。

提交：`refactor: split settings and preferences out of AppModel`

## Task 4: 控制器拆分与菜单

**Files:** AppDelegate.swift（≤ 180 行）、MenuBarController.swift、ApplicationMenuController.swift、HotKeyRouter.swift、EditorCoordinator.swift、PreviewHarness.swift、TeleprompterController.swift。

**结构：**

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preview = PreviewHarness()
    private var model: AppModel!
    private var engine: PlaybackEngine!
    private var panel: TeleprompterController!
    private var editor: EditorCoordinator!
    private var menuBar: MenuBarController!
    private var hotKeys: HotKeyRouter!
    private var menus: ApplicationMenuController!
    // 只做组装、屏幕观察、退出清理
}
```

- `EditorCoordinator`：openEditor、hideEditor、start、startLocal、togglePlayback、navigate、restart、togglePanel、capturePreviousApp、reactivate。
- `MenuBarController`：status item、NSMenu、menuNeedsUpdate、图标与 tooltip。
- `ApplicationMenuController`：主菜单；新增 AI Settings…（⌘,）、Open Editor（⌘E）、View > Toggle Inspector（⌘⌥I）、Show/Hide Panel（⌘⌥H）。工具栏每一项都有菜单命令。
- `HotKeyRouter`：GlobalHotKeyManager 安装、hover、通知分发。
- `PreviewHarness`：`--preview-sample`、`--demo`、`--preview-ai-settings`、`--preview-compact`、`--preview-paused`、隔离 defaults、PreviewSecretStore、背景窗。
- `TeleprompterController`：`styleMask` 加 `.nonactivatingPanel`（如未设置）；入口动画尊重 Reduce Motion；订阅 `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`。

**验收：**

- 构建通过；应用启动、菜单、快捷键、开始流程可用。
- 无 `sharingType` 删改（保留，加注释与文案）。
- 截图：编辑器、AI 设置、提词面板。

提交：`refactor: split app delegate into controllers`

## Task 5: 主界面

**Files:** EditorView.swift、EditorToolbar.swift、ScriptPane.swift、BreathRibbon.swift、InspectorPane.swift、InspectorSections.swift、PaceSegmentedControl.swift、EditorStatusBar.swift、PlanningErrorBanner.swift、EditorWindowController.swift。

**布局：**

```swift
ZStack {
    NookCanvasBackground()
    VStack(spacing: 0) {
        EditorToolbar(...)
        HStack(alignment: .top, spacing: 20) {
            ScriptPaper(...)   // maxWidth 720, 居中
            if model.isInspectorVisible { InspectorPane(...).transition(.move(edge: .trailing).combined(with: .opacity)) }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        EditorStatusBar(...)
    }
}
```

**EditorToolbar：** 品牌（`text.line.first.and.arrowtriangle.forward` + "Nook"）、"Teleprompter" 副标、右侧 AI 状态胶囊、Inspector 切换、设置、Start。

**ScriptPaper：** 白色卡片；标题 "Script"（display）+ 元信息；TextEditor（17/lineSpacing 8）；空状态；BreathRibbon。

**BreathRibbon：** 每句一段，宽度按时长比例；hover 显示句子、时长；点击把焦点放到文本。数据变化 `.snappy(0.3)`。句子 > 120 时只显示总条。

**Inspector：** 4 个可折叠分区；Pace 用自定义分段控件（matchedGeometryEffect）；卡片样式。

**空状态：** 图标 + "Paste your script" + 说明 + "Load sample" 按钮；图标 2.8 s 浮动。

**EditorWindowController：** 默认 1080×740，最小 960×680；`hide(animated:)` 支持开始交接；`window.contentView` 背景透明或画布色。

**验收：** 960×680 与 1080×740 截图无裁切、无重叠；键盘焦点顺序正确；Reduce Motion 无位移。

提交：`feat: redesign editor with Quiet Studio layout and motion`

## Task 6: 设置、提词与细节

- AISettingsOverlay：material 卡片、分组、provider 分段、密钥显隐、错误行内提示、底部操作。
- TeleprompterController：入场 spring；Reduce Motion 时 fade；nonactivating；屏幕参数变化重定位。
- KaraokeWordView：固定视图结构（mask 始终存在，opacity 切换），避免 ForEach 视图数跳变。
- 屏幕共享文案："Best-effort capture hiding" + 说明。
- 检查 Focus ring、hover、按下反馈。

提交：`feat: polish settings sheet and teleprompter motion`

## Task 7: 文档

**Files:** README.md（重写）、docs/README.md、01–09、style-guide.md。

要求见 spec 第 6 节。每篇：目的、前置、正文、下一步。

- 01 产品与用户（含截图）
- 02 构建与第一次提词
- 03 术语与心智模型（图）
- 04 架构（分层图、数据流、开始时序、AI 状态机）
- 05 设计系统（颜色/字体/间距/动效表 + UI 标注图）
- 06 开发（加功能、测试、调试、发布）
- 07 AI 合约与缓存
- 08 故障排查（含屏幕共享限制）
- 09 代码地图
- style-guide（STE 等价规则 + 术语表）

提交：`docs: add one-hour handbook and rewrite README`

## Task 8: 图表与检查脚本

- draw.io 源文件 7 张：doc-map、architecture、data-flow、start-sequence、ai-state、ui-anatomy、build-pipeline。
- 导出 2× PNG 到 docs/assets，逐张用 read_image 检查文字不重叠。
- scripts/check-docs.py：
  - 句子长度（操作 ≤20 汉字、说明 ≤25）
  - 段落 ≤6 句
  - 术语变体（同义词黑名单）
  - 禁用词（进行/予以/加以 + 名词、分号）
  - Markdown 链接存在性
  - 图片 alt 与文件存在
  - 输出 0–100 分，<80 退出 1

提交：`docs: add diagrams and documentation checker`

## Task 9: 验证与审查

- `./scripts/test.sh`（≥550 项）
- `./scripts/build.sh`（无警告）
- 截图：1080×740、960×680、AI 设置、空状态、提词面板 READY/PAUSED。
- 手工检查：⌘↩ 开始、⌃⌥Space 暂停、悬停裸键、菜单命令、Keychain 保存。
- 独立审查 3 份：代码、UI、文档（新读者 10 题）。
- 修复 blocker，复验，安装到 /Applications，确认用户数据保留。
- 更新 Obsidian 记忆。

提交：`chore: verify Nook 2.0 and update install`
