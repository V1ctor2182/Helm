# Loop Report · memory-rag-skills · m4

> 档位:🌙 放手模式。`memory-rag-skills` 第 4/7 个 milestone（Round 4）。

## 目标

`memory-rag-skills` / **m4 — RAG 文档索引（本地目录 PDF/Office/Markdown/代码 → ChromaDB）+ 检索 API**
（intent#2 后端）。复用 m2 的 Embedder/Chroma 栈，新增独立的 RAG 能力。非末个 milestone。

## 做了什么

新建 **`helm/rag/`** 独立包（与 `helm/memory/` 平级，同属本 Room）：

- **`extract.py`**（新增）：`extract_text`（text/code/markdown 直读；PDF→pypdf、docx→python-docx，
  库缺/解析失败优雅返回 None）；`iter_files`（walk 目录、跳过 `.git`/`node_modules`/`.venv` 等噪声）；
  `chunk_text`（~1000 字 / 150 重叠，优先在窗口后半换行处断开）；`is_supported`。
- **`models.py`**（新增）：`RagSource` 表（path/kind/status/file_count/chunk_count/error/indexed_at）。
  chunk 向量只进 Chroma，SQLite 只存源注册 + 状态。
- **`vector.py`**（新增）：`RagVectorStore` —— 独立 collection `helm_rag`，存 chunk document + metadata
  （source_id/path/chunk），`query` 返回 path+text+score，`delete_source` 按 `where={source_id}` 删，
  `healthy` 优雅降级。
- **`service.py`**（新增）：`RagService` —— add/list/remove/reindex source + search + stats；
  `_index` 即使无向量库也统计 chunk 数（注册表在 keyword-less 模式仍有意义）。
- **`routes.py`**（新增）：`/api/rag/sources` CRUD + `/{id}/reindex` + `/search` + `/stats`。
- **`helm/app.py`**（改）：构造**一个**共享 `FastEmbedEmbedder` 同时喂 memory + rag 两个 store
  （镜像 Odysseus 共享 EmbeddingClient），同受 `HELM_MEMORY_VECTORS` 门控；加 `get_rag_vectors` 依赖 + 挂 router。
- **`pyproject.toml` / `requirements.txt`**（改）：+`pypdf`、`python-docx`。
- **`tests/test_rag.py`**（新增）：8 测——提取/支持判定、iter_files 跳噪声目录、chunk 窗口、
  add_source 索引目录 + 语义检索、remove 删 chunk、reindex 重建、API（vectors-off 仍注册计数、404）。

## 决策（record_decision）

- **decision `1e5cb361`**（ai_proposed）：helm/rag 包结构 + 共享 embedder + helm_rag collection +
  检索 API。全技术决策，依据 Odysseus rag_manager/rag_vector + constraint 8ace2b3a。chunk 参数 /
  文件类型清单为可逆技术调参。
- 无难撤产品 OQ，无 `[needs-human]`。

## VibeHub / MCP 交互

**pull**：读 Odysseus `src/document_processor.py`、`rag_manager.py` 定 RAG 接口与提取策略。
**write**：
- `record_decision`（`1e5cb361`，ai_proposed）。
- `create_ticket` "[perf] RAG 同步索引大目录阻塞 → 后台索引"（`7842c722`，bound→memory-rag-skills，medium）。

## Hooks / 自动化

- `commit-sync`：本轮提交走流程。
- CI：本轮纯后端；本地 `pytest` 全绿，等 Room 收尾 CI 复核。
- cron/loop：`2dc539c2`，Round 4。

## defer

- [perf] 后台索引 ticket（`7842c722`，本 Room，medium）——留待 m5/收尾 drain，不阻塞本轮。

## 优化

- **后端**：memory + rag 共享一个 embedder 实例（省一份 ONNX 模型内存）;`_index` 异常兜底置
  source.status=error 不炸整请求;iter_files 跳过 vendored/缓存目录避免索引垃圾;chunk 边界对齐换行。
- **前端**：本轮纯后端。

## 验证

- `pytest tests/test_rag.py` → **8 passed**。
- `pytest`（全量后端）→ **93 passed, 1 skipped**（m3 85 → +8）。
- **真 fastembed RAG 路径**：内联 smoke（模型已缓存）—— "feline resting in sunlight" 命中
  `animals.md`、score 0.738、语义排序正确。
- 无 GUI/人工目视项（纯后端 API；PDF/docx 解析为优雅降级路径，二进制格式深测未做——文本/代码/md 全测）。

## review

自审：
- chunk id `{source_id}:{path}:{i}` 唯一;reindex 先 delete_source 再重建，无残留。
- vectors-off 时注册/计数仍工作、search 返回 [] 不报错 —— API 测试覆盖。
- 共享 embedder 不引入耦合（仅 embed 接口）。
- 未发现真 bug，无 fixup。

## 熔断状态

未命中熔断。本轮无失败/打转/越界。

## 下一步

`memory-rag-skills` / **m5 — RAG 前端（文档源管理 + 检索 UI）**（intent#2 UI，挂 workspace-layout
`research` 或 `memory` 区）。Room 未收尾，继续。
