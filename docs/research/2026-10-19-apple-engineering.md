# Apple 生态 macOS 应用工程标准与官方工程实践（Nook 参考）

- 调研时间：2026-10-19（Asia/Shanghai）
- 调研方式：直接抓取 Apple 官方 DocC JSON（`developer.apple.com/tutorials/data/...`）与 HIG 页面 JSON，逐条核对原文；WWDC 会话页逐条验证 `<title>` 是否 200。
- 抓取说明：本机 `web_fetch` 对 `developer.apple.com` 报 host-unresolvable（解析到非公网 IP），改用 `curl` 抓取成功；HIG 与 API 页面均为官方线上内容，引文为英文原文摘录。
- 完成度：① ② ⑤ 基本完成；③ 部分完成（官方页面描述部分）；④ 完成。**第 4 节"无 Xcode 工程"一节标注为「未查证/推断」，未拿官方 URL 的内容一律不写成结论。**

---

## ① 结论摘要

1. **HIG 对"悬浮面板"有明确取向**：panel 是"辅助于主窗口"的窗口（less prominent appearance），并且**应用不活跃时应隐藏所有 panel**；同时 HIG 承认 HUD 式面板（dark + translucent）存在，但要求"用例稀缺、保持小、少用颜色、不要和内容抢注意力"。提词器属于 HUD 场景，但"常驻不隐藏"是对 HIG 的**有意偏离**，应当有显式用户开关而不是默认行为。
2. **提词器窗口应走 `NSPanel` + `nonactivatingPanel` + `becomesKeyOnlyIfNeeded`**，这条在官方 API 文档里能逐字落地；`isFloatingPanel` 决定 floating level。是否会跟随全屏空间取决于 `NSWindow.CollectionBehavior`（`fullScreenAuxiliary` / `canJoinAllSpaces`）。
3. **"屏幕共享时隐藏窗口"不能用 `NSWindow.sharingType = .none`**：官方文档明说 `NSWindow.SharingType.none` 是 *"A legacy constant that macOS no longer uses"*，并且 **"Don't use this value to hide or omit content from being captured. Instead, use FairPlay Streaming (FPS)."** 这是本次调研对任务假设的**关键纠正**。
4. **macOS 不支持 Dynamic Type**：HIG Typography 明写 *"macOS doesn't support Dynamic Type."*。macOS 的正确做法是 text styles + dynamic system font variants + 用户可调的界面字号（HIG Accessibility 要求"至少能放大到 200%"）。
5. **Material 有语义，不是配色**：HIG 要求按语义选 material（`NSVisualEffectView.Material.sidebar/titlebar/menu/popover/hudWindow...`），并且 **inactive window 在系统层面不使用 materials** —— 自绘半透明背景会破坏系统给"非活动窗口"的视觉语义。
6. **菜单栏 app**：`NSStatusBar` 文档要求"status items 少用、必须提供隐藏它的用户偏好、不要假设它一定存在"；`MenuBarExtra` 文档要求纯菜单栏 app 设 `LSUIElement`，并给出 `isInserted:` 绑定让用户增删。HIG 另加一条：点菜单栏图标应**弹菜单，不是 popover**（除非功能复杂到菜单放不下）。
7. **菜单栏是 macOS 的"功能真源"**：HIG Toolbars（macOS）要求 **"Make every toolbar item available as a command in the menu bar."**，HIG The menu bar 要求 View / Window / Help 菜单齐全（View 管外观、Window 管窗口、二者不混）。
8. **动作与动画必须可关闭**：`accessibilityReduceMotion`（SwiftUI）与 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`（AppKit）是官方入口；订阅变化必须用 `NSWorkspace.shared.notificationCenter`（官方 Important 明确写了用错 notification center 收不到）。
9. **官方示例工程的组织亮点**：同一份代码通过 **target 变体**（Simple / All）承载不同签名与能力（Fruta、Food Truck）；跨平台用**单 target 多平台**（Food Truck）或**多 target**（Backyard Birds 有 watchOS target、widget）；数据用 SwiftData + Observation；示例页面**不谈测试**，测试组织需另找官方来源（见 §4 待补项）。
10. **Nook 现状与官方实践的差距集中在**：菜单栏完整性、panel 语义（抢焦点/常驻）、material 自绘、macOS 字号策略、Reduce Motion 覆盖、无障碍审计、以及"无 Xcode 工程"带来的签名/资源/测试限制。

---

## ② 官方规则清单（可执行）

### A. 窗口与 panel

- [ ] **区分 primary window 与 auxiliary window**；不要自绘窗口边框/按钮：*"Avoid making custom window frames or controls... Doing so without perfectly matching the system's look and behavior can make your app feel broken."*（[HIG Windows](https://developer.apple.com/design/human-interface-guidelines/windows)）
- [ ] **不要用"主窗口 / 关键窗口 / 非活动窗口"之外的自定义状态视觉**：inactive 窗口系统会去掉 material 使其"retreat"。
- [ ] panel 用在"与当前窗口/选区相关的补充控制"，并在 app 激活时把 panel 提到前面、**app 不活跃时隐藏所有 panel**（[HIG Panels](https://developer.apple.com/design/human-interface-guidelines/panels)）。
- [ ] panel 给**短标题**（名词或 title-style capitalization 名词短语），菜单里用 `Show Inspector` 这类写法，不要在 UI 里出现 "panel" 字样。
- [ ] **panel 一般不提供 minimize 按钮**；panel 不进 Window 菜单的窗口列表。
- [ ] HUD 式面板只在"媒体/演示类、标准 panel 会遮挡内容"时使用；**保持小、少用彩色、全模式只维持一种 panel 风格**。
- [ ] 不要自绘 toolbar 背景：*"Reduce the use of toolbar backgrounds and tinted controls."*（[HIG Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)）
- [ ] macOS **不要把控件/关键信息放在窗口底部**（窗口常被拖到屏幕下缘）；**不要在图窗顶部 camera housing 区域放内容**（[HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout)）。
- [ ] 全屏用系统能力（`toggleFullScreen(_:)`），不要自己改 display mode；"Always let people choose when to enter full-screen mode."；*"Using the system's full-screen support automatically accommodates this area [camera housing]"*（[HIG Going full screen](https://developer.apple.com/design/human-interface-guidelines/going-full-screen)）。

**API 落地**

- `NSPanel`：`isFloatingPanel`、`becomesKeyOnlyIfNeeded`、`worksWhenModal`（[NSPanel](https://developer.apple.com/documentation/appkit/nspanel)）
- `styleMask` 含 `.nonactivatingPanel`："The window is a panel or a subclass of NSPanel that does not activate the owning app."（[nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)）
- `window.level`：floating 窗口在所有 normal level 之前（[level](https://developer.apple.com/documentation/appkit/nswindow/level-swift.property)）
- `collectionBehavior`：`.canJoinAllSpaces`（"The window can appear in all spaces."，文档补一句 *"The menu bar behaves this way."*）、`.fullScreenAuxiliary`（"The window displays on the same space as the full screen window."）（[canJoinAllSpaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)、[fullScreenAuxiliary](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary)）
- 鼠标穿透：`ignoresMouseEvents`（"whether the window is transparent to mouse events"）（[ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)）

### B. 菜单栏与 menu bar extra

- [ ] 菜单顺序：**AppName / File / Edit / Format / View / 自定义菜单 / Window / Help**；Apple 菜单在最前、menu bar extras 在尾部（[HIG The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)）。
- [ ] 菜单项"永远显示、不可用时置灰"，不要隐藏；用系统标准图标与标准快捷键。
- [ ] **自定义命令必须进菜单栏**，理由官方给了三条：好找、可配快捷键、**对使用 Full Keyboard Access 的人可访问**。
- [ ] View 菜单只管外观（Show/Hide Toolbar、Enter/Exit Full Screen），标题要反映当前状态；Window 菜单提供 Minimize / Zoom（即使只有一个窗口）。
- [ ] **每个 toolbar item 都要有对应菜单命令**（可被隐藏/自定义，不能是唯一入口）。
- [ ] 菜单栏图标用 **template 图**（黑+透明，系统配色适配明暗与选中态）；菜单栏高度 **24 pt**。
- [ ] 点菜单栏图标**给菜单，不给 popover**；*"Let people — not your app — decide whether to put your menu bar extra in the menu bar."*
- [ ] 不要依赖 menu bar extra 一定存在（系统会因空间不足隐藏它）；额外提供 Dock menu 等第二入口（[HIG Dock menus](https://developer.apple.com/design/human-interface-guidelines/dock-menus)）。
- [ ] **必须提供隐藏 status item 的用户偏好**：*"status items are not guaranteed to be available at all times... always provide a user preference for hiding your application's status items"*（[NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)）。
- [ ] 纯菜单栏 app 在 Info.plist 设 **`LSUIElement = true`**（不进 Dock / App Switcher）；被用户移除 extra 后系统会终止该 app（[MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)）。
- [ ] 需要富内容时用 `MenuBarExtra(...).menuBarExtraStyle(.window)`，官方描述为 "a popover-like window ... that contains standard controls"。

### C. 字体、字号、配色、材质

- [ ] **macOS 走 text styles 与 dynamic system font variants，不要假设 Dynamic Type**（HIG Typography：*"macOS doesn't support Dynamic Type."*）（[HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography)）。
- [ ] 不用 Ultralight/Thin/Light 作为界面正文；层次靠 weight/尺寸/颜色而非换字族。
- [ ] **不要内嵌系统字体**（"don't embed system fonts in your app"）。
- [ ] 对比度：WCAG AA 至少 **4.5:1**；小字与自定义前景色目标 **7:1**；暗色与浅色两套都要测（[HIG Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)）。
- [ ] **不要提供 app 级明暗外观开关**：*"Avoid offering an app-specific appearance setting."* 例外是沉浸式媒体类 app 可固定深色外观。
- [ ] 优先语义色（`labelColor`/`separator`/`controlColor`），避免硬编码 RGB。
- [ ] **Liquid Glass 不用于 content layer**；只用于控件/导航层，且"use sparingly"；`clear` 变体只用于覆盖"视觉丰富背景"的组件（例如文字压在亮背景上时加 35% 暗色 dimming）（[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)）。
- [ ] **按语义选 material**，不要按"看起来什么颜色"选：`.sidebar` 用于侧栏背景、`.hudWindow` 用于 HUD、`.titlebar`/`.menu`/`.popover` 各归其位（[NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview)、[Material](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material-swift.enum)）。
- [ ] blendingMode 二选一：**behind-window**（sheets/popovers，整个窗口浮起）vs **in-window**（scrolling content 下的工具栏、toolbar 一律用 in-window）。

### D. 可访问性、Reduce Motion、键盘、VoiceOver

- [ ] **文字至少可放大到 200%**（watchOS 140%）；用自定义 UI 或 Dynamic Type 实现（[HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)）。
- [ ] 控件间距：带 bezel 元素周围约 **12 pt**，无 bezel 约 **24 pt**；不要用复杂多指手势作为核心路径，且必须给非手势替代。
- [ ] **Reduce Motion 生效时**：减少自动/重复动画（缩放、位移、周边运动）；官方给的四个具体手法是——收紧紧弹簧减少回弹、动画直接跟随手势、**不要在 z 轴做深度动画**、**把 x/y/z 位移换成 fade**、**不要在进出 blur 上做动画**。
- [ ] 不要用"定时自动消失"的 UI（time-boxed），改显式关闭。
- [ ] 键盘：支持 Full Keyboard Access，不覆盖系统快捷键，所有核心动作有菜单命令（这一点与 §B 的规则是同一条链）。
- [ ] VoiceOver：为界面与内容提供描述；重要信息不能只靠颜色，也不能只靠视觉。
- [ ] 用 **Accessibility Inspector** 做审计（HIG 明确推荐）。

**API 落地**

- SwiftUI：`@Environment(\.accessibilityReduceMotion)`，文档说明 *"If this property's value is true, UI should avoid large animations, especially those that simulate the third dimension."*（[accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)）
- AppKit：`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`，*"avoid large animations, especially those that simulate the third dimension"*（[accessibilityDisplayShouldReduceMotion](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)）
- 变化通知：`NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`，**必须注册到 `NSWorkspace.shared.notificationCenter`**，否则收不到；Swift concurrency 用 `NSWorkspace.AccessibilityDisplayOptionsDidChangeMessage`（[通知文档](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayoptionsdidchangenotification)）

### E. 官方设计语汇（2025 之后）

- Liquid Glass 是"控件与导航层"的动态材质，**regular** 变体（模糊+亮度）用于正文/侧栏/弹窗，**clear** 变体用于浮动在媒体之上的元素（[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)）。
- 系统组件自动获得该材质；自定义控件"do so sparingly"，且只给最重要的功能元素。
- 参考会话：[Meet Liquid Glass (WWDC25/219)](https://developer.apple.com/videos/play/wwdc2025/219/)、[Get to know the new design system (WWDC25/356)](https://developer.apple.com/videos/play/wwdc2025/356/)、[Build an AppKit app with the new design (WWDC25/310)](https://developer.apple.com/videos/play/wwdc2025/310/)、[What's new in SwiftUI (WWDC25/256)](https://developer.apple.com/videos/play/wwdc2025/256/)（四条均已验证 URL 可访问且标题匹配）。

---

## ③ 示例代码 / 开源项目结构对比

| 项目 | 官方页面要点（可引用） | 工程组织方式 | 状态管理 / 数据 | 测试 |
|---|---|---|---|---|
| **Landmarks**（Liquid Glass 版） | 单 target 跑 iPhone/iPad/Mac；`NavigationSplitView` 组织导航；演示 background extension effect、横向滚动延伸到 sidebar/inspector 之下、toolbar 的 Liquid Glass、自定义 glass 元素与动画、Icon Composer 图标、窗口尺寸变化与全局搜索（[页面](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)） | 官方教程/示例工程（Xcode project） | SwiftUI 状态 + 视图内聚，未在页面描述持久层 | 页面未描述 |
| **Fruta** | 一套共享代码做 macOS/iOS/iPadOS；**两种 target 风味**：Simple（Personal Team 可跑）与 **All**（widget extension + App Clip + Sign in with Apple + PassKit）；`@main struct FrutaApp: App` + `WindowGroup` + `.commands { SidebarCommands(); SmoothieCommands(model:) }`；用 `@StateObject private var model` 注入 `environmentObject`（[页面](https://developer.apple.com/documentation/appclip/fruta-building-a-feature-rich-app-with-swiftui)） | **按能力拆分 target**（simple/all），共享源码 | `ObservableObject` + `@StateObject`/`environmentObject`（老式 MVVM 风格） | 页面未描述 |
| **Backyard Birds** | SwiftData + Observation；widget 用 App Intents；StoreKit 的 `ProductView`/`SubscriptionStoreView`；**multiplatform target + 独立 watchOS target + widget**，需要为各 target 配置 `Store.storekit` scheme（[页面](https://developer.apple.com/documentation/swiftui/backyard-birds-sample)，[官方仓库](https://github.com/apple/sample-backyard-birds)） | **多 target / 多平台模块**，StoreKit 配置文件随仓库走 | `@Model` 持久模型 + `@Attribute(.unique)` + `@Relationship`；Observation 驱动 SwiftUI | 页面未描述 |
| **Food Truck** | "Create a single codebase and app target for Mac, iPad, and iPhone"；`NavigationSplitView` + `Layout` + Swift Charts + WeatherService；Live Activities（ActivityKit / DynamicIsland）；同样区分 **Simple target 与 Food Truck All target**（passkeys 等能力）（[页面](https://developer.apple.com/documentation/swiftui/food-truck-building-a-swiftui-multiplatform-app)） | **单 target 多平台** + 能力型 target 变体 | SwiftUI 状态 + 服务对象（WeatherService 等） | 页面未描述 |
| **Wi‑Fi Aware 示例** | 点对点 Wi‑Fi Aware：publisher/subscriber 模拟；**必须真机**（Simulator 跑不了）；能力靠 entitlement `com.apple.developer.wifi-aware`（Publish/Subscribe），服务在 Info.plist 声明（`_udp` 服务 + Publishable/Subscribable）（[页面](https://developer.apple.com/documentation/wifiaware/building-peer-to-peer-apps)） | Xcode project + entitlements + Info.plist 声明 | 框架回调驱动，非状态框架演示 | 页面未描述 |
| **Nook（本项目）** | 自建：`Sources/Nook`（AppKit/SwiftUI UI 层，16 文件）+ `Sources/NookKit`（纯逻辑，15 文件，6255 行总量） | **手写双模块**（UI / Kit），无 Xcode 工程，`scripts/build.sh` 直接 `swiftc -parse-as-library -O -whole-module-optimization` 一次性编译全部源码 | 手写 `AppModel`（无 `@State` 等宏） | 自建 harness：`Tests/NookKitTests/*` 用 `swiftc` 编成可执行文件跑断言（非 XCTest） |

**对比结论（只做结构性，不评价美观）**

1. 官方示例的"模块切分"主要靠 **target / package 边界 + 目录**，而不是靠运行时分层；Nook 的 `Nook`/`NookKit` 双模块与 `BackyardBirdsData`/`BackyardBirdsUI` 这类官方切法方向一致，属于可接受结构。
2. 官方示例把"**能力变体**"做成不同 target（Simple / All），Nook 目前只有单一产物，能力（AI Keychain、玻璃效果）靠运行期判断——这在无 Xcode 时是合理妥协，但应在 README 明示"没有 entitlements，故不用 App Sandbox / 不使用需要签名的能力"。
3. 官方示例页面**均不描述测试组织**（已逐页确认 Fruta / Food Truck / Backyard Birds / Landmarks / Wi‑Fi Aware 五个页面无 test 段落）；因此"官方测试范式"无法从示例页引用，见 §4 待补。

---

## ④ 对 Nook 的 10 条具体改造建议（按优先级）

> 判定标准：先"语义正确/不误导用户"，再"可访问性"，再"工程可持续"，最后"观感"。每条给出官方依据与验收方式。

1. **P0｜屏幕共享隐藏：删掉/退役 `sharingType = .none` 路线。**
   官方明确 `.none` 是 legacy 且 macOS 不再使用，并点名"不要用它把内容从录制里隐去，应该用 FairPlay Streaming"。Nook 若当前依赖它做"共享时隐身"，属于**功能假象**。验收：代码中无 `sharingType = .none`；改为"共享时降低不透明度/模糊正文"等显式产品方案，或在文档里删除该承诺。（[依据](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none)）

2. **P0｜提词窗改为真 `NSPanel` 语义：`.nonactivatingPanel` + `becomesKeyOnlyIfNeeded`。**
   目标：点提词窗不抢前台 app、不打断 Space 切换、不触发 app 激活副作用。若必须能输入/选择，再局部让 panel 成为 key。验收：前台是 Safari 时点提词窗，Safari 菜单栏标题不变；连续点击不产生 Space 切换动画。（[依据](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)、[NSPanel](https://developer.apple.com/documentation/appkit/nspanel)）

3. **P0｜常驻可见 vs HIG「app 不活跃时隐藏 panel」的书面取舍。**
   HIG 对 panel 的要求是"激活时前置、非激活时隐藏"。提词器是 HUD 场景，可以偏离，但**必须写成产品决定**并给用户开关（"随前台应用隐藏 / 始终置顶"）。验收：设置里有该开关，默认值在 README/ADR 里写明理由。（[依据](https://developer.apple.com/design/human-interface-guidelines/panels)）

4. **P1｜菜单栏完整性：把已有动作全部镜像到菜单栏。**
   需要 File（导出/打开讲稿）、Edit（撤消/重做/查找）、Format（字号/朗读速度）、View（Show/Hide 提词窗、Enter/Exit Full Screen、显示/隐藏侧栏）、Window（Minimize/Zoom）、Help。Toolbar 上每一项都必须能在菜单里找到（官方硬要求）。验收：`NSApp.mainMenu` 结构与 HIG 顺序一致；Accessibility Inspector 里 Full Keyboard Access 能走完主流程。（[依据](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)、[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)）

5. **P1｜status item 必须可被用户隐藏，且不能是唯一入口。**
   `NSStatusBar` 文档要求提供隐藏偏好；`MenuBarExtra` 给 `isInserted:` 绑定；HIG 要求点图标给"菜单"。若现在点击是自定义 popover/窗口，评估改为 `menuBarExtraStyle(.window)` 或 `NSMenu`。验收：设置里能隐藏图标；图标隐藏后所有功能仍可从菜单栏/快捷键触达。（[依据](https://developer.apple.com/documentation/appkit/nsstatusbar)、[MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)、[HIG](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)）

6. **P1｜材质语义化：提词玻璃与主界面 toolbar/sidebar 用系统 material，不自绘半透明。**
   `hudWindow` 用于提词 HUD，`.sidebar`/`.titlebar` 用于主窗口区域；blendingMode 选 behind-window（浮起）或 in-window（跟随滚动）。自绘背景会让 **inactive 窗口失去"subdued"** 这段系统语义。验收：切到别的 app 时提词窗/工具栏自动变灰；取消自定义 `.background(Color.white.opacity(...))` 类叠加。（[依据](https://developer.apple.com/documentation/appkit/nsvisualeffectview)、[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)）

7. **P2｜字号策略对齐 macOS：text styles + 用户可放大 200%，不要做成 iOS 式 Dynamic Type。**
   项目已有"系统字号"诉求时，落地为 `NSFont.preferredFont(forTextStyle:)` / SwiftUI `.font(.body)` 起基线，再提供显式字号档位（提词器本质需要大字号，可给 80%–200% 滑杆）。验收：200% 下无截断/重叠；提词窗 680×205 在最大字号下逐词换行仍可读。（[依据](https://developer.apple.com/design/human-interface-guidelines/typography)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)）

8. **P2｜Reduce Motion 全链路覆盖歌词动效。**
   在 SwiftUI 处读 `@Environment(\.accessibilityReduceMotion)`，AppKit 处读 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`，并订阅 `accessibilityDisplayOptionsDidChangeNotification`（**`NSWorkspace.shared.notificationCenter`**）。开启时：位移/缩放→fade、去弹簧回弹、去 z 轴、去 blur 进出。验收：系统开关切换后**不重启 app** 立即生效；录屏对比无位移。（[依据](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)、[AppKit](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)、[通知](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayoptionsdidchangenotification)）

9. **P2｜多显示器 / 刘海 / 全屏：用 `NSScreen` 与系统 full-screen，别硬编码。**
   提词窗定位应以 `screen.frame` 与 `screen.visibleFrame`、`safeAreaInsets` 推算，而不是常量；全屏走 `toggleFullScreen(_:)`（系统会替 camera housing 让位）；需要跨 Space 时显式声明 `.canJoinAllSpaces`/`.fullScreenAuxiliary` 并接受其副作用。验收：外接显示器 + 不同缩放 + 全屏 Space 下位置正确；菜单栏自动隐藏时不跳动。（[依据](https://developer.apple.com/design/human-interface-guidelines/going-full-screen)、[Layout](https://developer.apple.com/design/human-interface-guidelines/layout)、[fullScreenAuxiliary](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary)）

10. **P3｜受控的"无 Xcode 工程"声明：把限制写进 README/ADR，而不是留给用户发现。**
    现状已做对的部分：手写 `Resources/Info.plist`、手写 `Nook.icns`、`swiftc` 单命令构建、`codesign --force --sign - --timestamp=none`（ad-hoc）、自建测试 harness。需要**明示**的是：ad-hoc 签名 → 他人机器上会被 Gatekeeper 拦截、**无法 notarize**；不用 asset catalog → 无 `actool` 语义（多分辨率/明暗变体需自己管）；不用 XCTest → 无标准测试报告。验收：README 有"分发限制"段落；构建脚本对缺资源/缺 plist 快速失败。（§4 中标注的"未查证"项落地前不要写成官方结论）

---

## ⑤ 参考链接

**HIG（全部为本次实际抓取的线上页面）**

- [Windows](https://developer.apple.com/design/human-interface-guidelines/windows) · [Panels](https://developer.apple.com/design/human-interface-guidelines/panels) · [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) · [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) · [Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus) · [Dock menus](https://developer.apple.com/design/human-interface-guidelines/dock-menus)
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) · [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) · [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views) · [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) · [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) · [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) · [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) · [Color](https://developer.apple.com/design/human-interface-guidelines/color) · [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) · [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) · [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) · [Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion) · [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) · [Going full screen](https://developer.apple.com/design/human-interface-guidelines/going-full-screen) · [Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking) · [Launching](https://developer.apple.com/design/human-interface-guidelines/launching) · [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) · [Settings](https://developer.apple.com/design/human-interface-guidelines/settings) · [Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help) · [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) · [Searching](https://developer.apple.com/design/human-interface-guidelines/searching)

**API 文档**

- [NSPanel](https://developer.apple.com/documentation/appkit/nspanel) · [nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) · [NSWindow.level](https://developer.apple.com/documentation/appkit/nswindow/level-swift.property) · [NSWindow.ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents) · [CollectionBehavior.canJoinAllSpaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces) · [CollectionBehavior.fullScreenAuxiliary](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary)
- [NSWindow.sharingType](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.property) · [NSWindow.SharingType](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum) · [SharingType.none（legacy，勿用于隐藏）](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none)
- [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar) · [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem) · [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview) · [NSVisualEffectView.Material](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material-swift.enum)
- [SwiftUI accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion) · [NSWorkspace.accessibilityDisplayShouldReduceMotion](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion) · [accessibilityDisplayOptionsDidChangeNotification](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayoptionsdidchangenotification)

**官方示例 / 教程页**

- [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)
- [Fruta: Building a feature-rich app with SwiftUI](https://developer.apple.com/documentation/appclip/fruta-building-a-feature-rich-app-with-swiftui)
- [Backyard Birds: Building an app with SwiftData and widgets](https://developer.apple.com/documentation/swiftui/backyard-birds-sample) · [apple/sample-backyard-birds](https://github.com/apple/sample-backyard-birds)
- [Food Truck: Building a SwiftUI multiplatform app](https://developer.apple.com/documentation/swiftui/food-truck-building-a-swiftui-multiplatform-app)
- [Building peer-to-peer apps（Wi‑Fi Aware 示例）](https://developer.apple.com/documentation/wifiaware/building-peer-to-peer-apps)

**WWDC（URL 均已在本次逐条验证 200 且标题匹配）**

- [Meet Liquid Glass — WWDC25/219](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Get to know the new design system — WWDC25/356](https://developer.apple.com/videos/play/wwdc2025/356/)
- [Build an AppKit app with the new design — WWDC25/310](https://developer.apple.com/videos/play/wwdc2025/310/)
- [What's new in SwiftUI — WWDC25/256](https://developer.apple.com/videos/play/wwdc2025/256/)
- [Meet Swift Testing — WWDC24/10179](https://developer.apple.com/videos/play/wwdc2024/10179/)
- [Build an app with SwiftData — WWDC23/10154](https://developer.apple.com/videos/play/wwdc2023/10154/)

---

## 附：未完成 / 未查证（明确标注，勿当结论）

1. **「无 Xcode 工程」的 Apple 官方立场未查到可引用页面。** 本次只确认了 Nook 现有做法（`swiftc` + 手写 Info.plist + ad-hoc `codesign`）。以下均属**推断**，尚未找到官方 URL：`actool`/asset catalog 仅随 Xcode 提供；notarization 需 Xcode 工具链（`notarytool`）；XCTest 需 test bundle + runner。**不要**把这三条写成 Apple 规定，落地前需补官方来源（建议方向：Apple Developer「Notarizing macOS software before distribution」、Swift.org 的 `swift build`/`swift test` 文档、`man codesign`）。
2. **官方示例仓库的目录结构未核实。** GitHub API 本机被 rate limit（403），`raw.githubusercontent.com` 可读单文件。若要"模块划分"细节，需 clone 或次日重试 API。
3. **Sidebars / Menus / Keyboards / Multitasking 等页面已抓取但未逐段引用**（时间受限），其规则未写进 §②，避免转述失真。
4. **「屏幕共享隐藏」的替代实现未验证**：官方指向 FairPlay Streaming，但未查证其在普通 app 内是否可用（很可能只对受保护媒体流适用）。该点需单独调研，Nook 近期不要承诺"共享隐身"。
