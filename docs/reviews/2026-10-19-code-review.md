# Nook 2.0 代码审查报告

- 日期：2026-10-19
- 审查员：独立代码审查 agent（只读；未修改 Sources / Tests）
- 审查范围：`git diff ed46c95..HEAD -- Sources scripts` 与 `Tests`
- 基线提交：ed46c95（Nook 2.0 设计文稿提交）
- 实测提交：d29d3f3（构建、测试与主要阅读均在此提交完成）
- 重要过程说明：审查期间工作树被其他 agent 继续推进；结束时 HEAD 已变为 `887de25`，且 `Sources/Nook/Editor/EditorToolbar.swift` 存在未提交修改、新增 `Sources/Nook/Editor/PlanningActivityLine.swift`。本报告结论针对 `d29d3f3`；抽查 `887de25` 时 `AISettingsOverlay` 的 blocker 仍成立。发布前需在最终 HEAD 重跑质量门。

## 结论：blocked

发现 1 个真实功能 blocker：AI 设置面板在 AppModel 发布更新后可能变为不可见，同时编辑器仍被 `.allowsHitTesting(false)` 锁住，用户会看到“编辑器无响应、设置面板消失”。

## Blocker（1）

### B1. AI 设置面板的入场状态会随父视图刷新被重置，面板可“消失”且锁死编辑器

- 位置：`Sources/Nook/Editor/AISettingsOverlay.swift:10`、`:18-32`；`Sources/Nook/Editor/EditorView.swift:63-70`；触发路径 `Sources/Nook/Model/AISettingsModel.swift:141`、`:150-173`、`Sources/Nook/Model/AppModel.swift:319-322`。
- 根因：`AISettingsOverlay` 用 `@ObservedObject private var state = EntranceState()` 在视图内部创建观察对象。AISettingsOverlay 是 EditorView 的子视图；EditorView 观察 AppModel，任何 AppModel 的 `objectWillChange` 都会重新求值 EditorView.body，从而重新构造 AISettingsOverlay，并新建一个 `EntranceState`（`visible == false`）。SwiftUI 不会为这种内联 `@ObservedObject` 保留对象身份，`.onAppear` 也不会再次触发，于是 scrim 与卡片都以 opacity 0 渲染，但 `model.isAISettingsPresented` 仍为 true，EditorView 的 `.allowsHitTesting(!model.isAISettingsPresented)` 仍为 false。
- 可复现触发（普通用户路径）：
  1. 打开 AI 设置，已有 Keychain 密钥；点 “Clear key”。`clearKey()` 在非 local endpoint 时调用 `onChange?()`；AppModel 的 `invalidateAIPlan()` 无条件写多个 `@Published` 属性，必然发布更新。
  2. 或输入合法 endpoint/model 但暂不填 key，点 Save。`save()` 在返回 false（保留面板）前先调用 `onChange?()`（`AISettingsModel.swift:141`）。
  3. 或打开设置时后台 0.16 s 文档重建、AI 规划完成/失败、⌃⌥↑/↓ 改变 WPM 等任一 AppModel 更新。
  结果：面板不可见，编辑器不可点击；只能靠 Esc 或再次 ⌘, 尝试退出。
- 证据（独立 SwiftUI 探针，未改仓库）：在 /tmp/nook-review-probe/probe 中复刻“父视图观察 model + 子视图内联 @ObservedObject = EntranceState()”的结构。父 model 触发更新后输出：
  ```text
  OBS_INIT A
  CHILD_BODY state=A appeared=false
  CHILD_ONAPPEAR A
  CHILD_BODY state=A appeared=true
  --- TRIGGER ROOT UPDATE ---
  OBS_INIT B
  CHILD_BODY state=B appeared=false   // 新对象，onAppear 未再次触发
  ```
  同一模式还出现在 `InspectorPane`（见 N1）。
- 建议修复：把入场状态提升到稳定所有者（例如 `AppModel` / `EditorWindowController` 持有并注入，或复用 EditorView 根视图的 `EntranceState` 传入 overlay），不要在内联 `@ObservedObject` 初始化里创建状态；同时让 `AISettingsModel.save()` 只在确实要关闭面板时才触发 `onChange`，避免“保存失败但状态已失效”。
- 说明：受 2 分钟收尾要求限制，未完成真实 App 内“清空密钥后截图”的干净复现；上述结论由代码路径 + 同版本 SwiftUI 行为探针得出。建议修复后补一条 UI 自动化或截图回归。

## Non-blocking（5 条，按严重度排序）

