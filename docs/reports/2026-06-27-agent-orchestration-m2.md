# Loop Report · agent-orchestration · m2

> 档位:🌙 放手模式。`agent-orchestration` 第 2 个 milestone（Round 9）。本 Room 技术核心。

## 目标

`agent-orchestration` / **m2 — ACP 驱动层抽象 + agent_runs 数据模型**（decision bf5dc16b）。
定义 ACP 风格结构化事件 + 多后端可扩展的 adapter 抽象(仅实现 Claude Code parser)+ agent_runs 表,
为 m3(实时子进程会话)与 m4(驾驶舱观测)打底。非末个。

## 做了什么

- **`helm/orchestration/acp.py`**（新增）:ACP 风格事件词汇——`AcpEventType`(STATUS/MESSAGE/
  TOOL_CALL/TOOL_RESULT/PLAN/PERMISSION_REQUEST/SESSION_END/ERROR)、`RunStatus`(pending→running→
  waiting_permission→completed/failed)、`AcpEvent`(dataclass,`to_dict` 可直接上 WS/JSON)。
  **非全 ACP JSON-RPC 规范**——按 decision「ACP *风格*」取最小可扩展子集。
- **`helm/orchestration/adapters.py`**（新增）:`AgentAdapter` ABC(`command` + `parse_line`)+
  `ClaudeCodeAdapter`(解析 `--output-format stream-json` NDJSON:system/init、assistant 的
  text+tool_use、user 的 tool_result、result;非 JSON 噪声忽略)+ 注册表 `get_adapter`/
  `available_adapters`。**多后端可扩展,MVP 仅 claude-code**(加后端=新 adapter,上层不改)。
- **`helm/orchestration/models.py`**（新增）:`AgentRun` 表(session_id/project_path/agent/status/
  prompt/error/started_at/ended_at)。session_id 松引用非 FK(run 独立于 pty 生命周期)。
- **`helm/orchestration/runs.py`**（新增）:`AgentRunService` —— create(校验后端存在)/list/get/
  `consume_line`(喂一行原生输出→adapter 解析→按 ACP 事件推进 run 状态)/fail。**无传输层**,状态机可单测。
- **`routes.py`**（改）:`GET /api/orchestration/agents`(可用后端)、`GET /runs`、`GET /runs/{id}`(404)。
- **`tests/test_acp.py`**（新增）:9 测——注册表、command、解析 init/message/toolcall/result、忽略噪声、
  事件可序列化、run 生命周期推进、错误结果→failed、未知后端 raise、路由。

## 决策(record_decision)

- 本轮技术决策(放手模式自决,承接已记录的 decision bf5dc16b/76961005):
  - ACP 取**最小风格子集**而非全 JSON-RPC 规范——足够驱动驾驶舱观测,避免过度移植(可逆,后续要扩按需加)。
  - adapter 注册表式扩展点——加后端零上层改动,符合"多后端可扩展、MVP 单后端"边界。
  - `AgentRun.session_id` 松引用非 FK——run 独立于 pty。
- **无难撤产品 OQ → 0 条 `[needs-human]`**。

## VibeHub / MCP 交互

**pull**:读 AionUi `acpTypes.ts`(ACP 规范形状,取最小子集)+ 现有 `helm/cockpit/terminal.py`
(PtyProcess raw pty)+ `cockpit/models.py`(TerminalSession.agent 字段)。
**write**:无新 decision/ticket(本轮承接已记录的 ACP 决策,实现层无新分歧;Claude Code 格式验证留 m3)。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:纯后端;本地 `pytest` 全绿。
- cron/loop:`2dc539c2`,Round 9。

## defer

- Claude Code stream-json **真实格式验证**:本轮 parser 基于其文档化的 stream-json 格式 + 构造样本测试;
  **真实输出的字段细节待 m3 实时子进程联调验证**(届时若字段名有出入,在 m3 校正)。非 ticket——m3 自然覆盖。

## 优化

- **后端**:adapter 无状态(parse_line 纯函数式)→ 易测易并发;状态机集中在 consume_line 一处;
  事件 to_dict 直出 WS 形状,m3/m4 零额外序列化。
- **前端**:本轮无前端。

## 验证

- `pytest tests/test_acp.py` → **9 passed**。
- `pytest`（全量后端）→ **119 passed, 1 skipped**(m1 110 → +9)。
- 人工目视项:未跑真实 Claude Code 子进程(m3 做);本轮以构造的 stream-json 样本全覆盖解析路径。

## review

自审:
- 解析覆盖 init/text/tool_use/tool_result/result + 噪声忽略 + 多内容块(text+tool_use 同行→两事件)。
- 状态机 pending→running→completed/failed,ended_at 落点正确,有测试。
- 注册表对未知后端 raise(P1 后端不会静默当成 claude)。
- 事件 JSON 可序列化(WS 前置)。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。

## 下一步

`agent-orchestration` / **m3 — Claude Code ACP 会话**:把 cockpit raw pty 上抬为 ACP 子进程会话,
跑真实 `claude --output-format stream-json`,把 adapter 解析的事件经 WS 推驾驶舱(保留 pty fallback),
并**校验真实 stream-json 格式**。Room 继续。
