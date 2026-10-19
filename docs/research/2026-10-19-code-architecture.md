# macOS SwiftUI + AppKit 代码架构与重构手法（Nook 场景）

> 状态：**部分完成**（按父代理要求 2 分钟内落盘）。已确认结论均给可点击 URL 或本机可复现命令；标「待补」者为尚未逐条查证的社区实践，不作定论。
> 调研日期：2026-10-19。查证环境：本机 /Library/Developer/CommandLineTools（无 Xcode），Swift 6.4，部署目标 macOS 14。

---

## ① 结论摘要

1. **分层比「框架」重要**：Apple 没有推荐 MVVM / Coordinator 这类具体架构；官方文档真正规范的是**数据流**（谁拥有模型、view 的 body 读了什么）与**互操作边界**（NSHostingView / NSViewRepresentable）。分层的收益必须落到「view body 少读状态」上，否则只是搬文件。
2. **Observation（@Observable）的官方收益正是 Nook 的痛点**：迁移文明确写——改用 Observation 后，视图**只在该 view 的 body 读取到的属性变化时**更新，而不是「该对象任意属性变化」都更新，从而改善性能；而 @ObservedObject 的语义就是「任一 @Published 变化 → 所有依赖该对象的视图更新」。Nook 把 20+ 个 @Published（含 AI 设置草稿）放在同一个 AppModel 里，正是官方指出的低效形态。
   - https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
   - https://developer.apple.com/documentation/swiftui/observedobject
3. **「无 Xcode 不能用宏」在当前工具链上不成立**：本机实测 @Observable（Observation 宏）**在纯 swiftc 下可展开、可运行**（见 ③ 命令）。因此项目「不用宏」是**团队约定**而非工具链限制；是否解除由用户决定。若维持约定，用「拆小 ObservableObject + 只读切片」等价达成「少读少刷新」。
4. **并发默认值建议显式声明**：Swift 6 语言模式默认 nonisolated；SE-0466（Swift 6.2 已实现）提供 -default-isolation MainActor，让整 module 默认主线程隔离，正好适合「UI 状态全在主线程」的菜单栏 App。本机 swiftc 已支持（-help-hidden 可见，实测可编译）。
   - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md
5. **动画正确性 = 谁以什么频率失效**：Nook 播放引擎以 **30 Hz Timer 每 tick 写 @Published elapsed**，导致整棵提词视图每 33 ms 重新求值。Apple 的 CADisplayLink（**macOS 14.0+**，恰等于部署目标）与 TimelineView（macOS 12+）才与刷新率同步；面板级出现/消失用 NSAnimationContext（官方定义：类似 CATransaction、可嵌套）。
6. **无 Xcode 的测试不止「手写 harness」**：@testable import 需要被导入模块以 -enable-testing 编译；本机实测「不开 → #ModuleNotTestable；开 + -I → 通过」。XCTest / Swift Testing 在本机不可用（no such module），故现有 TestHarness 路线正确。

---

## ② 推荐分层（mermaid，可直接贴入支持 mermaid 的渲染器）

    graph TD
      subgraph App["NookApp（可执行，@MainActor，仅装配）"]
        A1[AppDelegate / NSStatusItem]
        A2[WindowControllers: NSPanel + NSHostingView]
        A3[Composition Root: 构造并注入依赖]
      end
      subgraph UI["NookUI（SwiftUI 视图层）"]
        F1[TeleprompterFeature: KaraokeLyricsView / Rail]
        F2[EditorFeature: ScriptPane / Inspector]
        F3[AISettingsFeature: SettingsOverlay]
        F4[DesignSystem: NookMetrics / NookColor / Glass]
      end
      subgraph Kit["NookKit（纯逻辑，可单测）"]
        C1[Domain: PromptDocument / PhrasePlan]
        C2[Services: PromptScriptBuilder / HeuristicPlanner]
        C3[Repositories: PhrasePlanCache / ScriptStore]
        C4[Gateways: HTTPTransport / SecretStore-Keychain]
      end
      A3 --> UI
      A1 --> A3
      A2 --> UI
      UI --> Kit
      Kit --> C1

