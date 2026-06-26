# Loop Report · memory-rag-skills · m2

> 档位:🌙 放手模式。本轮为 `memory-rag-skills` 第 2/7 个 milestone（Round 2）。

## 目标

`memory-rag-skills` / **m2 — 记忆向量检索（ChromaDB + fastembed ONNX 混合检索）**。
完成 intent#1「向量 + 关键词混合检索」的语义半边：把 m1 的纯关键词 recall 升级为
**向量 + 关键词混合**，复用 Odysseus 的 ChromaDB + fastembed 栈（constraint 8ace2b3a）。
非末个 milestone。

## 做了什么

- **`pyproject.toml` / `requirements.txt`**（改）：运行时依赖新增 `chromadb`、`fastembed`
  （constraint 8ace2b3a）。本地已 `pip install` 验证可装可导入（chromadb 1.5.9）。
- **`helm/memory/embedding.py`**（新增）：`Embedder` Protocol + `FastEmbedEmbedder`
  （默认 `BAAI/bge-small-en-v1.5`，**模型懒加载**——import/boot 不阻塞，首次 `embed()` 才下载）。
- **`helm/memory/vector.py`**（新增）：`MemoryVectorStore` —— Chroma `PersistentClient`
  持久化到 `<data_dir>/memory_vectors`，collection `helm_memories`，cosine 空间
  （similarity = 1 − distance）。`upsert/delete/query/count/reset` + `healthy` 标志，
  全程 try/except **优雅降级**（Chroma/embedder 起不来 → 退回纯关键词）。镜像 Odysseus
  `src/memory_vector.py` 的「预计算嵌入 + healthy 降级」模式。
- **`helm/memory/service.py`**（改）：`MemoryService` 接受可选 `vectors`；`create/update(仅
  text 变)/delete` 同步向量索引；`search` 改为**混合**——向量相似度与关键词 Jaccard 按
  `VECTOR_WEIGHT=0.7` 融合，无健康向量库时退回 m1 纯关键词语义。
- **`helm/app.py`**（改）：构建 `app.state.memory_vectors`（`HELM_MEMORY_VECTORS=0` 可关；
  构造廉价，模型懒加载）+ `get_memory_vectors` 依赖；memory 路由注入向量库。
- **`tests/conftest.py`**（改）：autouse fixture 把 `HELM_MEMORY_VECTORS` 置 0，保证 app 级
  测试纯关键词、**不下载模型**（headless）。
- **`tests/test_memory_vector.py`**（新增）：6 个测试 —— 确定性 `FakeEmbedder` + 真实
  ChromaDB（无网络）覆盖向量 roundtrip、混合检索语义命中（`automobile`→`car`，关键词为 0
  仍召回）、降级回退、update 重索引 / delete 移除、reset；外加 1 个 `HELM_TEST_EMBED=1`
  opt-in 的**真 fastembed** 集成测试。

## 决策（record_decision）

- **decision `63ac6ef9`**（ai_proposed）：m2 向量检索设计（Embedder 抽象 + ChromaDB 预计算嵌入 +
  懒加载 + 混合融合 + 优雅降级 + headless 测试策略）。全为技术决策，依据 constraint 8ace2b3a /
  182f1ae6 + Odysseus `src/memory_vector.py`。`VECTOR_WEIGHT=0.7` 为可逆 recall 调参。
- 无难撤产品 OQ，无 `[needs-human]`。

## VibeHub / MCP 交互

**pull**：本轮承接 Round 1 的 `get_feature_context` context（未重复拉取）。
**write**：
- `record_decision` "m2 记忆向量检索…"（`63ac6ef9`，ai_proposed）。
- `create_ticket` "[tech-debt] chromadb+fastembed 打包体积影响"（`b005c5de`，bound→platform-shell，low）。

## Hooks / 自动化

- `commit-sync`：本轮提交走流程。
- CI（`ci.yml` backend job）：将随 `pip install -e ".[dev]"` 安装 chromadb+fastembed（变重，约 +1–2min）；
  默认 gate **跳过**真 fastembed 测试（无模型下载），仍 headless。Room 收尾合 main 时触发。
- cron/loop：`2dc539c2`，本轮 Round 2。

## defer

- [tech-debt] 打包体积 ticket（`b005c5de`，platform-shell）——非本 Room 范围。
- 真 fastembed 语义路径默认不进 CI（模型下载非 headless），已用 opt-in 测试在本地验证；report 留痕。

## 优化

- **后端**：向量候选先用 Chroma ANN（`query`），关键词只在候选集 Python 打分；`update` 仅在 text
  变化时重索引（category/tags/pin 不动向量）。降级路径零额外开销。
- **前端**：本轮纯后端。

## 验证

- `pytest tests/test_memory_vector.py` → **5 passed, 1 skipped**。
- `pytest`（全量后端）→ **82 passed, 1 skipped**（m1 77 + m2 新增 5）。
- **真 fastembed 路径**：`HELM_TEST_EMBED=1 pytest …::test_real_fastembed_roundtrip` →
  **1 passed（14.97s）**，模型下载 + 嵌入 + Chroma roundtrip + 语义排序均正确。
  （注：本沙箱经 SOCKS 代理，需先 `pip install socksio` 才能下载模型；socksio 是环境项，未加入项目依赖。）
- 无 GUI/人工目视项。

## review

自审：
- 混合融合：向量+关键词并集打分，过滤 0 分；向量空/不健康 → 退回关键词 —— 测试覆盖。
- `reset()` 原未测 → **当场补 `test_vector_store_reset`**。
- app 默认开向量但构造廉价（模型懒加载）；测试关掉避免下载 —— 已验证 headless。
- 未发现真 bug，无 fixup。

## 熔断状态

未命中熔断。本轮一个**环境阻塞**（沙箱 SOCKS 代理挡住模型下载）按放手模式就地化解
（装 socksio 重试通过），未升级为 ticket/停下。

## 下一步

`memory-rag-skills` / **m3 — 记忆 JSON 导入/导出（constraint 463c14ca）+ 前端记忆面板**
（挂 workspace-layout 外壳）。Room 未收尾，继续。
