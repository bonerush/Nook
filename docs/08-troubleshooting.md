# 08 故障排查

## 读完能做什么

你能定位构建、启动、面板、AI 和快捷键问题，并恢复用户数据。

## 先收集信息

运行三条命令：

~~~bash
sw_vers
xcode-select -p
swiftc --version
~~~

记录输出。多数构建问题能从这里发现。

## 构建失败

### 找不到 swiftc

原因：没有安装 Xcode Command Line Tools。

修复：

~~~bash
xcode-select --install
~~~

### 编译错误

先看第一条错误。后面的错误常是连锁反应。

常见原因：

- 新增文件放错目录。
- 使用了 @State 等宏。
- 修改了公开类型签名。

运行完整构建：

~~~bash
./scripts/build.sh
~~~

### 签名失败

ad-hoc 签名不需要证书。

如果 codesign 失败，先确认 Xcode Command Line Tools 正常。

## 应用无法打开

### Gatekeeper 阻止

原因：应用使用 ad-hoc 签名。

修复：

1. 打开系统设置。
2. 进入隐私与安全性。
3. 点击仍要打开。

### 打开后没有窗口

Nook 是菜单栏应用。先看菜单栏图标。

点击图标，选择打开编辑器。

也可以按 ⌃⌥E。

## 提词面板不出现

按顺序检查：

1. 屏幕是否有刘海。
2. 面板是否被 ⌃⌥H 隐藏。
3. 是否在屏幕共享中。
4. 是否按了 Start。
5. 讲稿是否为空。

无刘海屏时，面板回退到主屏幕菜单栏下方。

### 面板位置偏移

运行：

~~~bash
NOOK_DEBUG_LAYOUT=1 ./dist/Nook.app/Contents/MacOS/Nook --preview-sample
~~~

终端会打印屏幕、刘海和窗口坐标。

## AI 失败

| 现象 | 检查 |
| --- | --- |
| AI not configured | Base URL、model 或密钥是否完整 |
| API key rejected | 密钥是否正确，是否有权限 |
| Rate limited | 等待后重试 |
| 请求超时 | 网络是否稳定，provider 是否繁忙 |
| 响应被截断 | 讲稿是否过长 |
| AI error 无详情 | 查看编辑窗口的错误横幅 |

### 查看诊断日志

~~~bash
cat "~/Library/Application Support/Nook/ai-debug.log"
~~~

日志只包含元数据。它不包含讲稿和密钥。

### 测试连接

1. 打开 AI 设置。
2. 点击 Test connection。
3. 看状态行。

## 快捷键无效

### 全局快捷键

确认没有其他应用占用 ⌃⌥Space。

### 悬停裸键

裸键只在鼠标位于面板内时生效。

移出面板后，裸键立即失效。

### 菜单命令

菜单命令使用 ⌘ 组合键。全局快捷键使用 ⌃⌥。

两者不冲突。

## 文本问题

### 中文被拆错

当前分词器以英文为主。中文不会按字切分。

### 引号或破折号被替换

Nook 关闭了智能引号和智能破折号。

如果旧文本已包含替换字符，请手动修复。

### 粘贴后格式丢失

Nook 只保存纯文本。这是预期行为。

## 屏幕共享限制

Nook 使用 `sharingType` 请求录制工具跳过面板。

这是旧接口。Apple 不建议用它隐藏内容。

结果：

- 系统截图可能看不到面板。
- 会议软件可能仍然看得到。
- 不能把此项当作安全保证。

需要绝对隐藏时，请关闭面板或使用系统的窗口共享选择。

## 数据在哪里

| 数据 | 位置 |
| --- | --- |
| 讲稿与偏好 | UserDefaults，bundle id app.nook.teleprompter |
| API key | macOS Keychain |
| 断句缓存 | ~/Library/Application Support/Nook/PhrasePlans |
| 诊断日志 | ~/Library/Application Support/Nook/ai-debug.log |

### 恢复默认设置

先退出 Nook。再运行：

~~~bash
defaults delete app.nook.teleprompter
~~~

此命令会删除讲稿和偏好。

密钥在 Keychain 中，需要在应用内清除。

## 收集崩溃信息

打开 Console.app。

在左侧选择崩溃报告。

搜索 Nook。

## 下一步

读 [09 代码地图](09-code-map.md)，找到对应文件。
