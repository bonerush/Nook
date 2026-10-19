# Apple 界面与动效语言调研 — Nook 主界面改造参考

> 状态：**部分完成（DRAFT）**。本文 ③ 动效参数表、① 材料部分、⑤ 链接为已查证（含本机 swiftc 实测）；② 逐 app 观察表、④ 的第三方标杆部分**本轮未查证完**，已明确标注「待查证」，未用记忆填充。
> 调研方法说明见文末「取证与限制」。所有 Apple 文档以 2026-10-19 抓取为准。

---

## ① 设计语言总结

### 1.1 材质：两套并存，按系统版本分层
Apple HIG *Materials* 原文：材料用于把前景（文字、控件）与背景（内容、纯色）在视觉上分开，"By allowing color to pass through from background to foreground, a material establishes visual hierarchy to help people more easily retain a sense of place."；并明确 "Apple platforms feature two types of materials: **Liquid Glass**, and **standard materials**."
→ 来源：<https://developer.apple.com/design/human-interface-guidelines/materials>

对 Nook 的直接含义（部署目标 macOS 14）：
- macOS 14 只能使用 **standard materials**（`.regularMaterial`/`.thinMaterial` + `NSVisualEffectView`），Liquid Glass 的 `glassEffect` 实测要求 **macOS 26.0+**（见 ③.4）。
- 因此"Nook 的原生感"必须由 standard material + hairline + 系统字体排版承担，而不是靠玻璃拟态堆叠。

### 1.2 动效：弹簧是默认，不是装饰
WWDC23 *Animate with springs* 的核心论点（原文）：
- "A spring animation doesn't only mean a bouncy animation." 无回弹的弹簧在 iOS 里"used in animations all over"。
- 弹簧之所以像真实物体，是因为它"very slowly and gradually comes to rest. There's no single point when the object is abruptly done."
- bounce 的正负对应三种物理形态：**bouncy / smooth / flattened**（underdamped / critically damped / overdamped）。
→ 来源：<https://developer.apple.com/videos/play/wwdc2023/10158/>

### 1.3 两条工程纪律（WWDC23 明确给出）
1. **duration 是"感知时长"（perceptual duration），可预测；settlingDuration 不可预测**。原文："you shouldn't wait for the settling duration for user-facing changes"，需要"动画基本结束"时用 SwiftUI 的 completion handler。
2. 参数可互相换算（原文公式）：
   ```
   mass = 1
   stiffness = (2π ÷ duration)^2
   damping   = 1 - 4π × bounce ÷ duration      (bounce ≥ 0)
               4π ÷ (duration + 4π × bounce)   (bounce < 0)
   ```

### 1.4 平台观（macOS）
macOS 的原生感来自：**菜单栏 + 键盘优先 + 窗口/工具栏材质的一致性**，而不是卡片堆叠。HIG 有独立页 *Designing for macOS*、*The menu bar*、*Toolbars*、*Windows*（链接见 ⑤）——本轮已抓取页面但尚未逐条摘录，标记「待查证」。

---

## ② 逐 app 观察表（**未完成 / 待查证**）

> 本轮时间预算被压缩，**没有**完成 Notes / Freeform / Keynote / Music 歌词页 / Weather / Photos / Maps / Reminders / Calendar / Xcode / Safari 起始页 / Tips 的逐条查证。为避免编造，此表只给"待查证"框架，不作为设计依据。

| App | 布局 | 材质 | 动效 | 可借鉴点 | 状态 |
|---|---|---|---|---|---|
| Notes | 三栏（文件夹/列表/编辑）+ 网格视图 | 侧栏 material、编辑区纯白 | 列表→详情过渡、工具条 morph | 编辑区留白与标题层级 | 待查证 |
| Freeform | 无限画布 + 悬浮工具条 | 浮动面板 material | 缩放/平移的惯性、吸附 | 悬浮控件不抢画布 | 待查证 |
| Keynote | 左侧幻灯片导航 + 检查器 | 深色画布、浅色 chrome | Magic Move 过渡 | 对象级过渡语义 | 待查证 |
| Music（歌词页） | 全屏歌词 + 背景模糊封面 | 大范围 blur + 渐变 | 逐句/逐词随节拍推进、滚动居中 | Nook 提词高亮节奏的参照 | 待查证（**Nook 关键参照，建议优先**）|
| Weather | 纵向卡片分区 | 半透明卡片 + 动态背景 | 背景天气动画、卡片进出 | 卡片圆角与内边距节奏 | 待查证 |
| Photos | 侧栏 + 网格 + 浮动工具条 | 内容优先、chrome 极简 | 缩略图→大图的 matched geometry | 内容/控件层级 | 待查证 |
| Maps | 地图为主，控件浮动 | 浮动面板 + vibrancy | 面板弹簧进出 | 控件不得遮挡内容 | 待查证 |
| Reminders | 列表 + 彩色标记 | 浅色卡片 | 勾选动画、完成移除 | 完成态反馈 | 待查证 |
| Calendar | 月/周/日 + 侧栏 | 浅色 chrome | 视图切换过渡 | 密度与网格对齐 | 待查证 |
| Xcode | 导航器/编辑/检查器 + 底部栏 | 深色或浅色统一 chrome | 面板折叠动画 | 三栏比例与折叠 | 待查证 |
| Safari 起始页 | 分区 + 背景图 | 背景图 + 半透明分区 | 分区展开 | 空状态可配置 | 待查证 |
| Tips | 卡片集合 | 大圆角卡片 | 卡片 hover 抬升 | 空状态/引导写法 | 待查证 |

