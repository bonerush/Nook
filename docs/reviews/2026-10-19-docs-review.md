# Nook 文档审查报告（2026-10-19）

审查角色：独立技术文档审查员 + 第一次接触项目的新读者  
审查范围：`README.md`、`docs/README.md`、`docs/01`–`09`、`docs/style-guide.md`、`docs/assets/*.png`  
审查方式：只读审查；运行了 `./scripts/check-docs.py`、`./scripts/test.sh`、`./scripts/build.sh`；逐张查看 12 张 PNG；对照 Swift 源码核对事实。  
审查限制：未启动应用，未执行预览截图和 `NOOK_DEBUG_LAYOUT` 运行时命令；涉及运行时行为的推断已单独标注。

## 结论

**blocked**。文档主线和关键事实大多正确，但有一个“手把手修改并验证”的示例按文档执行会失败，且 10 个必查问题中有 2 个无法从文档回答；另有验收相关的不实陈述需要修正后才能作为可信的新读者入口。

## 验收结果

### 1. `./scripts/check-docs.py`

- 分数：**100.0/100**，阈值 80，退出码 0。
- sentences=726，long sentences=0，within-limit rate=100.0%。
- 12 个受检文件全部 `[OK]`。
- 重要限制：`docs/09-code-map.md` 仅统计到 **2 句**，因为脚本跳过表格；09 几乎全是表格，因此它的 `[OK]` 基本没有句长约束力。

### 2. 测试与构建

- `./scripts/test.sh`：**PASS — 558 checks**（退出码 0）。
- `./scripts/build.sh`：**Built …/dist/Nook.app**，编译 52 个 Swift 文件，退出码 0。
- 已核对：`Resources/Info.plist` 的 `CFBundleShortVersionString = 2.0.0`、`CFBundleIdentifier = app.nook.teleprompter`、`LSMinimumSystemVersion = 14.0`。
- README、04、06 中的“558 项检查”“版本 2.0.0”“bundle id”均属实。

## Comprehension 分数：7/10

| # | 问题 | 分数 | 判断依据 |
| --- | --- | --- | --- |
| 1 | Nook 为谁解决什么问题？ | 1 | 01 明确：英文自我介绍/面试/演讲/录像；解决“看镜头附近读稿”和“分手”问题。 |
| 2 | 一次 Start 经过哪些对象？ | 1 | 04 的 10 步和 start-sequence 图覆盖 EditorActions → EditorCoordinator → AppModel → AIPlanningCoordinator → 面板 → PlaybackEngine；但未说明 ⌘↩ 由 ApplicationMenuController 触发，而非 EditorToolbar。 |
| 3 | 为什么 AI 不能改写讲稿？ | 1 | 03 的“AI 返回行边界、显示文字来自本地词元”+07 的 schema 可回答；但 03 说“AI 收到词元编号”不准确，实际同时收到词元文本。 |
| 4 | 词元、断句计划、提词文档三者的关系？ | 1 | 03 数据流图和 03/04/07 的字段说明足够回答。 |
| 5 | 密钥存在哪里？日志会记录什么？ | 1 | 07/05/06 回答 Keychain；日志元数据、不含讲稿/密钥/响应正文。日志字段列表不完整（见 non-blocking）。 |
| 6 | 断句校验在哪两个文件？ | 0 | 07 和 09 只点名 `PhrasePlan.swift`。第二处校验实际在 `AIPlanningCoordinator.decodePlan`（解码/范围/调用校验器），且 `PromptComposer` 会再次校验；文档没有指出。新读者无法从文档回答“两个文件”。 |
| 7 | 如何改默认语速并验证？ | 0 | 06 的步骤可读，但验证步骤不成立：`PreferencesStoreTests` 断言默认值为 138 WPM，改 `registerDefaults` 必然使 `test.sh` 失败；且文档同页说旧值不会被覆盖，已有用户启动应用后也不会看到新值。 |
| 8 | 如何构建、测试、截图？ | 1 | 06 给出 build/test/截图步骤，命令均已存在；截图命令确实依赖 `--preview-sample`、`--demo`（面板截图部分未写清楚）。 |
| 9 | 面板位置如何计算？ | 0 | 文档只说“刘海下方”和“运行 NOOK_DEBUG_LAYOUT 看坐标”，没有说明计算方法。实际逻辑在 `TeleprompterController.targetWindowFrame()`：寻找有刘海/辅助区域屏幕，`menuBarInset = max(safeAreaInsets.top, frame.maxY - visibleFrame.maxY)`，`cardTop = frame.maxY - menuBarInset - 7`，卡片尺寸来自 `cardWidth` 与 `PromptMetrics.cardHeight`，窗口水平居中。文档没有这段解释。 |
| 10 | 屏幕共享隐藏为什么不能当安全承诺？ | 1 | 08“屏幕共享限制”和 06 的 `sharingType` 说明准确：旧接口、Apple 不建议、会议软件可能忽略、不能当安全保证。 |

