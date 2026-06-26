# Room 收尾复盘 · agent-orchestration

> 档位:🌙 放手模式。`agent-orchestration` 4 个 MVP milestone 完成,Room 收尾 → 合 main。

## Room 概览

粘合层:以 Claude Code(外部 CLI)为唯一 agent(MVP),经 MCP 把 Helm 大脑能力注入终端 Claude Code,
并让驾驶舱实时观测其产出。MVP 边界由用户 2026-06-25 拍板(decisions b199f333/76961005):
v1 仅 Claude Code,多后端/多 agent Teams = P1。

## 4 个 milestone(全部完成)

| m | 内容 | 关键产出 | 提交 |
|---|---|---|---|
| m1 | MCP 配置注入 | `helm/orchestration/mcp_config.py` 合并+备份 .mcp.json,即时启停,损坏拒绝 | `23cb0b7` |
| m2 | ACP 驱动层抽象 + agent_runs | `acp.py` 事件 + `adapters.py`(Claude parser + 注册表)+ AgentRun 表 + 状态机 | `60da471` |
| m3 | Claude Code ACP 会话 | `session.py` async 子进程 + WS `/runs/ws` 流式 ACP 事件(stub 验证,未跑真 claude) | `c1d30b0` |
| m4 | 驾驶舱观测 agent 产出 | `agentStore` + `AgentView` + CockpitView 分段【预览\|Agent】 | `0ee2cff` |

## 验证门(全绿)

- 后端 `pytest` → **124 passed, 1 skipped**。
- desktop `node --check` → ok。
- 前端 `vitest` → **105 passed**;`svelte-check` → **0/0**;`build` → ok。

## 决策留痕(本 Room,均 ai_proposed 待确认)

- `6820a48c` milestone 拆分 · `c0b2b2ea` m3 会话架构 · `0851c826` m4 观测 UI。
- 承接已有:`bf5dc16b` ACP 层 · `76961005`/`b199f333` MVP 收口(Claude Code only)。

## backlog(留待 drain,未阻塞合并)

- **`df66321e`（[needs-human]，high）**:用真实 Claude Code 核对 stream-json 解析 —— **付费外部调用,loop 不做**,你来跑。
- `ae484ba6`(medium):Skills 启停/遥测需 agent 集成(m7 遗留,本 Room 承接)。
- `f4987eed`(medium):tool_call↔FileChange 关联高亮。
- `bb92b74d`(medium):驾驶舱终端 agent 识别 + 结构化事件 seam —— **实质已被 m2/m3 的 ACP 驱动层覆盖**,建议人工确认后关闭。

> 收尾 drain:本 Room 非 needs-human 技术 ticket 均为可延 medium,按"绝不为清债拖延合并"留 backlog。

## needs-human 队列

**1 条(df66321e)**:真实 Claude Code stream-json 核对。这是整夜首条 [needs-human],因为它是
**loop 碰到付费外部调用、按硬底线不靠猜执行**而留给你的验证任务——不是难撤产品决策,而是 loop 能力外的事。

## 合并

`feat/agent-orchestration` → `main`(PR + CI 绿 + 合并提交保留逐 milestone 历史)。
合后自动切下一个 Room:`deep-research`。
