# Loop Report · agent-orchestration · m3

> 档位:🌙 放手模式。`agent-orchestration` 第 3 个 milestone（Round 10）。

## ⚠️ 本轮产生 1 条 [needs-human](整夜首条)

`df66321e`(high):**需你用真实 Claude Code 跑一次,核对 stream-json 解析吻合度**。
原因:真跑 `claude -p` = 发真实外部请求 + 花钱,放手模式硬底线下 loop **不实跑**——
已用 stub 子进程全链路 headless 验证,真实格式核对只能由你手动做(详见 ticket)。

## 目标

`agent-orchestration` / **m3 — Claude Code ACP 会话**(decision bf5dc16b 落地)。把 raw pty 之外
新增一条**结构化 lane**:跑 agent 子进程,把 m2 的 adapter 解析的 ACP 事件经 WS 推驾驶舱,raw-pty 作 fallback 保留。

## 做了什么

- **`helm/orchestration/session.py`**（新增）:`iter_process_lines(argv, cwd)` async 生成器——
  唯一碰 OS 的部件(asyncio 子进程→逐行解码 stdout,stderr 合并),缺二进制 raise,退出必 reap。
- **`helm/orchestration/routes.py`**（改）:`@websocket /api/orchestration/runs/ws` —— client 发
  `{agent,prompt,cwd?,...}` → 建 run → 子进程逐行 → `consume_line` 解析为 ACP 事件 → `ws.send_json`
  逐条 → 退出兜底 `done`;未知后端/缺二进制 → `error`。逐行 commit 让 `/runs` API 反映实时状态。
- **`helm/orchestration/adapters.py`**（改）:加 `register_adapter`/`unregister_adapter`(P1 扩展点 + 测试注入)。
- **`tests/test_session.py`**（新增）:5 测——`iter_process_lines` 产出/缺二进制 raise;
  **WS 端到端**(stub 适配器 emit 预置 stream-json → status/message/session_end → done → run=completed)、
  未知后端 error、缺二进制 → run=failed。

## 决策(record_decision)

- **decision `c0b2b2ea`**（ai_proposed）:async 子进程 + WS 流式 ACP 事件,与 raw-pty 并存,逐行 commit。
- 放手模式硬底线:真跑 claude=外部付费请求,**loop 未实跑**;stub 全链路验证 + `[needs-human]` 核对 ticket。
- **本轮 1 条 `[needs-human]`**(`df66321e`,真实格式核对——loop 不能做的事)。

## VibeHub / MCP 交互

**pull**:读 `helm/cockpit/routes.py` 的 terminal_ws WS 范式(accept/pump/finally teardown)。
**write**:
- `record_decision`（`c0b2b2ea`,ai_proposed）。
- `create_ticket`（`df66321e`,**[needs-human]** 真 Claude Code 核对,bound→agent-orchestration,high）。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:纯后端;本地 `pytest` 全绿。注意 WS 测试用本地 python stub 子进程(免费),不跑真 claude。
- cron/loop:`2dc539c2`,Round 10。

## defer

- `[needs-human]` `df66321e`:真实 Claude Code stream-json 格式核对(付费外部调用,loop 不做)。

## 优化

- **后端**:OS 触点收敛到 `iter_process_lines` 一处(WS 与测试共用,真/stub 可换);事件逐行流式 +
  逐行 commit 让实时状态可查;`register_adapter` 既是 P1 扩展点也是测试注入点(一物两用)。
- **前端**:本轮无前端(驾驶舱消费 WS 在 m4)。

## 验证

- `pytest tests/test_session.py` → **5 passed**(含 WS 端到端 + 两条错误路径)。
- `pytest`（全量后端）→ **124 passed, 1 skipped**(m2 119 → +5)。
- **未跑真实 claude**(付费外部调用,放手模式硬底线);stub 子进程覆盖 spawn→parse→stream→持久化全链路。

## review

自审:
- WS 路径:run_started → ACP 事件 → done;未知后端 error;缺二进制 → run 标 failed + error 事件 —— 全有测试。
- async 子进程退出必 reap(finally terminate+wait),无僵尸。
- 逐行开 session commit:实时状态可查;略费但 SQLite 快,m4 真用时若成瓶颈再优化(未达瓶颈,不预优化)。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。一个付费外部操作按放手模式**就地化解**(stub 验证 + [needs-human] ticket),未停 loop。

## 下一步

`agent-orchestration` / **m4 — 驾驶舱观测 agent 产出**:前端连 `/runs/ws`,把 ACP 事件
(tool_call/plan/message/permission)显示在驾驶舱,与 cockpit 文件监听联动(intent#3)。Room 末个 milestone。
