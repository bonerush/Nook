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
