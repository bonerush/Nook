# Nook Agent Delivery Workflow

适用：Nook 1.1 AI Phrasing + Linear Editor + Official Glass 实施。

## 角色与原则

- **主代理是默认实现者。** 小任务、连续编辑、上下文强相关的工作由主代理直接完成，以减少重复读取和 token 消耗。
- **重大且相互独立的修改可以使用实现 subagent 或 teams。** 例如独立的官方玻璃 spike、独立的视觉资产或大规模的测试补齐。
- **审查必须由 subagent 完成。** 主代理不能自审后直接放行。
- 遇到高风险改动（网络、密钥、安装、用户数据）时，必须增加一次独立审查。
- 可复用的流程和逻辑沉淀成 workflow 或项目文档，不重复写一次性指令。

## 执行循环

1. 主代理按实施计划完成一个任务。
2. 主代理运行该任务的测试与构建命令。
3. 在检查点派发独立审查 subagent。
4. 审查发现分级：
   - **blocker**：必须修复后才能继续。
   - **non-blocking**：记录，在最终检查点前修复。
   - **note**：保留在报告中，不阻塞。
5. 主代理修复 blocker；如修复改变了设计或安全边界，再派同一审查 agent 复验。
6. 通过后更新 git checkpoint、Obsidian 记忆的进行中状态。

## 强制审查检查点

| Checkpoint | 覆盖任务 | 必须审查的内容 |
|---|---|---|
| A | 1–4 | Tokenizer 保真、schema、composer 时间轴、旧行为回归 |
| B | 5–8 | Keychain、HTTP、错误映射、缓存、隐私与密钥泄漏 |
| C | 9 | Linear 视觉、布局、Tokens、无玻璃/无金色残留、预览数据隔离 |
| D | 10 | AI 设置、Start 状态机、失败降级、无输入期联网 |
| E | 11–12 | 官方玻璃 spike 结论、歌词填充、Reduce Motion、刘海定位、隐私 |
| F | 13 | 全量测试、安装、用户数据保留、文档与版本 |

每个 checkpoint 至少一个 reviewer。UI checkpoint 可以并行派两个独立 reviewer：一个看视觉/交互，一个看工程与可访问性。

## 审查 Agent Prompt 模板

~~~text
你是独立代码审查员，不是实现者。

只读审查：
- Spec: docs/superpowers/specs/2026-10-18-nook-ai-glass-redesign.md
- Plan: docs/superpowers/plans/2026-10-18-nook-ai-glass-redesign.md
- Checkpoint: <A/B/C/D/E/F>
- Files changed: <paths>
- Test evidence: <commands and output>

必须检查：
1. 是否符合 strict no-rewrite token contract。
2. 是否有 API key 或讲稿内容写入日志、UserDefaults、缓存、截图或仓库。
3. Start-only 网络调用是否成立。
4. 测试是否覆盖失败、缓存、超时和恢复路径。
5. 原有刘海定位、鼠标穿透、屏幕共享隐藏和快捷键是否保持。
6. 视觉任务是否遵守 spec；官方玻璃若不可用是否诚实 fallback。
7. 是否有未使用的依赖、隐藏的 @State 宏、错误的安装行为。

输出：
- 结论：pass / pass-with-notes / blocked
- blockers
- non-blocking findings
- evidence checked
- 未覆盖的验收项

不要修改文件。不要声称未运行过的验证通过。
~~~

## 视觉验收

- 只用 --preview-sample 和隔离的 UserDefaults suite 生成截图。
- 不展示用户真实讲稿。
- 每个 UI 检查点至少保留：
  - 960 × 680 和 1040 × 720 两张编辑窗口截图。
  - 刘海下方面板截图，包含 READY、playing、paused 中至少两个状态。
  - 如果官方玻璃 spike 失败，保留对照截图和 fallback 说明。
- Reviewer 必须实际查看截图，不能只读 SwiftUI 代码。

## 安全与数据

- .obsidian-mem 是项目绑定，必须提交；.build/ 与 dist/ 不提交。
- API Key 只存在 macOS Keychain。
- 用户讲稿只存在本机 UserDefaults；不要把它复制进仓库或截图。
- 安装到 /Applications 时保留 bundle id app.nook.teleprompter。
- 任何安装替换前先验证目标路径和 bundle id。

## 实施状态记录

每个 checkpoint 结束后，在 Obsidian 项目中更新：

- 已完成的事实或决策，写为独立 note。
- 进行中的任务只放短指针到 hot 层。
- 失败根因和修复写入 Pitfalls，带证据。
- 用户明确的工作方式写为 Convention，不写入 _meta/user.md。