### N1. Inspector 折叠状态在任意 AppModel 更新后丢失
- 位置：`Sources/Nook/Editor/InspectorPane.swift:18`（`@ObservedObject private var state = InspectorState()`）。
- 同一身份问题：折叠 Privacy/Pace 后，只要输入文字、拖 WPM、AI 状态变化，EditorView 重建 InspectorPane，新 `InspectorState` 回到“四个分区全展开”。不影响数据，但交互状态不稳定。

### N2. 菜单栏的屏幕共享文案仍在做过度承诺
- 位置：`Sources/Nook/App/MenuBarController.swift:89`：`item("屏幕共享时隐藏", ...)`。
- Inspector 已改为 “Best-effort capture hiding”，README 与 docs/08 也写明限制，但菜单栏这个最主要的入口仍写“屏幕共享时隐藏”。与设计文稿 5.11 的“UI 文案改为 Best-effort capture hiding”不一致。建议改为“尽力隐藏屏幕共享”并在 help 中说明限制。

### N3. “The key never leaves Keychain.” 与实现不符
- 位置：`Sources/Nook/Editor/AISettingsOverlay.swift:220`。
- `AppModel.prepareForStart` 会从 Keychain 读出 key（`AppModel.swift:220`），`OpenAICompatibleClient` 将其放入 `Authorization: Bearer` 请求头发往用户配置的 endpoint（`OpenAICompatibleClient.swift:91`）。Key 不落 UserDefaults/日志是对的，但“never leaves Keychain”字面为假。建议改为“仅存于 Keychain；Start 时只发送给此 endpoint”。

### N4. 连接测试的旧任务可覆盖新状态
- 位置：`Sources/Nook/Model/AISettingsModel.swift:195-211`。
- `testConnection()` 会 cancel 旧 `testTask`，但旧任务 catch 中无条件写 `testState = .failure(...)`；没有 generation / `Task.isCancelled` 保护。用户关掉再开、或连续点 Test，可能在新测试显示 testing 时被旧任务的 “Connection test cancelled.” 覆盖。建议在写入前检查取消或 generation，参考 `AppModel.prepareForStart` 的 generation 模式。

### N5. AI 缓存读写落在主线程
- 位置：`Sources/Nook/Model/AppModel.swift:19,240` + `Sources/NookKit/Planning/AIPlanningCoordinator.swift:89,107`。
- AppModel 现在 `@MainActor`，`Task { }` 继承 MainActor；`prepare` 在首个 await 前的 `cache.load` 和 await 后的 `cache.save` 都在主 actor 上做同步文件 I/O。当前缓存是单个小 JSON，影响有限；但长讲稿/慢磁盘时可能卡住输入。建议把缓存与解析移到 nonisolated/后台，或加一点异步边界。

## 已核对的行为保持（通过）

- 全局快捷键：`GlobalHotKeys.swift` 与基线完全一致；`HotKeyRouter` 只是安装/转发，动作枚举、Carbon 注册、hover 裸键逻辑未变。
- 悬停裸键：`TeleprompterController` 的 0.08 s hover timer、`panel.ignoresMouseEvents = true`、`onHoverChanged → GlobalHotKeyManager.setHoverActive` 链路保留。
- 鼠标穿透：面板仍 `ignoresMouseEvents = true`，仍为 `.nonactivatingPanel`，`canBecomeKey/Main = false`。
- 刘海定位：`targetWindowFrame()` / `screenForPrompter()` / 7 pt 顶距 / `PromptMetrics` 未变；`windowShadowMargin` 仍为 0。
- 屏幕共享隐藏：`sharingType = .none/.readOnly` 字段与 `forceVisibleInCapture` 环境变量保留；仅新增注释。文案问题见 N2。
- Keychain：`KeychainStore` 未改，service/account 未变；API key 仍只写 Keychain，未进入 UserDefaults、日志或仓库。
- UserDefaults key：`nook.script.v1`、`nook.wordsPerMinute.v1`、`nook.fontSize.v1`、`nook.cardWidth.v1`、`nook.hideFromCapture.v1` 与默认值（138/30/680/true）完全保留在 `PreferencesStore`。
- 缓存键：`PhrasePlan{,CacheKey}` 未改；prompt version 仍 6；AI 请求合约 `PhrasePlanningPrompt` / `OpenAICompatibleClient` 未改。
- Start 流程：⌘↩ → `EditorCoordinator.start()` → `AppModel.prepareForStart` 的 guard、本地回退、失败开编辑器、成功 hide editor + show panel + 恢复上一个 app 均保留；新增的 0.16 s hide 动画有 generation 保护。
- 菜单命令：AI 设置（⌘,）、打开编辑器（⌘E）、Inspector（⌥⌘I）、提词窗（⌥⌘H）、Start（⌘↩）以及编辑/窗口/关于均存在；状态栏/菜单栏的状态文案与 enable 条件保持。
- bundle id：`Resources/Info.plist` 与构建出的 `dist/Nook.app` 均为 `app.nook.teleprompter`；版本 2.0.0 (3)。安装只替换 .app，不触碰 Application Support/UserDefaults/Keychain。
- 架构：AppDelegate 131 行（≤180），AppModel 344 行（≤350）；`AISettingsModel`、`PreferencesStore`、菜单/HotKey/Preview 控制器拆分清晰；NookKit 未新增 UI 依赖（`PromptMetrics` 仍 import AppKit，基线即如此，属于已知偏差而非回归）。