分层规则（依赖单向）：
- **Domain**：值类型 + 纯函数，不 import SwiftUI/AppKit。NookKit 已基本如此，但 PromptScript.swift 依赖 AppKit 字体测量，建议抽出 TextMeasuring 协议注入。
- **Service / Repository / Gateway**：以 protocol 定义端口，具体实现留外层。Nook 已有 HTTPTransport、PhrasePlanRemoteFetching、SecretStore 三个端口，模式正确，应扩到「时钟」「排版测量」「持久化」。
- **Feature**：一窗/一屏一目录，View + 该屏专属小 ViewModel（ObservableObject），**只依赖自己需要的状态切片**。
- **DesignSystem**：纯 token（间距/字号/圆角/材质）+ 少量原子组件，不承载业务判断。
- **Composition Root**：只出现在 App 层，构造器注入 + 默认参数，不用全局单例。
- **何时用 AppKit（官方边界）**：需要 NSPanel 非激活浮动窗、NSStatusItem 菜单栏项、NSVisualEffectView 材质、Carbon 全局热键、NSAnimationContext 面板动画时用 AppKit；桥接用 NSHostingView（macOS 10.15+）与 NSViewRepresentable。
  - https://developer.apple.com/documentation/swiftui/appkit-integration
  - https://developer.apple.com/documentation/swiftui/nshostingview
- **Coordinator / MVVM / VIPER**：均为社区模式，Apple 未推荐；本项目取「Feature + 小 ViewModel + 端口注入」即可，保持零第三方依赖。**待补**：社区文章逐条查证。

---

## ③ 关键 API 与模式清单（含平台可用性）

| 主题 | 结论（官方要点） | 可用性 | 来源 |
|---|---|---|---|
| Observation | 视图只随 body 读到的属性更新；可用 @State/@Environment 取代 @StateObject/@EnvironmentObject | macOS 14.0+ | 迁移文 / Observation |
| @ObservedObject | 任一 published 属性变化 → 更新所有依赖该对象的视图 | macOS 10.15+ | observedobject |
| @MainActor | executor 等价于主 dispatch queue 的全局 actor | macOS 10.15+ | mainactor |
| -default-isolation MainActor | 按 module 选择「默认单线程」；仅 MainActor / nonisolated 两值；缺省 nonisolated | Swift 6.2 | SE-0466 / SE-0316 |
| EquatableView / .equatable() | 新旧值相等时阻止子视图更新 | macOS 10.15+ | equatableview |
| ForEach | 每个元素应映射**常量个**视图才能获得最大性能；元素需 Identifiable 或显式 id | macOS 10.15+ | foreach |
| drawingGroup() | 先把子树合成到离屏位图；只含 SwiftUI 自行栅格化的内容（文本/图形/图片），CoreAnimation 合成的复杂内容不进入 | macOS 10.15+ | drawinggroup |
| Canvas | 立即模式绘制；不提供逐元素交互与无障碍；「对涉及动态数据的复杂绘制可能有更好性能」 | macOS 12.0+ | canvas |
| TimelineView | 按 schedule 重绘；系统可能给出比 schedule 更慢的 cadence | macOS 12.0+ | timelineview |
| CADisplayLink | 与屏幕刷新同步的定时器 | macOS **14.0**+ | cadisplaylink |
| withAnimation | 用给定 Animation 重算 body，本质是设置当前 Transaction 的 animation | macOS 10.15+ | withanimation |
| NSAnimationContext | 类似 CATransaction，可嵌套，控制 AppKit 动画时长/曲线 | macOS 10.5+ | nsanimationcontext |
| 菜单栏 App 设计 | HIG：用菜单栏提供全部命令；支持键盘快捷键 | — | HIG designing-for-macos |

本机实测（可复现，非记忆）：

    # 1) 无 Xcode 时 XCTest / Swift Testing 均不可用
    echo 'import XCTest'  | swiftc -typecheck -   # error: no such module 'XCTest'
    echo 'import Testing' | swiftc -typecheck -   # error: no such module 'Testing'

    # 2) @Observable 宏在纯 swiftc 下可用（target macOS 14；withObservationTracking 命中）
    swiftc -O -target arm64-apple-macosx14.0 ObsRun.swift -o obsrun && ./obsrun
    #   → observation-tracking fired: 1 / @Observable macro expansion works: true

    # 3) @testable 跨模块可用，但必须 -enable-testing（否则 #ModuleNotTestable）
    swiftc -emit-module -emit-library -module-name Foo -enable-testing Foo.swift -o libFoo.dylib
    swiftc -typecheck -I . TestFoo.swift

    # 4) 工具链支持默认主线程隔离
    swiftc -typecheck -default-isolation MainActor -target arm64-apple-macosx14.0 Plain.swift

