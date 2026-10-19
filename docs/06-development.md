# 06 开发指南

## 读完能做什么

你能构建、测试、调试、截图和发布 Nook，并完成一个小功能修改。

## 命令

| 命令 | 作用 |
| --- | --- |
| `./scripts/build.sh` | 编译并生成 dist/Nook.app |
| `./scripts/test.sh` | 编译并运行 558 项检查 |
| `./scripts/run.sh` | 构建后启动 |
| `./scripts/check-docs.py` | 检查文档规则 |
| `./scripts/benchmark.sh` | 测量预览模式的 CPU 与内存 |

## 构建过程

build.sh 做五件事：

1. 用 find 收集 Sources 下的 Swift 文件。
2. 调用 swiftc，目标 macOS 14。
3. 链接 AppKit、SwiftUI、Carbon、NaturalLanguage、Security。
4. 复制 Info.plist 和图标。
5. 做 ad-hoc 签名。

源文件按目录分组。新增目录不需要修改脚本。

## 常见修改

| 想改 | 改这里 |
| --- | --- |
| 默认语速 | PreferencesStore.registerDefaults |
| 语速范围 | PreferencesStore clamp 与 AppModel.setSpeed |
| 断句规则 | HeuristicPhrasePlanner |
| 排版宽度 | PhraseBudget.derive |
| 颜色与字号 | NookTokens |
| 动效 | NookMotion |
| 工具栏 | EditorToolbar |
| 检查器 | InspectorPane |
| 提词面板 | TeleprompterView、KaraokeLyricsView |
| AI 超时 | OpenAICompatibleClient |
| 输出预算 | OpenAICompatibleClient |
| 快捷键 | NookHotKeyAction 与 ApplicationMenuController |

## 例：修改 Natural 预设

1. 打开 `Sources/Nook/Editor/InspectorPane.swift`。
2. 找到 `PacePreset(id: "natural", title: "Natural", wpm: 138)`。
3. 把 138 改成 140。
4. 运行 `./scripts/test.sh`。
5. 运行 `./scripts/build.sh`。
6. 启动应用。
7. 点击检查器的 Natural。
8. 确认语速显示 140。

这个练习不改默认值，所以测试不需要改。

如果你改 `PreferencesStore.registerDefaults`，还要同步修改 `PreferencesStoreTests` 的期望值。

已有用户的旧值不会被覆盖。这是预期行为。

## 例：增加一项检查

1. 打开 `Tests/NookKitTests` 下的测试文件。
2. 写一个 `func runXxxTests()`。
3. 在函数内调用 `check` 或 `checkEqual`。
4. 在 `Tests/NookKitTests/main.swift` 末尾注册函数。
5. 运行 `./scripts/test.sh`。

示例：

~~~swift
func runExampleTests() {
    let store = PreferencesStore(defaults: .standard)
    checkEqual(store.fontSize, 30, "Default type size is 30")
}
~~~

## 预览模式

预览模式使用隔离的 UserDefaults。它不读用户讲稿。

| 参数 | 作用 |
| --- | --- |
| `--preview-sample` | 使用样例数据和隔离存储 |
| `--preview-compact` | 使用 960 × 680 窗口 |
| `--preview-empty` | 清空讲稿，显示空状态 |
| `--preview-ai-settings` | 打开 AI 设置 |
| `--preview-no-inspector` | 收起检查器 |
| `--preview-start` | 1 秒后开始提词 |
| `--preview-motion` | 播放检查器动效序列 |
| `--demo` | 显示提词面板和演示背景 |

示例：

~~~bash
./dist/Nook.app/Contents/MacOS/Nook --preview-sample
~~~

## 调试

### 布局

设置环境变量：

~~~bash
NOOK_DEBUG_LAYOUT=1 ./dist/Nook.app/Contents/MacOS/Nook --preview-sample --preview-start
~~~

终端会打印屏幕、刘海和面板的位置。

必须让面板出现，才会打印。
所以命令要加 `--preview-start`。

### 网络

请求截断时写入诊断日志。

路径：

~~~text
~/Library/Application Support/Nook/ai-debug.log
~~~

日志只记录时间、host、model、预算和 token 数。

日志不记录讲稿、响应正文和密钥。

### 崩溃

用 Console.app 查看 Nook 的崩溃报告。

或在终端运行：

~~~bash
log stream --predicate 'process == "Nook"'
~~~

## 重新生成图表

图表源文件在 `docs/assets/*.drawio`。

重新生成需要 draw.io 桌面版。

~~~bash
./scripts/make-diagrams.py
~~~

脚本会写入 .drawio 文件并导出 2x PNG。

导出后请逐张查看。确认文字不重叠。

## 截图

1. 用 `--preview-sample` 启动。
2. 按 ⌘⇧4。
3. 按空格。
4. 点击窗口。

截图保存到桌面。不要把真实讲稿放进截图。

## 发布

1. 更新 `Resources/Info.plist` 的版本号。
2. 运行 `./scripts/test.sh`。
3. 运行 `./scripts/build.sh`。
4. 检查 bundle id 是 `app.nook.teleprompter`。
5. 退出正在运行的 Nook。
6. 安装：

~~~bash
ditto dist/Nook.app /Applications/Nook.app
~~~

7. 启动应用。
8. 确认讲稿和设置仍在。

安装不会清空 UserDefaults 或 Keychain。

## 提交规范

- 使用 `feat:`、`fix:`、`refactor:`、`docs:`、`test:`、`chore:`。
- 一次提交只做一类改动。
- 提交前运行测试。

## 约束

- 不使用 @State、@FocusState、@StateObject、@Observable。
- 不新增第三方依赖。
- 不切换构建系统。
- 不把密钥写入 UserDefaults 或日志。
- 不删除用户的讲稿和设置。

## 常见陷阱

### 宏不可用

纯 swiftc 缺少 SwiftUI 宏插件。

@State 会报 StateMacro plugin 缺失。

用 ObservableObject 和模型字段替代。

### 预览数据被清空

预览模式每次启动都会清空隔离 suite。

生产数据在标准 UserDefaults 中，不受影响。

### 滚动条出现

SwiftUI TextEditor 会重新打开滚动条。

项目使用 ScriptTextView 包装 NSTextView。

### 屏幕共享隐藏

sharingType 是旧接口。

Apple 明确不建议用它隐藏内容。

项目把它当尽力而为，不当作安全承诺。

## 下一步

读 [07 AI 断句](07-ai-phrasing.md)，理解网络与校验。