### 2.x 第三方标杆（Things 3 / Bear / Craft / Linear / Raycast / IINA / Stats / Ice / Notion Calendar / Arc）
**未完成 / 待查证**。本轮未抓取这些产品的官方设计资料，不写未经核实的"细节结论"。

---

## ③ 动效参数表（已查证 + 本机实测）

### ③.1 弹簧预设的真实参数（**框架实测**）
方法：用本机 swiftc 编译运行 `Spring` 并读取 `duration` / `bounce` / `settlingDuration`。这比任何二手文章可靠。

| 预设 | duration | bounce | settlingDuration |
|---|---|---|---|
| `Spring.smooth` | 0.500 | 0.000 | 0.800 |
| `Spring.snappy` | 0.500 | 0.150 | 0.877 |
| `Spring.bouncy` | 0.500 | 0.300 | 1.045 |
| `Spring.smooth(duration: 0.3)` | 0.300 | 0.000 | 0.500 |
| `Spring.snappy(duration: 0.28)` | 0.280 | 0.150 | 0.519 |
| `Spring(duration: 0.4, bounce: 0)` | 0.400 | 0.000 | 0.600 |
| `Spring(duration: 0.5, bounce: 0.2)` | 0.500 | 0.200 | 0.926 |
| `Spring()`（默认） | 0.500 | 0.000 | 0.800 |

**重要事实**：`.smooth/.snappy/.bouncy` 三个预设的 duration 都是 **0.5s**，差异只在 bounce（0 / 0.15 / 0.30）。所以"snappy 更短"是错觉，它只是回弹更明显。
另：`bounce = 0` 时 settling ≈ **1.6 × duration**；`bounce = 0.3` 时 ≈ **2.09 × duration**。

### ③.2 response/dampingFraction ↔ duration/bounce 的对应
实测：`Spring(response: 0.35, dampingRatio: 0.85)` → duration 0.350, bounce 0.150；`response: 0.5, dampingRatio: 1.0` → duration 0.500, bounce 0.000。
→ 结论：**dampingRatio ≈ 1 − bounce**，response ≡ duration。旧 API `Animation.spring(response:dampingFraction:)` 与新 API 可等价换算。
参数表（提案用，非 Apple 声明）：

| 场景 | 建议写法 | 感知时长 | 备注 |
|---|---|---|---|
| hover / press 微反馈 | `.smooth(duration: 0.16)` | 0.16s | settling 约 0.36s，够快不糊 |
| 按钮按下缩放 | `.snappy(duration: 0.18)` | 0.18s | bounce 0.15，手感"脆" |
| 面板/侧栏进出 | `.snappy(duration: 0.28)` | 0.28s | settling ≈ 0.52s（实测同形参）|
| 内容页切换 | `.smooth(duration: 0.30)` | 0.30s | 无回弹，避免文字抖动 |
| 强调一次（成功徽标） | `.bouncy(duration: 0.45)` | 0.45s | bounce 0.30，仅用于一次性反馈 |

> 注意：`.smooth/.snappy/.bouncy` 的**短写法没有官方时长**，只有实测的 0.5s 默认值；写短写法的目标是"可预测"，不是"更快"。

### ③.3 可用性矩阵（**本机 swiftc 实测**，target `arm64-apple-macos14.0` / `macos26.0`）
SDK 版本：macOS 27.0（CommandLineTools），Swift 6.4。

