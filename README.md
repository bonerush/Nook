# Nook

<p align="center">
  <img src="docs/assets/editor-main.png" alt="Nook 编辑窗口：浅灰画布、白色纸张、右侧检查器" width="900">
</p>

<p align="center"><strong>把视线留在镜头里。</strong></p>

Nook 是一个 macOS 提词器。它把英文讲稿分成短行。开始提词后，面板停在刘海下方。你的视线靠近摄像头。

## 快速开始

~~~bash
cd "/Users/yukisala/subject/提词器"
./scripts/build.sh
open dist/Nook.app
~~~

1. 粘贴英文讲稿。
2. 选择语速。
3. 按 ⌘↩ 开始。

面板出现后，按 ⌃⌥Space 暂停。

## 主要功能

- **AI 断句。** AI 只返回行边界和停顿。讲稿文字不变。
- **本地回退。** 没有密钥时，本地断句立即可用。
- **官方玻璃面板。** macOS 26 使用 glassEffect。旧系统使用材质回退。
- **逐词填光。** 每个词按朗读进度变亮。
- **悬停裸键。** 鼠标在面板上时，可直接按 Space 或方向键。

## 文档

第一次阅读请从 [docs/README.md](docs/README.md) 开始。那里有一条 60 分钟路线。

| 你想知道 | 读这篇 |
| --- | --- |
| Nook 是什么 | [01 产品说明](docs/01-what-is-nook.md) |
| 怎么运行 | [02 快速开始](docs/02-quick-start.md) |
| 术语是什么意思 | [03 概念与术语](docs/03-concepts.md) |
| 代码怎么分层 | [04 架构](docs/04-architecture.md) |
| 界面为什么这样设计 | [05 设计系统](docs/05-design-system.md) |
| 怎么改代码 | [06 开发指南](docs/06-development.md) |
| AI 请求怎么工作 | [07 AI 断句](docs/07-ai-phrasing.md) |
| 出错了怎么办 | [08 故障排查](docs/08-troubleshooting.md) |
| 每个文件做什么 | [09 代码地图](docs/09-code-map.md) |

## 构建与检查

环境要求：macOS 14 或更新版本。需要 Xcode Command Line Tools。

~~~bash
./scripts/test.sh     # 运行 558 项检查
./scripts/build.sh    # 生成 dist/Nook.app
./scripts/run.sh      # 构建并启动
~~~

## 数据与隐私

- 讲稿和偏好保存在本机 UserDefaults。
- API key 只保存在 macOS Keychain。
- 只有 Start 会联网。输入文字不会联网。
- 请求只发往你配置的 endpoint。

## 限制

- 屏幕共享隐藏是尽力而为。会议软件可能不遵守。详见 [08 故障排查](docs/08-troubleshooting.md)。
- 当前以英文为主。中文不会按字切分。
- 提词面板固定在带刘海的屏幕。无刘海屏会回退到主屏幕。
- 使用 ad-hoc 签名。分发到其他机器要重新签名。

## 版本

当前版本 2.0.0。构建与界面说明见 [05 设计系统](docs/05-design-system.md)。