**合计：7/10。** 第 6、7、9 题是内容/可执行性缺口；其余问题可有保留回答。

## Blockers

### B1. 06 的“修改默认语速并验证”示例按文档执行会失败

- 06 第 45–54 行要求改 `PreferencesStore.registerDefaults` 中的 `Key.wordsPerMinute: 138.0`，随后运行 `./scripts/test.sh` 并启动应用确认检查器显示新值。
- `Tests/NookKitTests/PreferencesStoreTests.swift:16` 断言 `Preferences default to 138 WPM`；把默认值改掉，测试会失败（不再是 558/558）。
- 同页第 54 行又说“已有用户的旧值不会被覆盖”，因此按 02 已经运行过 Nook 的读者，启动后看到的是旧的 138（或其他已保存值），不会看到新默认值。
- 这是文档唯一的“动手改一个小功能并验证”完整示例，直接影响 docs/README 的 60 分钟目标“修改一个小功能并验证”。修复需要同时更新测试、清理默认值或改用`--preview-sample` 隔离存储，并删掉“启动应用确认新值”的错误断言。

### B2. 必查问题 6（两个校验文件）没有文档答案

- 07 第 71 行只说“校验器在 `PhrasePlan.swift`”；09 的“断句怎么校验”也只给 `NookKit/Core/PhrasePlan.swift`。
- 实际第二处校验在 `Sources/NookKit/Planning/AIPlanningCoordinator.swift` 的 `decodePlan`：检查数组形状、start/end 范围和越界，然后调用 `PhrasePlanValidator`。`Sources/NookKit/Planning/PromptComposer.swift` 在合成前还会再校验一次。
- 新读者无法从文档回答“在哪两个文件”，也无法知道 AI 解码阶段的边界检查。建议在 07 的“校验与修复”明确两处，并在 09 增加 `AIPlanningCoordinator` 行。

### B3. 必查问题 9（面板位置计算）没有文档答案

- 01/05 只说“在刘海下方”，06/08 只给 `NOOK_DEBUG_LAYOUT=1` 命令，没有解释算法。
- 实际计算在 `Sources/Nook/Teleprompter/TeleprompterController.swift` 的 `targetWindowFrame()`：优先选有 `safeAreaInsets.top > 0` 且有 `auxiliaryTopLeftArea` 的屏幕，否则回退主屏；`menuBarInset = max(safeAreaInsets.top, screen.frame.maxY - visibleFrame.maxY)`；`cardTop = screen.frame.maxY - menuBarInset - 7`；窗口 `x` 居中，`y` 由卡片高度和边距推出。
- 06 第 101 行和 08 第 90 行的命令是 `NOOK_DEBUG_LAYOUT=1 … --preview-sample`；按代码阅读（未运行验证），调试输出只在 `show()` 或 `reposition()` 时打印，而 `--preview-sample` 单独启动只打开编辑窗口，不显示面板，因此该命令很可能没有输出。若要用它看面板坐标，应加 `--preview-start` 或 `--demo`，或在文档中说明先触发面板。

### B4. 07 对校验行为的描述自相矛盾且与实际不符

- 07 第 71–79 行说校验器“修复四类问题”，其中包括“越界的组”；同页“拒绝三类问题”又列出“编号越界”。
- `PhrasePlanValidator.validate` 对越界组直接返回 `.outOfBounds` 失败，不修复；实际修复的是编号缺口、跨句组和停顿范围（0–400 ms），越界/重叠/空计划是拒绝。
- 07 第 67 行“强调词最多三个”只是 prompt 指令；`PhrasePlanValidator` 只过滤非法 emphasis 索引，不截断到 3 个，因此该“规则”没有被校验器执行。
- 这属于校验/安全边界相关的不实陈述，需修正 07，避免读者以为越界输入会被自动修复。

