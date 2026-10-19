# 09 代码地图

## 读完能做什么

你能按问题找到文件，并知道每个文件的职责。

## 从问题找文件

| 问题 | 先看 |
| --- | --- |
| 讲稿怎么分词 | NookKit/Core/SpeechScript.swift |
| 断句怎么校验 | NookKit/Core/PhrasePlan.swift |
| 行宽怎么测量 | NookKit/Core/PhraseLayout.swift |
| 时间轴怎么算 | NookKit/Planning/PromptComposer.swift |
| 文档怎么生成 | NookKit/Planning/ScriptDocumentBuilder.swift |
| 本地断句规则 | NookKit/Planning/HeuristicPhrasePlanner.swift |
| AI prompt | NookKit/Planning/PhrasePlanningPrompt.swift |
| 请求与超时 | NookKit/Providers/OpenAICompatibleClient.swift |
| 配置校验 | NookKit/Providers/LLMConfiguration.swift |
| 缓存 | NookKit/Storage/PhrasePlanCache.swift |
| 偏好读写 | NookKit/Storage/PreferencesStore.swift |
| 密钥 | NookKit/Storage/KeychainStore.swift |
| 应用组装 | Nook/App/AppDelegate.swift |
| 菜单栏 | Nook/App/MenuBarController.swift |
| 主菜单 | Nook/App/ApplicationMenuController.swift |
| 快捷键 | Nook/App/HotKeyRouter.swift |
| 开始流程 | Nook/App/EditorCoordinator.swift |
| 编辑窗口 | Nook/App/EditorWindowController.swift |
| 预览模式 | Nook/App/PreviewHarness.swift |
| 编辑状态 | Nook/Model/AppModel.swift |
| AI 设置状态 | Nook/Model/AISettingsModel.swift |
| 主界面 | Nook/Editor/EditorView.swift |
| 工具栏 | Nook/Editor/EditorToolbar.swift |
| 稿纸 | Nook/Editor/ScriptPaper.swift |
| 正文输入 | Nook/Editor/ScriptTextView.swift |
| 呼吸图 | Nook/Editor/BreathRibbon.swift |
| 检查器 | Nook/Editor/InspectorPane.swift |
| 配色与字号 | Nook/DesignSystem/NookTokens.swift |
| 动效 | Nook/DesignSystem/NookMotion.swift |
| 提词面板 | Nook/Teleprompter/TeleprompterController.swift |
| 歌词 | Nook/Teleprompter/KaraokeLyricsView.swift |
| 播放时钟 | Nook/Teleprompter/PlaybackEngine.swift |

## App 目录

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| NookMain.swift | 15 | 创建 NSApplication |
| AppDelegate.swift | 131 | 组装对象，处理生命周期 |
| EditorCoordinator.swift | 254 | 编辑窗口与提词面板的交接 |
| EditorWindowController.swift | 118 | 创建窗口，设置焦点 |
| MenuBarController.swift | 171 | 状态栏图标与菜单 |
| ApplicationMenuController.swift | 222 | 主菜单与命令 |
| HotKeyRouter.swift | 44 | 全局快捷键分发 |
| GlobalHotKeys.swift | 192 | Carbon 热键注册 |
| PreviewHarness.swift | 185 | 预览模式与演示场景 |

## Model 目录

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| AppModel.swift | 344 | 讲稿、语速、计划与开始流程 |
| AISettingsModel.swift | 259 | 密钥草稿、保存与连接测试 |
| NookTime.swift | 24 | 时间格式化 |

## Editor 目录

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| EditorView.swift | 87 | 主界面布局 |
| EditorToolbar.swift | 150 | 品牌、状态、Start |
| ScriptPaper.swift | 167 | 纸张、标题、空状态 |
| ScriptTextView.swift | 118 | NSTextView 包装 |
| BreathRibbon.swift | 94 | 句子时长条 |
| InspectorPane.swift | 312 | 四个设置分区 |
| PaceSegmentedControl.swift | 76 | 三档语速 |
| AISettingsOverlay.swift | 494 | AI 设置面板 |
| PlanningErrorBanner.swift | 63 | 错误横幅 |
| EditorStatusBar.swift | 32 | 语速与快捷键提示 |
| EditorActions.swift | 10 | 编辑器意图 |

## DesignSystem 目录

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| NookTokens.swift | 94 | 颜色、字体、间距、窗口尺寸 |
| NookMotion.swift | 22 | 动效曲线与 Reduce Motion |
| NookComponents.swift | 175 | 通用控件样式 |
| NookCanvas.swift | 33 | 画布与材质背景 |

## Teleprompter 目录

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| TeleprompterController.swift | 341 | 面板定位、显示与隐藏 |
| TeleprompterView.swift | 48 | 玻璃卡片内容 |
| KaraokeLyricsView.swift | 153 | 三行歌词与填光 |
| LyricProgressRail.swift | 77 | 进度条与时间 |
| OfficialGlassSurface.swift | 42 | 官方玻璃与回退 |
| NookVisualEffectView.swift | 31 | 材质回退 |
| PlaybackEngine.swift | 289 | 播放时钟与进度 |

## NookKit 目录

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| Core/SpeechScript.swift | 87 | 词元模型与分词器版本 |
| Core/PhrasePlan.swift | 228 | 计划、预算、校验与修复 |
| Core/PhraseLayout.swift | 90 | 字体宽度测量 |
| Core/PromptMetrics.swift | 45 | 面板尺寸指标 |
| Core/PromptDocument.swift | 169 | 提词文档模型 |
| Core/PromptScriptBuilder.swift | 531 | 旧版文本构建器 |
| Core/SampleScript.swift | 15 | 示例讲稿 |
| Planning/PromptComposer.swift | 216 | 计划到时间轴 |
| Planning/HeuristicPhrasePlanner.swift | 24 | 本地断句 |
| Planning/PhrasePlanningPrompt.swift | 67 | prompt 版本与文本 |
| Planning/AIPlanningCoordinator.swift | 226 | 缓存、请求、校验状态机 |
| Planning/ScriptDocumentBuilder.swift | 25 | 文档构建入口 |
| Providers/LLMConfiguration.swift | 170 | endpoint 与 provider |
| Providers/HTTPTransport.swift | 58 | 传输协议 |
| Providers/OpenAICompatibleClient.swift | 256 | URLSession 请求与解码 |
| Storage/KeychainStore.swift | 78 | Keychain |
| Storage/PhrasePlanCache.swift | 148 | LRU 缓存 |
| Storage/PreferencesStore.swift | 59 | UserDefaults |

## 测试目录

| 文件 | 检查内容 |
| --- | --- |
| TestHarness.swift | check 与 checkEqual |
| SpeechScriptTests.swift | 分词与句子 |
| PhrasePlanTests.swift | 校验与修复 |
| PromptComposerTests.swift | 时间轴 |
| PreferencesStoreTests.swift | 偏好与钳制 |
| ScriptDocumentBuilderTests.swift | 文档构建 |
| LLMConfigurationTests.swift | URL 与 provider |
| PhrasePlanCacheTests.swift | 缓存键与淘汰 |
| AIPlanningCoordinatorTests.swift | 状态机 |
| main.swift | 运行器 |

## 下一步

读 [style-guide](style-guide.md)，了解文档规则。
