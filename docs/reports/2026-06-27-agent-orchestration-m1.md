# Loop Report · agent-orchestration · m1

> 档位:🌙 放手模式。新 Room `agent-orchestration` 第 1 个 milestone（Round 8）。

## 目标

`agent-orchestration` / **m1 — MCP 配置注入**（intent#2,并启用 intent#1）。
把 Helm 的 MCP server(memory-rag-skills m6 已建)合并写入 Claude Code 的 `.mcp.json`,
让终端 Claude Code 能读用户的记忆/RAG —— 用户无需手动编辑配置文件。非末个。

## 做了什么

新建 **`helm/orchestration/`** 包:

- **`mcp_config.py`**（新增）:
  - `helm_server_spec()` → `{command: sys.executable, args: [-m, helm.mcp]}`(同解释器,免 PATH 依赖)。
  - `inject(path, enabled)` → **合并**写入/移除 `mcpServers.helm`,保留其它 server 与无关键;
    首次修改前**备份**原文件到 `<path>.helm-backup`(只备一次,不覆盖原始)。enabled=False 移除条目(启停)。
  - `status(path)` → 是否已注入 + 是否存在 + 错误。
  - 恶意/损坏 JSON:`_load` **抛错而非清空**,绝不 clobber 无法解析的配置。
- **`routes.py`**（新增）:`GET /api/orchestration/mcp`(status)、`POST /api/orchestration/mcp`
  ({config_path?, enabled});损坏配置 → 400。
- **`helm/app.py`**（改）:挂 orchestration router。
- **`tests/test_orchestration.py`**（新增）:8 测——spec、合并保留、缺文件创建、停用只删 helm 条目、
  备份只备一次、status、损坏配置拒绝不 clobber、路由(含 400)。

## 决策(record_decision)

- **decision `6820a48c`**（ai_proposed）:Room MVP milestone 拆分(Claude Code only)+ m1 技术决策。
- m1 内技术决定(放手模式自决):注入命令用 `sys.executable -m helm.mcp`(最稳健);默认目标
  项目级 `.mcp.json`(`HELM_CLAUDE_MCP_CONFIG` 或路由 config_path 可覆盖);备份只备首次原始。
- **无难撤产品 OQ**:Room 方向(v1 Claude Code only、配置合并+备份)已由用户 2026-06-25 拍板 +
  decisions b199f333/76961005 收口,开放问题 ebe186b6 已解。**0 条 `[needs-human]`**。

## VibeHub / MCP 交互

**pull**:`get_feature_context(agent-orchestration)` → 3 intent + 4 constraint + 6 条 ai_proposed 决策
(ACP 层 bf5dc16b、Team 模型 0b2df71d、收口 b199f333、收窄 constraint 76961005、open question ebe186b6)。
据此定 MVP 边界 = Claude Code only,本 Room 是「注入+观测」侧(server 已在 m6 建)。
**write**:`record_decision`（`6820a48c`,milestone 拆分,ai_proposed）。无新 ticket。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:本轮纯后端;本地 `pytest` 全绿。
- cron/loop:`2dc539c2`,Round 8(memory-rag-skills 已合 main 后的首个新 Room milestone)。

## defer

- **设置 UI 启停开关**:constraint ae70bc36「启停须设置里即时生效」的后端已就位(toggle 即时重写配置);
  但本仓库尚无独立 Settings 面板(`settings` 模式目前落通用 tab,属 workspace-layout),故 UI 开关
  待 Settings 面板出现或本 Room m4(驾驶舱/设置)时接。非 backlog 债,是计划内 UI 工作。

## 优化

- **后端**:合并语义(setdefault + 仅动 helm 键)天然保留用户配置;备份只备一次避免覆盖原始;
  损坏配置抛错而非猜——把"不可逆破坏"(clobber 用户配置)挡在门外。
- **前端**:本轮无前端。

## 验证

- `pytest tests/test_orchestration.py` → **8 passed**。
- `pytest`（全量后端）→ **110 passed, 1 skipped**(memory-rag 合并后基线 + 本轮 +8)。
- 人工目视项:未在真实 Claude Code 里实测注入后能否读 Helm 记忆(需终端联调;注入/合并/备份逻辑已 headless 全覆盖)。

## review

自审:
- 合并保留其它 server + 无关键、备份只备一次、停用只删 helm —— 均有测试。
- 损坏 JSON 拒绝且文件原样保留(防 clobber)—— 有测试。
- 注入命令同解释器,免装 console script 也能跑。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。

## 下一步

`agent-orchestration` / **m2 — ACP 驱动层抽象 + agent_runs 数据模型**(decision bf5dc16b):
ACP 类型(session/new、session/update tool_call/plan/status、request_permission、session/close)+
adapter 抽象(多后端可扩展,仅实现 Claude Code parser)+ agent_runs 表。Room 继续。