**动画不阻塞打字的工程规则**（由上表 API 推出）：
1. 高频量（elapsed）不要放在会被整树读取的 @Published 里；拆出独立 PlaybackClock，只让歌词行/进度条这两个最小视图订阅。
2. 逐词高亮用 .animation(_, value:) 或 TimelineView/CADisplayLink 驱动；避免隐式 .animation(_:)（会把无关状态变化也纳入动画）。
3. 打字路径禁止整树重排：script 变更 → 防抖建文档 → 只发布 document，UI 侧用 Equatable / .equatable() 阻断无关子树。
4. 逐词视图里「if activeLine { 两层 Text+mask }」让元素对应视图数在 1/2 间跳变，与 ForEach 官方建议相悖；改为恒定结构 + mask/opacity 参数。
5. 面板级（NSPanel 出现/消失）用 NSAnimationContext（现实现已如此）；但 0.08 s 轮询 NSEvent.mouseLocation 的 hover 定时器建议换 NSTrackingArea 或本地事件监视器。

---

## ④ Nook 现状 → 目标架构 映射表

| 现状（文件/行数） | 问题 | 目标归属 |
|---|---|---|
| Sources/NookKit（19 文件 ~3.1k 行）：HTTPTransport / OpenAICompatibleClient / PhrasePlanCache / KeychainStore / AIPlanningCoordinator | 已是「端口 + 实现」结构；但与 Nook 仅靠**目录**区分 module，同一 swiftc 调用编译 | 保持为真实 module（-emit-module -enable-testing），或在测试脚本里以「先编译模块」获得边界与 @testable |
| NookKit/PromptScript.swift（756 行） | 领域建模 + 排版 + AppKit 字体测量混在一起 | Domain/PromptDocument + Layout/PromptLayoutEngine，字体测量抽 TextMeasuring 协议 |
| Nook/AppModel.swift（552 行，20+ @Published，含 aiXxxDraft 与会话测试状态） | 上帝对象：AI 设置草稿变化会刷新提词/编辑界面；didSet 里直接写 UserDefaults | 拆 ScriptSessionModel（script/document/WPM/font）、AISettingsModel（草稿 + 连接测试）、PreferencesStore（Repository 端口） |
| Nook/PlaybackEngine.swift（289 行，30 Hz Timer，@Published elapsed/currentWordIndex） | 每 tick 触发整棵提词视图求值；时钟与显示耦合 | PlaybackClock（CADisplayLink 或 TimelineView）+ PlaybackState（低频）+ 只读切片 |
| Nook/TeleprompterController.swift（323 行：NSPanel + NSHostingView + NSAnimationContext + hover 轮询） | 窗口控制与业务逻辑混在控制器；轮询 mouseLocation | TeleprompterWindowController（纯 AppKit 呈现）+ PresentationState；hover 改 NSTrackingArea |
| Nook/AppDelegate.swift（690 行：状态栏菜单、窗口装配、屏幕通知、预览背景窗） | 组合根 + 菜单构建 + 屏幕适配 + 若干 asyncAfter 时序补丁 | 拆 MenuBuilder / WindowFactory / ScreenObserver，移除非必要 asyncAfter |
| Nook/KaraokeLyricsView（151 行）/ LyricProgressRail / LinearDesign / OfficialGlassSurface | 设计 token 与视图耦合；activeLine 分支导致视图数变化 | 抽 DesignSystem（NookMetrics/NookColor/NookGlass）；视图保持常量结构 |
| Tests/NookKitTests（9 文件，TestHarness 43 行 + main.swift 断言脚本） | 本机无 XCTest / Swift Testing，全部同进程编译 | 保留 TestHarness；补 -enable-testing 模块化测试通道；加「黄金文件」快照 |

---

## ⑤ 分阶段重构路线（5k–10k 行 → 可测试 / 可维护）

原则：每步可编译、可运行、可回归；不改变行为的重构单独提交；先立测试再动结构。

