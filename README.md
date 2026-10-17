# Nook

<p align="center">
  <img src="Resources/NookIcon.png" width="128" alt="Nook app icon">
</p>

<p align="center">
  <strong>把视线留在镜头里。</strong><br>
  一个悬浮在 Mac 刘海下方的英文提词器。
</p>

Nook 是一个为英文自我介绍、面试和短演讲准备的小型 macOS 提词器。它把讲稿自动拆成适合换气的短句，以逐词高亮的方式提示节奏；窗口固定在刘海正下方，读稿时视线自然落在摄像头附近。

## 功能

- **刘海下方悬浮**：使用屏幕真实安全区定位，不遮挡摄像头；无边框、无焦点、始终置顶。
- **英文优先的自动断句**：基于 Apple 自然语言分句器，补充缩写与人名词首规则，再按实际字体宽度和标点切成短呼吸组。
- **自然的英文节奏**：按音节长度计算词时长，逗号、分号、破折号、句末和段落都有不同停顿；2 秒 READY 准备后再开始。
- **逐词高亮**：当前词用暖色胶囊指示，已读和未读词自然变淡，下一句保持在视觉余光内。
- **歌曲式进度**：极细进度轨、发光播放头、已用时 / 剩余时间、当前状态与 WPM。
- **液态玻璃暗色外观**：桌面实时模糊、暗色玻璃、顶部高光、边缘折射和细腻磨砂纹理。
- **不打断会议操作**：提词窗鼠标穿透，永远不会抢焦点；所有控制都在全局快捷键和菜单栏里。
- **面试隐形模式**：默认从屏幕录制和屏幕共享中排除提词窗；编辑器里可以随时关闭此选项。
- **本地持久化**：讲稿和偏好只保存在本机 UserDefaults，无网络请求。
- **零 Xcode 依赖**：用 Command Line Tools 和 `swiftc` 即可构建。

## 快速开始

环境要求：macOS 14 或更新版本，已安装 Xcode Command Line Tools。

```bash
cd "/Users/yukisala/subject/提词器"
./scripts/build.sh
open dist/Nook.app
```

或者一步构建并启动：

```bash
./scripts/run.sh
```

Nook 是菜单栏应用，不显示 Dock 图标。首次启动会打开编辑器。

## 使用

1. 粘贴或输入你的英文讲稿。空行会产生更长的段落停顿。
2. 选择语速预设（从容 / 自然 / 面试），或者拖动 WPM 滑杆。默认 **138 WPM**。
3. 按 **⌘↩** 或点击「开始提词」。窗口会出现在刘海正下方，并在 2 秒 READY 后开始。
4. 继续专注于朗读。界面本身会鼠标穿透，不会打断 Zoom、浏览器或 Keynote。
5. 需要调整时直接用全局快捷键；也可以点菜单栏的 Nook 图标。

### 全局快捷键

| 快捷键 | 动作 |
| --- | --- |
| **⌃⌥Space** | 播放 / 暂停 |
| **⌃⌥← / →** | 上一句 / 下一句 |
| **⌃⌥↑ / ↓** | 加快 / 放慢语速（每次 5 WPM） |
| **⌃⌥R** | 从头开始 |
| **⌃⌥H** | 显示 / 隐藏提词窗 |
| **⌃⌥E** | 打开编辑器 |

快捷键使用 Carbon 全局热键实现，不需要辅助功能权限。若某个组合被其他软件占用，可在菜单栏和编辑器里完成同样的操作。

### 屏幕共享时隐藏

编辑器右侧的「屏幕共享时隐藏」默认开启。开启时 Nook 使用 `NSWindow.sharingType = .none` 把提词窗从系统截屏和常见屏幕共享软件中排除。

这是一层软件级保护：绝大多数基于 macOS 窗口捕获的会议软件会遵守它，但硬件采集卡或对着屏幕拍摄的方式无法被它阻止。

## 断句与节奏是怎么做的

Nook 不会改写你的文字，只决定**怎么分组**、**停留多久**：

1. 用 `NLTokenizer` 将段落切成句子，并合并 `Dr.`、`Mr.`、`J. K.` 等被误切的片段。
2. 把句子按渲染后的真实字宽切成短行：优先在逗号、分号、破折号和从句连接词前断行，同时限制一行最多 12 个词。
3. 根据音节数给每个词计算相对时长，并将平均值校准到设定的 WPM。
4. 在行内逐词推进；遇到标点时延长停留，句末和段落末再增加分别约 0.55 秒和 0.91 秒的呼吸。
5. 用 30 fps 播放时钟刷新高亮和进度，暂停后恢复不会累积误差。

句子边界不会跨行合并，每一行都只属于一个句子。

## 项目结构

```text
Sources/NookKit/PromptScript.swift   # 分句、呼吸组、时间轴、测试用纯逻辑
Sources/Nook/AppModel.swift          # 讲稿/偏好持久化
Sources/Nook/PlaybackEngine.swift    # 播放时钟与进度
Sources/Nook/TeleprompterController.swift # 刘海定位、NSPanel、窗口动画
Sources/Nook/TeleprompterView.swift  # 液态玻璃提词面板
Sources/Nook/EditorView.swift        # 编辑器界面
Sources/Nook/AppDelegate.swift       # 菜单栏、全局快捷键、应用生命周期
Tests/NookKitTests/main.swift        # 无第三方依赖的检查程序
Resources/Info.plist                 # Bundle 配置
Resources/Nook.icns                  # 应用图标
scripts/build.sh                     # 使用 swiftc 构建 .app
scripts/test.sh                      # 编译并运行检查
scripts/make-icon.py                 # 重新生成图标（可选）
```

## 验证

```bash
./scripts/test.sh
```

当前检查覆盖：空输入、缩写/句首 initials、真实句界、em dash 停顿、逗号与句末停顿差异、WPM 缩放、逐词时间连续性、行的宽度约束、行与句子归属、进度边界，以及示例讲稿的断句输出。共 389 项检查通过。

已经在本机 macOS 27（Apple Silicon，1710 × 1112 pt 内置刘海屏）验证：

- 提词窗 736 × 261 pt（含透明阴影边距），可见玻璃卡片 680 × 205 pt；
- 卡片顶部距刘海安全区底部 7 pt，水平居中于摄像头；
- 开始后编辑器隐藏，焦点返回上一个前台应用；
- 开启隐藏后，提词窗在 `screencapture` 与系统截图中不可见，同时窗口仍在屏幕上；
- 全流程面板在 30 fps 下正常推进。

## 构建说明

项目没有使用 SwiftPM/Xcode 工程，因为当前机器只安装了 Command Line Tools，且该环境下的 SwiftUI 宏插件不完整。构建脚本直接调用 `swiftc`，部署目标为 macOS 14。因此本项目避开了需要 SwiftUI 宏插件的 `@State` 等特性，界面状态全部由 AppKit/SwiftUI ObservableObject 驱动。

生成图标（可选）：

```bash
python3 scripts/make-icon.py   # 需要 Pillow 和 numpy
```

## 已知边界

- 目前以英文为第一优先级。中文不会被按字切开，因此不建议直接用于中文讲稿。
- 固定显示在带刘海的屏幕；如果没有刘海屏，会退回到主屏幕菜单栏下方居中显示。
- 没有麦克风语音跟随；节奏由 WPM、音节和标点决定，可用快捷键随时跳句。
- 采用 ad-hoc 签名，适合本机使用；分发到其他机器时需要重新签名。