## Non-blocking（最多 5 条）

1. **多处事实与代码不符。** 03 说“AI 收到词元编号”（实际请求包含 token 文本）；03 说提词文档每个词“四个字段”（`PromptWord` 有 6 个：id/text/start/end/lineIndex/sentenceIndex）；04 说 AI 状态“四个：idle/planning/failed/ready”（`AppModel.AIPlanningState` 只有 idle/planning/failed；ready 是 PlaybackEngine 相位/UI 状态）；04 说“其他对象不创建窗口和控制器”（`EditorCoordinator` 创建 `EditorWindowController`）；04 数据流说“ScriptDocumentBuilder 调用分词器”（分词在 `AppModel`，builder 调用规划器/合成器）。
2. **09 的行数和测试清单已过期。** `AISettingsOverlay.swift` 文档 498 / 实际 494；`NookTokens.swift` 98 / 94；`NookMotion.swift` 25 / 22；`NookComponents.swift` 207 / 175。09 的“测试目录”缺 `PhrasePlanningPromptTests.swift` 和 `PausePolicyTests.swift`。`docs/09-code-map.md` 的读者会按错误行数找文件。
3. **check-docs 的 100 分不能证明 STE 等价规则全部满足。** 脚本跳过表格（09 只数到 2 句）、不检查主动语态、不检查“一句一指令”、不检查图表标题/重叠；术语黑名单也不全。实际能举出的违规：03 术语表用“悬浮窗口”“主窗口”（正是被禁的同义词）；08 “打开编辑器”、09 “编辑器意图”使用被禁的“编辑器”；07 “词元文本被标记为不可信数据”、08 “面板是否被 ⌃⌥H 隐藏”等被动句；06 第 166 行“启动并确认讲稿和设置仍在”把两个动作写进一句。
4. **图片与 alt 文本有偏差。** `docs/README.md` 的 `doc-map.png` alt 写“文档地图：从中枢页到六篇主文档”，图中标题却是“60 分钟阅读路线”，是线性路线，不是中枢图；`ui-anatomy.png` 的 alt 只列“工具栏、纸张、呼吸图、检查器、状态栏”，漏了图中 ②“标题与统计”，且图底部说“编号对应 05 设计系统里的区域表”，但 05 的表没有编号、也没有 ②/④ 两行；`teleprompter-panel.png` 是紫色演示背景，文档未标注为演示场景，容易被误读为产品配色。所有被引用图片都存在、无文字重叠；`ai-settings.png`、`editor-empty.png`、`editor-compact.png` 未被任何文档引用，其中 compact 图最后一行被呼吸图区域裁切。
5. **命令和日志描述的细节不实。** 08 的 `cat "~/Library/Application Support/Nook/ai-debug.log"` 因引号包住 `~` 不会展开，按原样执行找不到文件；07 说“触发条件只有 Start / Retry AI”，但“Test connection”也会发请求；07 的缓存键写“七个字段”，`PhrasePlanCacheKey` 有 8 个存储值；07 的“讲稿 SHA-256”实际是对 token 文本用 U+001F 连接后的哈希；07 的 `tooLong` 实际限制是 `sourceText.count > 20_000` 个字符，不是 token 上限；06 的日志字段“只记录时间、host、model、预算和 token 数”也漏了 error code/description、reasoning 开关和字符数。另：05 说圆角“只有五个值”，`NookRadius` 有六个（`input = 9`）；05 说“不使用无限旋转加载器”，但 planning 状态使用系统 `ProgressView`；05 说“不动画 blur”，但 `KaraokeLyricsView` 的 blur/scale 会随 `active` 动画；“正文每行 64 到 72 个字符”与 editor-main 截图（首行约 81 字符）不符。

## 逐图检查结果