- **Phase 0（0.5 天）基线固化**：记录 scripts/test.sh 的检查数（当前 500+）；补三类特征测试——(a) PromptDocument 序列化快照（存 Tests/Golden/），(b) PlaybackEngine 注入 now 闭包后的确定性时钟测试（替代 ProcessInfo.systemUptime），(c) 固定字体下的排版确定性断言。此阶段禁止改 UI。
- **Phase 1（1 天）抽时钟与端口**：PlaybackClock 协议（start/stop/tick(at:)）把 Timer 与 ProcessInfo 从 PlaybackEngine 剥离；DocumentLayoutMeasuring 协议包住 AppKit 文本测量。行为不变（仍 30 Hz，只换实现）。
- **Phase 2（1–2 天）拆 AppModel**：按「谁读它」切片——ScriptSessionModel（提词/编辑都读）、AISettingsModel（仅设置浮层读）。旧 AppModel 暂作门面转发，逐片迁移调用点，每片跑一次检查。
- **Phase 3（1 天）缩小失效半径**：逐词/逐行视图加 .equatable() 或把 elapsed 移出整树订阅；用 Instruments（SwiftUI）或 os_signpost 对比 Phase 0 的帧耗时。
- **Phase 4（1 天）显示层改为同步刷新率**：CADisplayLink（macOS 14+）或 TimelineView(.animation(minimumInterval:paused:)) 替换 30 Hz Timer；保持 isPlaying=false 时停驱动（不耗电）。
- **Phase 5（1–2 天）模块边界落地**：build.sh 改两步——先 swiftc -emit-module -enable-testing -emit-library Sources/NookKit/*.swift 产出 NookKit.swiftmodule，再编译 Sources/Nook/*.swift 并 -I/-L 链接；test.sh 用 @testable import NookKit。**架构守护**：NookKit 内出现 import AppKit 即失败（grep 检查）。
- **Phase 6（持续）DesignSystem 与 AppKit 边界**：token 归拢、NSPanel 控制器纯化、hover 换 NSTrackingArea、菜单/窗口装配抽 MenuBuilder / WindowFactory。

**行为不变的保证手段**：golden file 特征测试先行；每次只动一个维度（先替换实现、再调结构、最后改名）；检查数只增不减；对 PromptDocument 做「新旧实现同输入差分测试」（同进程同时调用两套实现并断言相等）。

说明：本节属工程推导，非 Apple 官方文本；可引用的 Apple 侧依据仅限 Observation 迁移文与 AppKit 集成文所表达的关注点分离/数据流思想。**待补**：Apple 对大规模 App 结构的明确表述、社区模块化文章。

---

## ⑥ 参考链接（均已实际抓取，非记忆）

Apple 文档与指南
- Observation 迁移（含性能收益表述）：https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
- Observation 框架：https://developer.apple.com/documentation/observation
- @ObservedObject：https://developer.apple.com/documentation/swiftui/observedobject
- 管理模型数据：https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- @MainActor：https://developer.apple.com/documentation/swift/mainactor
- AppKit 与 SwiftUI 集成（总览）：https://developer.apple.com/documentation/swiftui/appkit-integration
- NSHostingView：https://developer.apple.com/documentation/swiftui/nshostingview
- NSAnimationContext：https://developer.apple.com/documentation/appkit/nsanimationcontext
- EquatableView：https://developer.apple.com/documentation/swiftui/equatableview
- ForEach（元素→常量个视图）：https://developer.apple.com/documentation/swiftui/foreach
- drawingGroup(opaque:colorMode:)：https://developer.apple.com/documentation/swiftui/view/drawinggroup(opaque:colormode:)
- Canvas：https://developer.apple.com/documentation/swiftui/canvas
- TimelineView：https://developer.apple.com/documentation/swiftui/timelineview
- withAnimation(_:_:)：https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
- CADisplayLink（macOS 14.0+）：https://developer.apple.com/documentation/quartzcore/cadisplaylink
- Swift Testing（Swift 6.0 / Xcode 16；本机 CLT 无此模块）：https://developer.apple.com/documentation/testing
- HIG「Designing for macOS」：https://developer.apple.com/design/human-interface-guidelines/designing-for-macos

WWDC 会话（标题与摘要已抓取；逐句文字稿未取到，正文不改写其具体语句）
- Discover Observation in SwiftUI（WWDC23 10149）：https://developer.apple.com/videos/play/wwdc2023/10149/
- Demystify SwiftUI performance（WWDC23 10160）：https://developer.apple.com/videos/play/wwdc2023/10160/
- Demystify SwiftUI（WWDC21 10022：Identity / Lifetime / Dependencies）：https://developer.apple.com/videos/play/wwdc2021/10022/
- Eliminate data races using Swift Concurrency（WWDC22 110351）：https://developer.apple.com/videos/play/wwdc2022/110351/
- Discover concurrency in SwiftUI（WWDC21 10019）：https://developer.apple.com/videos/play/wwdc2021/10019/
- Integrating SwiftUI（WWDC19 231）：https://developer.apple.com/videos/play/wwdc2019/231/

Swift Evolution
- SE-0466 Control default actor isolation inference：https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md
- SE-0316 Global actors：https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md

### 待补（未完成清单）
1. WWDC 视频**逐句文字稿**未取得（Apple 页面 JS 异步加载，无公开 transcript JSON 端点）——正文未引用其具体语句，仅按标题/摘要定位。
2. 社区分层文章（Feature 模块、Coordinator、swift-snapshot-testing 等替代方案）尚未逐条抓取验证，故不给出其结论与链接。
3. Instruments / os_signpost 的具体模板名与 API 说明未抓取。
4. 「无 Xcode 快照测试」的可行性未实测（需确认离屏渲染与基线比对路径）。