## 质量门（在 d29d3f3 实测）

| 命令 | 结果 | 证据 |
| --- | --- | --- |
| `./scripts/build.sh` | exit 0，0 warning | /tmp/nook-build.log；“Built .../dist/Nook.app” |
| `./scripts/test.sh` | exit 0，PASS — 558 checks | /tmp/nook-test.log；≥ 550 目标，≥ 535 基线 |
| 禁用宏 | 无 `@State` / `@FocusState` / `@StateObject` / `@Observable` | rg/grep 全 Sources、Tests |
| 第三方依赖 | 无 Package.swift / Podfile / Cartfile；仅系统 framework（AppKit/SwiftUI/Combine/Carbon/NaturalLanguage/Security/CryptoKit/QuartzCore） | 文件树 + import 清单 |
| `git diff --stat ed46c95..HEAD`（开始时） | 42 files, +4038 −2194；核心文件见报告范围 | 审查开始时采集 |

注意：`887de25` 及未提交的 EditorToolbar 改动出现在实测之后；上面的 0 warning / 558 checks 不能直接当作最终 HEAD 的门禁结果，需重跑。

## 安全与隐私汇总

- 密钥泄漏路径：未发现新增写入 UserDefaults、日志、缓存或仓库的路径；`ai-debug.log` 仍只记录 host/model/reasoning/requested/prompt/completion 等元数据，不含原文与 key。
- 截图/预览：`--preview-sample` 使用隔离 suite 并每次清空，`PreviewSecretStore` 只在内存；生产启动仍用 `KeychainStore`。
- 文案：sharingType 的风险说明已进入 Inspector/README/docs，但菜单栏仍过度承诺（N2）；Keychain 文案不准确（N3）。

## 审查限制

- 未修改任何仓库文件；仅新增本报告。
- 未运行真实安装替换；按 bundle id 与 Info.plist 静态核对安装/数据保留。
- 未完成 5 个场景的完整视觉回归；仅用预览截图核对主界面与 AI 设置布局。
- 审查期间 HEAD 移动，最终版本需复验 B1 与质量门。

## 关键文件

- `Sources/Nook/Editor/AISettingsOverlay.swift`
- `Sources/Nook/Editor/EditorView.swift`
- `Sources/Nook/Editor/InspectorPane.swift`
- `Sources/Nook/App/MenuBarController.swift`
- `Sources/Nook/Model/AISettingsModel.swift`
- `Sources/Nook/Model/AppModel.swift`
- `Sources/NookKit/Planning/AIPlanningCoordinator.swift`
- `Sources/NookKit/Providers/OpenAICompatibleClient.swift`
- `Sources/Nook/App/AppDelegate.swift` / `EditorCoordinator.swift` / `HotKeyRouter.swift`
- `Tests/NookKitTests/`

## Scoped re-review — 2026-10-19（HEAD a4df8d2）

结论：pass-with-notes

范围：仅复验上次报告中的 B1、N1、N2、N3、N4；没有重做完整 diff 审查。

### 复验结果（5 项全部通过）

| 项 | 结果 | 证据 |
| --- | --- | --- |
| B1 AI 设置面板消失/锁编辑器 | 通过 | 内部入场状态已移除；AppModel 更新不影响面板可见性；预览实测通过 |
| N1 Inspector 折叠状态 | 通过（AppModel 更新维度） | InspectorState 已提升到 EditorView 根并注入 |
| N2 菜单栏屏幕共享文案 | 通过 | `MenuBarController.swift:89` = 「屏幕共享时尽力隐藏」 |
| N3 密钥文案 | 通过 | `AISettingsOverlay.swift:206` 已改为准确说明 |
| N4 testConnection generation | 通过（关闭/重开、连续 Test） | generation 自增 + success/catch 双守卫 |