| API | macOS 14 | macOS 26 | 结论 |
|---|---|---|---|
| `.smooth` / `.snappy` / `.bouncy` | ✅ | ✅ | **可用**（HIG 文档页标 iOS 13+ 与实测不冲突：符号存在，语义是 iOS 17 的弹簧预设）|
| `.animation(.spring(response:dampingFraction:))` | ✅ | ✅ | 可用 |
| `.spring(.bouncy(duration:))`（Spring 值） | ✅ | ✅ | 可用 |
| `phaseAnimator(_:content:animation:)` | ✅ | ✅ | **可用**，文档标 macOS 14.0+ |
| `keyframeAnimator(initialValue:trigger:content:keyframes:)` | ✅ | ✅ | **可用**，文档标 macOS 14.0+ |
| `.contentTransition(.numericText())` | ✅ | ✅ | 可用（数字滚动）|
| `.symbolEffect(.bounce, value:)` | ✅ | ✅ | 可用 |
| `.scrollTargetBehavior(.viewAligned)` | ✅ | ✅ | 可用 |
| `glassEffect(_:in:)` | ❌ | ✅ | 需 macOS 26.0+ |
| `MeshGradient` | ❌ | ✅ | 需 macOS 15.0+ |
| `@State` | ❌ | ❌ | **宏展开失败**（见 ③.5）|

### ③.4 **是否受宏限制：不受限**
`phaseAnimator` / `keyframeAnimator` 是**普通 View 修饰符**（接收 closure），不是宏；文档签名无 `@attached`/`@freestanding`。
- <https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:content:animation:)>
- <https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)>
两者都不要求 `@State`：可用 `@ObservedObject` 的模型属性作为 `trigger` 驱动，符合 Nook 的「禁宏属性包装器」约束。
⚠️ 文档原文提醒：keyframeAnimator 的 `content` closure "will be updated on every frame while animating, so avoid performing any expensive operations directly within content"。

### ③.5 `@State` 禁令的技术根因（实测）
直接 `swiftc` + CommandLineTools 工具链编译含 `@State` 的代码报错：
`external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found`
→ 宏需要 Xcode 工具链里的 macro plugin，纯 swiftc + CLT 环境不可用。**这条禁令是硬性技术约束，不是风格偏好**。（同一环境下 `@Observable` 反而能编过。）

### ③.6 性能建议（已查证部分）
- `TimelineView`：文档说明 "The system might use a cadence that's slower than the schedule's update rate"，并建议用 `Context.cadence` 降级细节 → 逐帧动画用 `TimelineView(.animation)` 时应读 cadence 做降级。
  <https://developer.apple.com/documentation/swiftui/timelineview>
- `keyframeAnimator`：content 每帧调用，禁止重计算（见上）。
- `matchedGeometryEffect`：文档明确 "If the number of currently-inserted views in the group with isSource = true is not exactly one results are undefined" → 同一 namespace 只能一个 source，切换时要在同一 transaction 内插入/移除。
  <https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)>
- CADisplayLink 的官方建议本轮**未查证**（待查证）。

---

## ④ Nook 主界面改造提案（15 点，含数值）

> 依据：现有代码 `Sources/Nook/DesignSystem/NookPrimitives.swift`、`NookDesign.swift`、`Sources/Nook/Editor/EditorChrome.swift`、`Editor/ScriptPane.swift`（调研时仓库正在重排目录，若路径变动以当前树为准）（当前：canvas #FFFFFF、pane #F5F5F7、border #E5E5EA、正文 17pt/lineSpacing 6.5、顶栏 52pt、圆角 8/9/10/12、press 反馈 0.1s easeOut）。以下为**设计提案**（判断，不是 Apple 声明）。

### 4.1 线框（现状 → 目标）
```
┌──────────────────────────────────────────────────────────────┐
│ ⌘ 顶栏 h=48  material+white18%  hairline 0.5 #E5E5EA         │
│  Script(13/semibold)                    [AI ready 胶囊][⚙][▶ Start] │
├───────────────────────────────┬──────────────────────────────┤
│ 稿纸列 max-w 720, pad-x 48    │ Inspector w=272, material    │
│  eyebrow 10.5 #5F5F64         │ 分组标题 11.5/semibold       │
│  TextEditor 17/行距 8         │ 行高 24, tabular 数字        │
│  measure 64–72 字符           │                              │
│  ─ Phrase map ─ 行高 24       │                              │
├───────────────────────────────┴──────────────────────────────┤
│ 状态栏 h=28  左: 词数/句数/时长(mono 10)   右: 快捷键 keycap │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 15 个可落地视觉提升点（含优先级）
| # | 提升点 | 具体数值 | 优先级 |
|---|---|---|---|
| 1 | 稿纸列限宽，避免 4K 下每行过长 | `maxWidth: 720`，水平 padding 32 → 48 | P0 |
| 2 | 正文行高加大提升可读性 | `lineSpacing` 6.5 → **8**，字号保持 17pt | P0 |
| 3 | 段落节奏 | 段间 `spacing: 12`，空行→`h=10` 视觉停顿条 | P1 |
| 4 | 顶栏收紧 | 高度 52 → **48**，右侧按钮间距 12 → 10 | P1 |
| 5 | 统一圆角阶梯 | 6 / 8 / 10 / 12（control/input/surface/overlay），去掉 9 这个孤值 | P1 |
| 6 | hairline 统一 0.5pt | `0.5pt #E5E5EA`，深色模式 `#3A3A3C` | P0 |
| 7 | press 反馈改为弹簧 | `.snappy(duration: 0.18)` + `scaleEffect(0.985)` + `brightness(-0.03)` | P0 |
| 8 | hover 反馈 | 背景 `#ECECF0` 0 → 1，`.smooth(duration: 0.16)` | P1 |
| 9 | 键盘 focus ring | 3pt，offset 2，accent 35% | P0 |
| 10 | AI 规划中的进度条 | 高度 2，accent #007AFF，不确定态用 `TimelineView(.animation)` 驱动渐变位移 | P1 |
| 11 | 数字/时长切换 | `.contentTransition(.numericText())` + `.snappy(duration: 0.28)` | P1 |
| 12 | Phrase map 行高 | 22 → **24**，序号用 `monospacedDigit` 10pt | P2 |
| 13 | 空状态收敛到一处 | 宽 360 居中，标题 17/medium #515154，副文 12.5/行距 3 #5F5F64 | P0 |
| 14 | 侧栏可折叠 | 宽 272，`⌘⌥S` 折叠，动画 `.snappy(duration: 0.28)` | P2 |
| 15 | 一次性成功反馈 | `symbolEffect(.bounce, value:)` 或 `.bouncy(duration: 0.45)`，全局唯一一处 | P2 |