- `doc-map.png`：文字不重叠，路线可读；alt 不准确（见 N4）。
- `architecture.png`：五层、箭头、底部说明完整，可独立阅读。
- `data-flow.png`：讲稿 → 分词器 → 断句计划（AI/local 两支）→ 合成器 → 提词文档 → 面板；无重叠。
- `start-sequence.png`：用户/编辑器/协调器/AppModel/面板时序清楚；无重叠；“按 ⌘↩”归到“编辑器”一列，和实际菜单触发路径略有简化。
- `ai-state.png`：四状态图清楚；但 ready 不是 `AppModel` 的枚举状态，和 04 的“四个状态”是同一处不精确。
- `build-pipeline.png`：find → swiftc → 二进制 → plist/icon → codesign → dist；无重叠；实际还有 `chmod +x`，未画不影响理解。
- `ui-anatomy.png`：区域和编号清楚；编号与 05 区域表对不上（见 N4）。
- `teleprompter-panel.png`：面板、填色歌词、进度/时间可读；紫色演示背景未标注。
- `editor-main.png`：1080×740，浅色编辑器、检查器、呼吸图、状态栏可读；无重叠；与 05 的“64–72 字符”声明不符。
- `editor-empty.png`：空状态、禁用 Start 可读；未被文档引用。
- `editor-compact.png`：960×712（内容 960×680）可读；底部最后一行被呼吸图区域裁切；未被文档引用。
- `ai-settings.png`：AI 设置覆盖层可读；未被文档引用（02 的“配置 AI”本可引用它）。

## 事实核对清单

已核对为真：

- `README.md` 的“558 项检查”与 `test.sh` 实际输出一致。
- `README.md`、`style-guide.md` 的版本 2.0.0 与 Info.plist 一致。
- bundle id `app.nook.teleprompter`、macOS 14 最低版本、窗口最小 960×680、默认 1080×740、默认 WPM 138、字号 30、卡片宽 680 与代码一致。
- 快捷键 ⌘↩、⌃⌥Space、⌃⌥E、⌃⌥H、⌃⌥←/→、⌃⌥R、⌃⌥↑/↓、⌘, 在 `ApplicationMenuController`/`GlobalHotKeys` 中存在。
- 08 的数据位置、缓存路径、日志路径与代码一致；API key 只写 Keychain（`KeychainStore`+UserDefaults 仅存 LLM 配置）；日志不含讲稿/密钥/响应正文（`OpenAICompatibleClient` 只写元数据）。
- 09 绝大多数文件路径和行数正确；03/04/05 的颜色、字号、间距、动效数值大多与代码一致。

未验证项（不要当作已验证）：

- 未启动 `dist/Nook.app`，未执行预览截图、`run.sh` 或 `NOOK_DEBUG_LAYOUT` 命令；B3 中关于调试输出时机和 06 截图流程的判断来自源码阅读，未做运行时复现。
- 未实际修改默认语速跑一次 558 checks；B1 的结论来自 `PreferencesStoreTests.swift:16` 的断言与 `registerDefaults` 语义。
- 未测量真实的字符/对比度数值；“约 81 字符”为截图目测。

## 建议修复顺序

1. 修 06 默认语速示例：更新测试断言或改示例；把验证改为 `--preview-sample`/清空 defaults，并说明已有用户不覆盖默认值。
2. 在 07 和 09 写清第二处校验文件（`AIPlanningCoordinator`，并提 `PromptComposer` 复校验）。
3. 在 04/06 或 09 增加面板定位算法说明，修正 `NOOK_DEBUG_LAYOUT` 的触发命令。
4. 修 07 的“修复越界组”、强调词上限、缓存键/哈希/tooLong 等不实陈述。
5. 修 alt 文本、05 圆角/动画/字符数、08 的 `cat` 命令和日志字段；补 09 行数。

## 文件路径

- 报告：`docs/reviews/2026-10-19-docs-review.md`
- 关键文档：`README.md`、`docs/README.md`、`docs/01-what-is-nook.md` … `docs/09-code-map.md`、`docs/style-guide.md`
- 关键源码：`Sources/NookKit/Core/PhrasePlan.swift`、`Sources/NookKit/Planning/AIPlanningCoordinator.swift`、`Sources/NookKit/Planning/PromptComposer.swift`、`Sources/Nook/Teleprompter/TeleprompterController.swift`、`Tests/NookKitTests/PreferencesStoreTests.swift`

# Scoped 复验（HEAD a4df8d2，2026-10-19）

## 结论

**pass-with-notes**。上一轮 4 个 blocker 均已解决；本轮 comprehension **10/10**。

验收命令结果：