**B1 细节**

- `AISettingsOverlay` 已删除内联 `@ObservedObject OverlayState`、`onAppear` 和 opacity/scale 入场状态（当前 `AISettingsOverlay.swift:6-17`）；入场由 `EditorView` 的条件插入 `.transition(.opacity.combined(with: .scale(scale: 0.985)))` 与 `.animation(..., value: model.isAISettingsPresented)` 驱动（`EditorView.swift:63-83`）。面板在 `isAISettingsPresented == true` 期间没有会被 AppModel 更新重置的内部状态。
- 真实 UI 验证：运行 `./dist/Nook.app/Contents/MacOS/Nook --preview-sample --preview-settings-update`（该 flag 在打开设置后 0.5 s 调用 `model.adjustSpeed(by: 5)`）。`/tmp/nook-final-settings-after-wpm.png` 显示设置卡片仍完整可见；状态栏与 Inspector 同时显示 143 WPM（138+5），证明 AppModel 更新已发生。编辑器在面板打开时仍被 dim 并阻止点击，这是模态的预期行为；面板可见，不再出现“面板不可见但编辑区被锁死”。
- 代码路径上未发现其他 AppModel 更新会隐藏该面板。

**N1 细节**

- `EditorView` 根持有 `@ObservedObject private var inspectorState = InspectorState()`，并调用 `InspectorPane(model: model, state: inspectorState)`（`EditorView.swift:7-8,34`）；`InspectorPane` 改为 `@ObservedObject var state: InspectorState`（`InspectorPane.swift:15-19`），不再在子视图内部创建。AppModel 更新只重算 EditorView.body，根上的 state 引用不变，折叠状态保留。

**N2 / N3 细节**

- `MenuBarController.swift:89`：`屏幕共享时尽力隐藏`。
- `AISettingsOverlay.swift:206`：`Stored in Keychain. Read only to sign requests to this endpoint.`。与“只在 Keychain 持久化、Start 时读出并作为 Bearer 请求头发给 endpoint”的实现一致。

**N4 细节**

- `AISettingsModel` 新增 `testGeneration`；`open()`、`close()`、`testConnection()` 均自增；success 与 catch 在写入 `testState` 前都检查 `generation == testGeneration`（`AISettingsModel.swift:49,85,98,198-218`）。上次报告的“关闭重开 / 连续点 Test 被旧结果覆盖”路径已修复。

### 质量门（a4df8d2 实测）

- `./scripts/build.sh`：exit 0，0 warning（log: `/tmp/nook-final-build.log`，“Built .../dist/Nook.app”）。
- `./scripts/test.sh`：exit 0，PASS — 558 checks（log: `/tmp/nook-final-test.log`）。
- HEAD 为 `a4df8d2`；审查未修改 Sources/Tests。结束时工作树有无关改动 `M docs/05-design-system.md` 与 `?? scripts/benchmark.sh`（其他 agent 的并行工作，不属于本次复验）。

### Non-blocking（3 条）

1. `AISettingsModel.save()` 没有 cancel 或自增 `testGeneration`；如果在 “Test connection” 请求进行中点击 Save，`save()` 会把 `testState` 置为 idle，但旧请求完成后仍可能写入 success/failure。只影响这个窄窗口；建议 save() 也取消 testTask 并 bump generation。
2. 自动测试未覆盖本次 N4 修复：Tests 中没有 AISettingsModel / testConnection 的纯逻辑检查（558 checks 与上次相同）。当前结论来自代码审查 + 预览 flag；建议补一条 generation 回归测试。
3. 上次报告的 N5（`AIPlanningCoordinator.prepare` 在 `AppModel` 的 MainActor Task 中同步执行 `cache.load/save`）不在本次 5 项修复范围内，代码未变；本次未复测其性能影响。

### 本次限制

- Inspector 折叠状态跨 AppModel 更新已确认；但 `EditorCoordinator.discardEditorWindow()` 在开始提词后释放编辑器窗口，重新打开会新建 EditorView 根，折叠状态会重置。这不是 AppModel 更新导致；如果需要跨窗口保持，可后续持久化。
- 未做真实 Keychain 写入/删除的 UI 操作；Keychain 路径按 `KeychainStore`（未变）静态核对。
- 预览实测只覆盖 WPM 更新这一种 AppModel 变更；其他更新路径由“overlay 无内部状态”的代码结构保证。