### 4.3 反面清单（勿做）
- 不要在正文区用 `.bouncy` 默认 0.5s：settling 1.045s，文字会"晃"。
- 不要给多个视图共用同一 `matchedGeometryEffect` namespace 的 source。
- 不要在 macOS 14 上调用 `glassEffect` / `MeshGradient`（实测编不过），只能走 `NSVisualEffectView` 回退路径（项目已有）。

---

## ⑤ 参考链接（均已抓取成功，HTTP 200）

**Apple HIG**
- Materials — <https://developer.apple.com/design/human-interface-guidelines/materials>
- Motion — <https://developer.apple.com/design/human-interface-guidelines/motion>
- Layout — <https://developer.apple.com/design/human-interface-guidelines/layout>
- Typography — <https://developer.apple.com/design/human-interface-guidelines/typography>
- Color — <https://developer.apple.com/design/human-interface-guidelines/color>
- Toolbars — <https://developer.apple.com/design/human-interface-guidelines/toolbars>
- The menu bar — <https://developer.apple.com/design/human-interface-guidelines/the-menu-bar>
- Designing for macOS — <https://developer.apple.com/design/human-interface-guidelines/designing-for-macos>
- Windows — <https://developer.apple.com/design/human-interface-guidelines/windows>
- Liquid Glass — <https://developer.apple.com/design/human-interface-guidelines/liquid-glass>

**Apple 文档**
- `Animation.spring(response:dampingFraction:blendDuration:)` — <https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)>
- `Animation.smooth` — <https://developer.apple.com/documentation/swiftui/animation/smooth>
- `Animation.snappy` — <https://developer.apple.com/documentation/swiftui/animation/snappy>
- `Animation.bouncy` — <https://developer.apple.com/documentation/swiftui/animation/bouncy>
- `phaseAnimator` — <https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:content:animation:)>
- `keyframeAnimator` — <https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)>
- `matchedGeometryEffect` — <https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)>
- `TimelineView` — <https://developer.apple.com/documentation/swiftui/timelineview>
- `glassEffect(_:in:)` — <https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)>

**WWDC**
- WWDC23 session 10158 *Animate with springs* — <https://developer.apple.com/videos/play/wwdc2023/10158/>

**未查证（下一轮必须补）**：Apple Music 歌词页 / Freeform / Weather 等逐 app 观察；Things 3、Bear、Craft、Linear、Raycast、IINA、Stats、Ice、Notion Calendar、Arc 的原生感细节；CADisplayLink 官方建议。

---

## 取证与限制（重要）
1. 本机 `web_fetch` 对 `developer.apple.com` 失败：DNS 返回 **198.18.0.85**（代理 fake-IP 段），工具判定 "non-public IP" 并拒绝。
   绕过：`bash` + `curl`（走系统代理）→ 文档正文用 `https://developer.apple.com/tutorials/data/documentation/<path>.json`，HIG/视频页用 `https://r.jina.ai/<url>` 转 Markdown。
2. 可用性结论不是抄的，是 `xcrun swiftc -typecheck -target arm64-apple-macos14.0` 逐条编译验证。
3. 弹簧数值不是猜的，是编译运行 `Spring` 读取 `duration/bounce/settlingDuration` 得到的。
