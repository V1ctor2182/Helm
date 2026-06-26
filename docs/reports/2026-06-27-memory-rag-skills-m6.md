# Loop Report · memory-rag-skills · m6

> 档位:🌙 放手模式。`memory-rag-skills` 第 6/7 个 milestone（Round 6）。

## ⚠️ 高风险对外契约（置顶，需你 dashboard 审计）

本轮定了一条**暴露给终端 Claude Code 的 MCP 工具契约**——这是高风险技术决策（对外契约）。
放手模式下 loop 自决，但已**写满 record_decision + 立 add_constraint**，请优先在 dashboard 审。

- **decision `e02ac069`**（ai_proposed）:架构 + 4 工具契约 + 备选权衡(见下)。
- **constraint `ca4b5e64`**（ai_proposed):4 个工具名/参数**稳定不可改名改义,扩能力只新增工具**;
  MCP server 必须保持**无状态桥接**(经后端 REST,不直接开 SQLite/Chroma)。

**契约(稳定)**:`helm_memory_search(query,limit)` / `helm_memory_add(text,category)` /
`helm_memory_list(category?)` / `helm_rag_search(query,limit)`。

**若你不认可**:改 `helm/mcp/server.py` 的工具定义即可回滚(stdio server 尚未被任何 agent 正式接入,
.mcp.json 未提交)。

## 目标

`memory-rag-skills` / **m6 — MCP 能力层 server**（intent#3）。把记忆/RAG 暴露为 MCP server,
终端 Claude Code 能直接读用户的 Helm 记忆与 RAG 文档。非末个(后面还有 m7 Skills 透视)。

## 做了什么

新建 **`helm/mcp/`** 包:

- **`client.py`**（新增）:`HelmClient` —— 调本机后端 REST 的薄客户端(memory_search/list/add、
  rag_search);base_url 由 HelmConfig 派生(`HELM_BASE_URL` 可覆盖)。可注入 `httpx.Client`
  (测试塞 TestClient → in-process headless)。
- **`server.py`**（新增）:`build_server(client?)` 用 FastMCP 注册 4 工具(类型注解自动生成 schema);
  `_safe` 把 httpx 传输错转成可读"backend unreachable"文案;`main()` 跑 stdio。
- **`__main__.py`**（新增）:`python -m helm.mcp` 入口。
- **`pyproject.toml` / `requirements.txt`**（改）:+`mcp`(1.28.1);console script `helm-mcp`。
- **`tests/test_mcp.py`**（新增）:5 测——client round-trip、rag 空、**工具契约(名+schema)**、
  工具执行、后端不可达降级。

## 决策(record_decision)

见顶部。**备选权衡**(decision `e02ac069` 全文):
- A(选中)stdio→REST 桥接:后端是 DB/Chroma 唯一属主,不与 agent 争锁;复用 REST 单一真相源。
- B 直连 import service(同 Odysseus):弃——两进程同开 Chroma 持久目录可能互锁 + 双写风险。
- C FastAPI 内挂 MCP-over-HTTP/SSE:可行但需 url+鉴权;stdio command 对本地单用户更简、零鉴权面。
  未来要远程可再加 HTTP transport 并存。

**跨 Room 边界**:本 Room 拥有 memory/RAG 工具表面;通用 agent↔MCP 接线/沙箱/权限属
`agent-orchestration` Room,本轮不碰。

## VibeHub / MCP 交互

**pull**:读 Odysseus `mcp_servers/memory_server.py`、`rag_server.py`(工具语义)+ 本仓库 `.mcp.json`
(Claude Code MCP 配置范式)+ HelmConfig(host/port)。
**write**:
- `record_decision`（`e02ac069`,ai_proposed,高风险置顶）。
- `add_constraint`（`ca4b5e64`,ai_proposed,工具契约稳定 + 无状态桥接）。
- 无新 ticket(无遗留缺口)。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:本轮纯后端;本地 `pytest` 全绿。MCP stdio 传输本身(`main()`)未进 CI(标 pragma no cover),
  契约/逻辑/降级均经 in-process 测试覆盖。
- cron/loop:`2dc539c2`,Round 6。

## defer

无。`.mcp.json` 含密钥(gitignored)未提交;接入 helm MCP server 的配置片段写在 server.py docstring。

## 优化

- **后端**:client/server 分离使工具逻辑可注入 TestClient 测、零真 socket;`_safe` 统一传输错降级;
  共用一个 HelmClient 整个 server 生命周期。
- **前端**:本轮无前端。

## 验证

- `pytest tests/test_mcp.py` → **5 passed**。
- `pytest`(全量后端)→ **98 passed, 1 skipped**(m5 93 → +5)。
- entrypoint smoke:`build_server()` 注册 4 工具、`main` 可调用。
- 人工目视项:未在真实 Claude Code 里实际挂载 stdio server 联调(需终端环境;契约/逻辑已 headless 覆盖,
  实际 agent 接入待人工或 agent-orchestration Room 联调)。

## review

自审:
- 工具契约测试锁定名+required schema,防未来误改(契约稳定性有测试兜底)。
- 后端不可达:`_safe` 捕获 httpx.HTTPError(含 ConnectError)→ 可读文案,测试覆盖。
- 一处测试用 `asyncio.get_event_loop().run_until_complete`(py3.13 报无 loop)→ **当场改**为
  `@pytest.mark.anyio` async 测,复跑通过。
- 无状态桥接确保不与后端争 DB/Chroma 锁(架构层规避)。

## 熔断状态

未命中熔断。一次测试失败(事件循环 API)首次即修复,未达连败 2 次。

## 下一步

`memory-rag-skills` / **m7 — Skills 透视(列出本机 agent skills + 触发统计 + 健康检查 + 启停)**
(intent#4,Room 最后一个 milestone)。做完进入 **Room 收尾**:限额 drain 技术 backlog → 前后端优化扫描
→ 全量验证 → room-status → 全绿自动合 main。