- `./scripts/check-docs.py`：**100.0/100**，800 句，0 长句，阈值 80，退出码 0。
- `./scripts/test.sh`：**PASS — 558 checks**，退出码 0。
- `NOOK_DEBUG_LAYOUT=1 ./dist/Nook.app/Contents/MacOS/Nook --preview-sample --preview-start`：运行后打印 `NOOK_LAYOUT screen=… cardTop=… windowFrame=… visible=true`；B3 的命令已可产生输出。
- 本轮未把 `./scripts/build.sh` 作为验收项；一次重建因工作区被并发修改（`AISettingsModel.swift` 在编译中变化）中断，不作为文档结论。

审查边界：复验期间工作区出现并发未提交改动（`AISettingsModel.swift`、`docs/05-design-system.md`、`docs/06-development.md`、`docs/reviews/2026-10-19-code-review.md`、`scripts/benchmark.sh`）。本结论以 `a4df8d2` 的提交内容为准；05/06 以 HEAD 版本核对，未把未提交内容计为修复或缺陷。

## 上一轮 blocker 的复验

| Blockers | 结果 | 证据 |
| --- | --- | --- |
| B1 06 默认语速示例不可执行 | **已解决** | 06 改为“修改 Natural 预设”：`PacePreset(id: "natural", title: "Natural", wpm: 138)` 改为 140；选择 Natural 调用 `model.setSpeed(140)`，步骤可执行。测试目标只编译 NookKit，不包含 InspectorPane，558 checks 仍通过。默认语速路径保留在“常见修改”表和注释中；该示例本身不再修改默认值。 |
| B2 两个校验文件未写清 | **已解决** | 07 明确三处：`PhrasePlan.swift`、`AIPlanningCoordinator.swift`、`PromptComposer.swift`；并说明 coordinator 负责解码/调用校验器/错误映射，composer 按真实字体宽度切分。 |
| B3 面板位置算法与调试命令 | **已解决** | 04 新增 7 步定位算法；06/08 命令均加 `--preview-start` 并说明“面板出现后才会打印”。运行时已打印 `NOOK_LAYOUT … visible=true`。 |
| B4 07 校验描述矛盾 | **已解决** | 07 改为“修复三类：编号缺口、跨句组、负数或超长停顿；拒绝三类：重叠、越界、空计划”，不再声称修复越界；强调词数量明确为 prompt 要求、校验器不强制。 |

## 10 题新读者测试

| # | 问题 | 分数 | 依据/备注 |
| --- | --- | --- | --- |
| 1 | Nook 为谁解决什么问题？ | 1 | 01 明确目标用户和三个需求。 |
| 2 | 一次 Start 经过哪些对象？ | 1 | 04 的 10 步与 start-sequence 覆盖 EditorActions/Coordinator/AppModel/Coordinator/面板/Engine；注意 04 第 2 步把 ⌘↩ 写成 EditorToolbar，实际键盘路径是 ApplicationMenuController（非阻塞）。 |
| 3 | 为什么 AI 不能改写讲稿？ | 1 | 03 已改“AI 收到词元编号和文本；只能返回编号”；07 说明显示文字来自本地词元。 |
| 4 | 词元、断句计划、提词文档三者关系？ | 1 | 03 数据流、字段和 04 数据流可回答。 |
| 5 | 密钥存在哪里？日志会记录什么？ | 1 | 05/06/07/08 一致：Keychain；日志元数据，不含讲稿/密钥/响应正文。 |
| 6 | 断句校验在哪两个文件？ | 1 | 07 明确三处，至少能回答两个；PhrasePlan + AIPlanningCoordinator（并提 PromptComposer）。 |
| 7 | 如何改默认语速并验证？ | 1 | 06 的“常见修改”指向 `PreferencesStore.registerDefaults`，注释说明要同步测试、旧值不覆盖；08 的 `defaults delete` 和 06 的预览隔离提供验证路径。逐步示例现在验证 Natural 预设，不是默认值（见非阻塞）。 |
| 8 | 如何构建、测试、截图？ | 1 | 06 的 build/test 命令存在且 test 通过；截图步骤完整；面板截图需 `--demo`（06 表格已列出，但截图段未强调）。 |
| 9 | 面板位置如何计算？ | 1 | 04 新增算法：找刘海屏、安全区/菜单栏取大、cardTop = 顶部 − 内缩 − 7、宽度居中、底部减卡片高度和边距；调试命令已运行验证。 |
| 10 | 屏幕共享隐藏为什么不能当安全承诺？ | 1 | 08/06 说明 sharingType 是旧接口、会议软件可能忽略、不能当安全保证。 |

**合计：10/10。**

