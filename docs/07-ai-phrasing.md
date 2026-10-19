# 07 AI 断句

## 读完能做什么

你能说明 AI 请求的内容。你也能说明校验和失败处理。

## 目标

AI 只做一件事：把词元分组。

AI 不改写文字。

模型输出直接决定换行和停顿，因此必须严格校验。

## 请求

触发条件只有两个：

1. 用户按 Start。
2. 用户按 Retry AI。

输入文字时不联网。

请求发往用户配置的 Base URL。

请求体包含：

- 模型名。
- system prompt。
- user prompt。
- JSON 模式。
- 输出预算。
- thinking 开关与 effort。

user prompt 包含：

- 语速。
- 句子数。
- 词元总数。
- 合法编号范围。
- 每个句子的词元编号和文本。

词元文本被标记为不可信数据。

## 输出格式

模型必须返回一个 JSON 对象：

~~~json
{"lines": [[0, 3, 120], [4, 7, 0]], "emphasis": [2, 5]}
~~~

每一行含义：

| 字段 | 含义 |
| --- | --- |
| START | 起始词元编号 |
| END | 结束词元编号 |
| PAUSE_MS | 行尾额外停顿，0 到 400 |

规则：

- 每个编号出现一次。
- 编号递增。
- 行不跨句。
- 行不超词数与字符预算。
- 强调词最多三个。

## 校验与修复

校验器在 `PhrasePlan.swift`。

它会修复四类问题：

1. 编号缺口。
2. 跨句的组。
3. 越界的组。
4. 负数或超长停顿。

它拒绝三类问题：

1. 编号重叠。
2. 编号越界。
3. 空计划。

修复后的计划仍由本地排版器再次测量和切分。

## 预算

行预算由字号和面板宽度推导。

~~~text
最大字符数 = 可用宽度 / (字号 × 0.52)
最大词数 = 最大字符数 / 4
~~~

结果限制在 4 到 12 个词。

## 网络参数

| 参数 | 值 |
| --- | --- |
| 普通请求超时 | 60 秒 |
| reasoning 请求超时 | 180 秒 |
| 普通输出预算 | 2048 到 8192 token |
| reasoning 输出预算 | 8192 到 65536 token |

reasoning 预算用于思考内容和最终 JSON。

## 缓存

缓存键包含七个字段：

1. 模型名。
2. prompt 版本。
3. 讲稿 SHA-256。
4. 分词器版本。
5. thinking 开关。
6. effort。
7. 词数与字符预算。

缓存目录：

~~~text
~/Library/Application Support/Nook/PhrasePlans
~~~

保留策略：

- 最多 20 条。
- 最多 2 MB。
- 目录权限 0700。
- 文件权限 0600。

## 错误

| 错误 | 用户看到 | 原因 |
| --- | --- | --- |
| disabled | 未配置，使用本地断句 | 缺少 endpoint 或密钥 |
| unauthorized | API key rejected | 401 或 403 |
| rateLimited | Rate limited | 429 |
| timeout | 请求超时 | 超过 60 或 180 秒 |
| network | AI unavailable | 断网或 DNS 失败 |
| truncated | 响应被截断 | 输出预算不足 |
| server | Provider error | 其他 HTTP 错误 |
| invalidPlan | 计划不可用 | 校验失败 |
| tooLong | 讲稿过长 | 超过 token 上限 |

失败时不会静默降级。

用户可以选择 Retry AI、Start locally 或 Settings。

## 隐私

- 密钥只存 Keychain。
- 请求只包含词元、预算和 schema。
- 不包含其他本机内容。
- 截断日志只记录元数据。

## 测试

相关检查覆盖：

- 请求体字段。
- 响应解码。
- 校验与修复。
- 缓存命中。
- 超时与错误映射。
- coordinator 状态机。

## 下一步

读 [08 故障排查](08-troubleshooting.md)。
