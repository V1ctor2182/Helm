# F5 · Agent 编排与工具（融合粘合层）

> 来源：新建（融合 FanBox 终端 agent + Odysseus 内置 agent/MCP）｜优先级：**P0**｜里程碑：M2（基础）/ M3（MCP 接通）
> 上级：[PRD 主文档](../00-PRD-Master.md)

这是把「驾驶舱」和「大脑」真正接到一起的粘合层：管理两类 agent，并用 **MCP** 把大脑能力喂给它们、用工具把它们的产出落到文件系统。

---

## 1. 目标
- 统一管理两类 agent：
  1. **外部 CLI agent**（FanBox 路线）：在内嵌终端里跑 `claude` / `codex` / 任意命令。
  2. **内置 agent**（Odysseus 路线）：Helm 自带的、带工具（文件/shell/web）的 agent，用于 Chat 内的任务执行。
- 通过 **MCP** 让上述 agent 调用 Helm 大脑的能力（记忆 / RAG / 研究 / 生图…，见 F4/F3）。
- 让 agent 的产出（写文件、改代码）被驾驶舱实时观测（见 F1）。

## 2. 非目标
- 不重造 Claude Code / Codex 的能力；外部 agent 由其自身负责，Helm 只做宿主 + 能力注入 + 观测。

---

## 3. 两类 agent 的分工

| | 外部 CLI agent | 内置 agent |
|---|---|---|
| 跑在哪 | 内嵌终端（后端 pty，F1） | Python 后端（F0） |
| 适合 | 重度编程任务、长会话、`--resume` | Chat 内的轻任务、工具调用、与大脑深度联动 |
| 能力来源 | 自带 + Helm 注入的 MCP server | Helm 内置工具 + MCP |
| 观测 | 文件监听 + 会话日志解析（F1） | 工具调用事件直采 |

> 内置 agent 工具集**复用** Odysseus `src/agent_tools/`（Python）：`read_file` / `write_file` / `edit_file` / `glob` / `grep` / `bash` / `web_search`。

## 4. MCP 接通（融合核心）
- Helm 作为 **MCP host**：内置 agent 与大脑 Chat 通过 MCP client 调用 F4 暴露的 `memory` / `rag` 等 server。
- Helm 把这些 MCP server **注册给终端里的外部 agent**：
  - 自动生成/合并 Claude Code 的 MCP 配置（等价 `claude mcp add`），指向 Helm 暴露的 stdio/HTTP MCP server。
  - 对 Codex 做等价配置。
  - 结果：**在 FanBox 终端里跑 Claude Code，它能直接读你的 Helm 记忆 / RAG**。
- 设置里可视化管理：哪些 MCP server 开启、哪些 agent 可用、连接健康状态。

## 5. 工具与安全
- 内置工具（read/write/edit/glob/grep/bash）默认作用域限定在**当前选定的项目工作区**（对照 Odysseus 的 workspace 选择 + admin 限制；个人版简化为「明确选定的目录」）。
- `bash` / 写操作有可见性与（可选）确认；危险操作记录可回滚（与 F1 的 AI 整理回滚机制一致）。
- MCP 注入的 server 仅绑 127.0.0.1，凭据走钥匙串（F0）。

## 6. 观测与回放（与 F1 协同）
- 内置 agent 的每次工具调用 → 事件流 → 驾驶舱仪表盘/收件箱。
- 外部 agent → 通过文件监听 + 解析会话日志重建「改了哪些文件/触发哪些 skill」（对照 FanBox 的项目记忆/会话回放）。

## 7. 数据模型（关联 F0）
- `agent_runs(id, kind='cli'|'builtin', session_id, project_path, agent, status, ...)`
- `tool_calls(id, run_id, tool, args_json, result_meta, ts)`
- `mcp_servers(id, name, transport, target, enabled, exposed_to_json)`

## 8. 用户故事
- 作为用户，我在终端跑 `claude`，它能通过 MCP 查到我在 Helm 里存的记忆和 RAG 文档。
- 作为用户，我在 Chat 里让内置 agent 帮我改当前项目的某个文件，改动实时出现在驾驶舱并能 diff。
- 作为用户，我能在设置里一键把「记忆/RAG」MCP 开放给 Claude Code，无需手动编辑配置文件。
- 作为用户，agent 的 `bash`/写操作只能动我选定的项目目录。

## 9. 验收标准
- [ ] 终端里的 Claude Code 能成功连接 Helm 的 MCP server 并调用一次记忆查询。
- [ ] 内置 agent 调 `edit_file` 后，驾驶舱 < 500ms 反映改动并可 diff。
- [ ] MCP server 的启停在设置里即时生效（无需重启 App）。
- [ ] 内置工具越权访问工作区外路径被拒绝。

## 10. 依赖与风险
- 依赖 F1（终端/观测）、F4（被调用的 MCP 能力）、F2（内置 agent 用的 LLM）、F0（安全/存储）。
- 风险：自动改写外部 agent（Claude Code/Codex）的 MCP 配置需谨慎，避免破坏用户已有配置 —— 采用「合并而非覆盖 + 备份」策略。
