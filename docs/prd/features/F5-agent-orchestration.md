# F5 · Agent 编排与工具（Claude Code 优先）

> 来源：新建（融合粘合层）｜优先级：**P0**｜里程碑：M2（终端跑通）/ M3（MCP 接通）
> 上级：[PRD 主文档](../00-PRD-Master.md)
>
> **现行决策（2026-06-16）**：**暂不做内置/本地 agent**，统一默认用 **Claude / Claude Code**（外部 CLI 路线）。
> 旧的"双 agent"设计（含内置 agent）已归档：[`../_archive/F5-agent-orchestration.v1.md`](../_archive/F5-agent-orchestration.v1.md)，未来需要可恢复。

把「驾驶舱」和「大脑」接到一起的粘合层：在内嵌终端里跑 **Claude Code**，并用 **MCP** 把 Helm 大脑的能力喂给它，让它的产出被驾驶舱实时观测。

---

## 1. 目标
- 以 **Claude Code（外部 CLI，默认模型 Claude）** 为唯一 agent 路线，在内嵌终端运行。
- 通过 **MCP** 让 Claude Code 调用 Helm 大脑的能力（记忆 / RAG / 研究 / 邮件…，见 F4/F3/F7）。
- 让 agent 的产出（写文件、改代码）被驾驶舱实时观测（见 F1）。
- Helm 只做**宿主 + 能力注入 + 观测**，不重造 Claude Code 的能力。

## 2. 非目标
- **暂不做内置/本地 agent**（Python 自带工具的 agent）—— 设计保留在归档，本期不实现。
- 暂不做多 agent 后端切换（Codex 等留作后续可选；当前默认 Claude Code）。

---

## 3. agent 路线（单一）

| | Claude Code（默认且唯一） |
|---|---|
| 跑在哪 | 内嵌终端（后端 pty，F1） |
| 模型 | **Claude**（走你自己的 Claude 订阅 / API） |
| 适合 | 编程任务、长会话、`--resume` 续接 |
| 能力来源 | Claude Code 自带 + Helm 注入的 MCP server |
| 观测 | 文件监听 + 会话日志解析（F1） |

> Claude Code 自带文件/编辑/shell 等工具，Helm **不另造**一套工具；Helm 的增量价值在「MCP 注入大脑能力 + 驾驶舱观测」。
> Codex / 其它 CLI：架构上仍可在终端运行，但**非默认、暂不做专门集成**。

## 4. MCP 接通（融合核心）
- Helm 作为 **MCP host**：把 F4 暴露的 `memory` / `rag`（及按需的 `email` 等）server 提供出来。
- Helm 把这些 MCP server **自动注册给终端里的 Claude Code**：
  - 自动生成/**合并**（非覆盖）Claude Code 的 MCP 配置（等价 `claude mcp add`），指向 Helm 暴露的 stdio/HTTP MCP server；改前**备份**。
  - 结果：**在终端里跑 Claude Code，它能直接读你的 Helm 记忆 / RAG**。
- 设置里可视化管理：哪些 MCP server 开启、连接健康状态。
- 大脑侧 Chat（F2，默认也用 Claude）同样作为 MCP host 调用这些能力。

## 5. 安全
- Claude Code 的工具权限由其自身机制管理；Helm 仅负责在选定项目目录里启动它。
- Helm 注入的 MCP server 仅绑 `127.0.0.1`，凭据走钥匙串（F0）。
- 修改 Claude Code 配置一律「合并 + 备份」，不破坏用户已有设置。

## 6. 观测与回放（与 F1 协同）
- Claude Code 在终端的产出 → 通过**文件监听**（watchdog）+ 解析会话日志，重建「改了哪些文件 / 触发哪些 skill」→ 驾驶舱仪表盘 / 变更收件箱 / 会话回放（F1）。

## 7. 数据模型（关联 F0）
- `agent_runs(id, kind='cli', session_id, project_path, agent='claude-code', status, ...)`
- `mcp_servers(id, name, transport, target, enabled, exposed_to_json)`
- （内置 agent 相关的 `tool_calls` 表本期不需要；恢复内置 agent 时再补，见归档。）

## 8. 用户故事
- 作为用户，我在终端跑 `claude`，它能通过 MCP 查到我在 Helm 里存的记忆和 RAG 文档。
- 作为用户，我能在设置里一键把「记忆/RAG」MCP 开放给 Claude Code，无需手动编辑配置文件，且不破坏我已有配置。
- 作为用户，Claude Code 改了文件后，驾驶舱立即高亮并能 diff。
- 作为用户，我能从某项目「续上」上次的 Claude Code 会话（`claude --resume`，见 F1）。

## 9. 验收标准
- [ ] 终端里的 Claude Code 能成功连接 Helm 的 MCP server 并调用一次记忆查询。
- [ ] Helm 写入 Claude Code 的 MCP 配置为「合并 + 备份」，不覆盖用户原有项。
- [ ] MCP server 的启停在设置里即时生效（无需重启 App）。
- [ ] Claude Code 改文件后，驾驶舱 < 500ms 反映改动并可 diff。

## 10. 依赖与风险
- 依赖 F1（终端/观测）、F4（被调用的 MCP 能力）、F0（安全/存储）。
- **范围更小、风险更低**：砍掉内置 agent 后，无需重写 Odysseus 的 Python 工具集，也无内置 agent 的工具安全边界问题；核心风险仅剩"安全地合并 Claude Code 的 MCP 配置"。
- 后续若需"无终端的后台自动化 agent"（如定时任务自动改文件），再评估恢复内置 agent（设计见归档）。