## Non-blocking（本轮新增/残留，最多 5 条）

1. **02 的首次启动描述不实。** 02 第 57 行说“第一次启动时，稿纸是空的”；`PreferencesStore.registerDefaults` 默认写入 `SampleScript.interviewIntro`，首次启动实际显示示例讲稿。`editor-empty.png` 是 `--preview-empty` 场景，不是首次启动。应改为“启动后显示示例讲稿；可清空后粘贴”或把默认值改成空。
2. **08 的菜单标签与实际 UI 不一致。** 08 第 69 行让用户“选择打开编辑窗口”，`MenuBarController` 实际菜单是“打开编辑器…”。新读者按字面找不到该项。文档要么引用真实标签，要么同步改 UI。
3. **05 的性能/淡出描述仍有小偏差。** 24 Hz、当前行前后 3 行、50 ms 滑块合并、160 ms 文本合并、隐藏时停止时钟、释放编辑窗口均与代码一致；但“稿纸底部有 20 pt 淡出”没有 20 pt 常量（ScriptPaper 用的是编辑器区域 7% 的渐变遮罩），且“动画只改透明度和位移”仍与 `scaleEffect`/歌词行 blur 不完全一致。CPU/内存表未在本次复测（HEAD 值 75/45 MB），只能视为作者自测。
4. **03 术语表仍含被禁变体，且“计划只含编号”不精确。** 03 术语表写“刘海下方的提词窗口”，而 style-guide 禁止 panel 用“窗口”；“计划只包含词元的编号”仍忽略 pause、emphasis 和 source。check-docs 跳过表格，所以 100 分不覆盖这些行。
5. **04 的 Start 第 2 步仍有轻微路径错误。** “EditorToolbar 调用 EditorActions.start”适用于点按工具栏按钮；⌘↩ 实际由 ApplicationMenuController 的菜单命令触发。Q2 仍可回答，但读代码的人会发现差异。

## 图片复验

- 12 张 PNG 全部重新查看；没有文字重叠，图表可独立阅读。
- `doc-map.png` 的 alt 已改为“60 分钟阅读路线：六篇文档与时间分配”，与图一致。
- `ui-anatomy.png` 的 alt 已含 ①–⑥；05 的区域表已补 ② 标题与统计、④ 呼吸图，并含编号，图底“编号对应 05 区域表”现在成立。
- `editor-compact.png` 已更新；底部不再出现被裁切的半个字形，淡出表示还有内容；alt“960 宽窗口”与 960×712 外框、960×680 内容一致。
- `editor-empty.png`、`ai-settings.png` 已分别被 02 引用；`teleprompter-panel.png` 的紫色演示背景已在 01 用“演示背景是合成图”说明。
- 未发现新的 alt 缺失或图片链接错误；`ai-settings.png` 已显示“Stored in Keychain. Read only to sign requests to this endpoint.”，比旧文案更准确。

## 抽查非阻塞修复

- **03**：词元/提词文档“六个字段”、AI 收到编号和文本：已修正。
- **04**：AI 状态“界面四个、AppModel 存三个”、EditorCoordinator 按需创建 EditorWindowController、数据流中 AppModel 分词：已修正。
- **09**：不再记录行数；补 `PhrasePlanningPromptTests.swift`、`PausePolicyTests.swift`；新增 `PlanningActivityLine.swift`；`EditorActions` 改为“编辑窗口意图”。
- **08**：`cat "$HOME/Library/.../ai-debug.log"` 已修正；调试命令加 `--preview-start`；被动语态标题已改为主动表述。
- **07**：缓存键改为 8 个字段并说明 U+001F 哈希；`tooLong` 改为 20,000 字符；触发条件加入 Test connection；三处校验和 prompt/校验器的强调词区别已写清。
- **05**：圆角改为 6 个值并补 `input = 9`；字符数改为“约 75 到 82”；性能段补充 24 Hz、前后 3 行、50/160 ms、释放编辑窗口等代码可核对项；仍保留第 3 条 non-blocking 中的淡出/动画措辞问题。

## 复验限制

- 未重新截图；查看的是仓库中已更新的 PNG。
- 未实际修改 `PacePreset` 后启动 UI 验证 140；仅做源码路径与测试范围核对，`test.sh` 558 checks 通过。
- 未复测 CPU/内存表；未把一次被并发编辑打断的 build 作为结果。

