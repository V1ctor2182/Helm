# F4 · 记忆 / RAG / Skills（含 MCP 能力层）

> 来源：Odysseus（`memory*`, `rag_*`, `mcp_servers/`, skills）｜优先级：**P1**｜里程碑：M3
> 上级：[PRD 主文档](../00-PRD-Master.md)

复用 Odysseus 的「持久记忆 + 文档 RAG + Skills」（Python 原样保留，且**已是 MCP server**），让驾驶舱里的 agent（Claude Code/Codex）与大脑侧 Chat 都能调用。这是融合的「共享大脑」。

---

## 1. 目标
- **记忆**：跨会话、跨项目持久记忆（偏好、决策、事实），可增删查、可向量+关键词检索、可导入导出。
- **RAG**：把本地文档目录建索引，作为 Chat / Research / agent 的可检索知识。
- **Skills**：管理本机 agent skills（启停、健康检查、context 预算、触发统计）。
- **MCP 能力层**：把上述能力暴露为 MCP server，供任意 MCP client（终端 agent / 大脑 Chat）调用。

## 2. 非目标
- 不做云端同步（本地优先）；首版不做团队共享记忆。

---

## 3. 功能拆解

### 3.1 记忆（Memory）
- 数据：`{ scope（global/project/session）, text, source, embedding, created_at }`。
- 操作：list / add / edit / delete / search（向量 + 关键词混合检索）。
- **自动沉淀**：从对话/研究中提炼值得长期记的事实（可人工确认，借鉴 Odysseus 的记忆巩固 housekeeping）。
- 导入/导出 JSON。
- 对照 Odysseus：`memory.py` / `memory_vector.py` / `memory_server.py`。

### 3.2 RAG（文档检索）
- 增删「索引目录」；自动抽取文本（PDF/Office/Markdown/代码等）→ 分块 → embedding → 向量库。
- 检索：向量 + 关键词，返回带出处的片段。
- 对照 Odysseus：`rag_manager.py` / `rag_vector.py` / `personal_docs.py` / `rag_server.py`。

### 3.3 Skills 透视
- 列出本机所有 agent skills：触发统计、健康检查（描述截断/缺 frontmatter）、context 预算、不删文件的启停开关。
- 对照 FanBox 的「Skills X-ray」+ Odysseus 的 skills。

### 3.4 MCP 能力层（融合关键）
**直接复用 Odysseus 现有的 MCP server**（`memory_server` / `rag_server` / `email_server` / `image_gen_server`，已实现）：
- `memory`：list/add/edit/delete/search 记忆。
- `rag`：list/add_directory/remove_directory/search 文档。
- `email` / `image_gen`：按需启用。
- Helm 既是 **MCP host**（Chat 侧调用），也把这些 server 注册给终端里的 Claude Code/Codex（见 F5），实现「终端 agent 写代码时能查我的记忆/RAG」。

---

## 4. 存储与 embedding（关联 F0）
- **直接复用 Odysseus，无需替换**：
  - 结构化：SQLAlchemy + SQLite（记忆元数据 / 文档 / 分块）。
  - 向量：**ChromaDB**。
  - embedding：**fastembed(ONNX)**。
- 后端选 Python 的最大红利之一：记忆/RAG 这套成熟栈原样可用，**不需要 embedding 选型 spike**。

## 5. 数据模型
- `memories(id, scope, project_path?, text, source, embedding_id, created_at)`
- `documents(id, path, kind, indexed_at, ...)`
- `chunks(id, doc_id, ord, text, embedding_id)`
- 向量由 **ChromaDB** 管理（记忆与 RAG 各自的 collection）
- `skills(id, path, name, enabled, last_triggered, health_json)`

## 6. 用户故事
- 作为用户，我在 A 项目里告诉 agent 的偏好，在 B 项目里它也记得（global scope）。
- 作为用户，我把一个文档目录加进 RAG，之后 Chat/Research 都能引用它。
- 作为用户，**我在 FanBox 终端里跑 Claude Code 时，它能通过 MCP 查到我的记忆和 RAG 文档**。
- 作为用户，我能在一个视图里看到所有 skill 的健康度并启停。

## 7. 验收标准
- [ ] 记忆的向量+关键词混合检索返回相关结果，可增删改。
- [ ] 加一个目录到 RAG 后能检索到其中内容并给出出处。
- [ ] Helm 暴露的 `memory`/`rag` MCP server 能被 Claude Code 成功连接并调用。
- [ ] 记忆/设置可导出再导入还原。
- [ ] 删除数据目录即彻底清空（本地优先验证）。

## 8. 依赖与风险
- 依赖 F0（存储）、F5（把 MCP server 注册给终端 agent）。
- **低风险**：记忆 / RAG / MCP 均为 Odysseus 既有 Python 实现，原样复用；无 embedding 选型风险。
