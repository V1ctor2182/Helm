# Loop Report · memory-rag-skills · m1

> 档位:🌙 放手模式(整夜跑)。本轮为 `memory-rag-skills` Room 的第 1 个 milestone(共 7 个,见 milestone 计划 decision `2cb56d3b`)。

## 目标

`memory-rag-skills` / **m1 — 记忆数据模型 + CRUD + 关键词检索 REST API**。
Room 的第 1/7 个 milestone(非末个)。交付 intent#1「持久记忆 + CRUD」的可验证后端切片,
**不引入** fastembed/ChromaDB 重依赖(向量/混合检索留到 m2),保证本轮即可 headless 验证。

本轮也顺带做了一项**基础设施修复**:把上一阶段做好但未合入 main 的「放手模式方法论文档」
合进了 main(否则每个 Room 分支从 main 切出后读到的是旧流程文档)。

## 做了什么

新建 `helm/memory/` Room 包,沿用既有 `chat/`、`cockpit/` 的 models/service/routes 三件套约定:

- **`helm/memory/__init__.py`**(新增):Room 包说明 + milestone 路线注释。
- **`helm/memory/models.py`**(新增):`Memory` ORM 表 —— `id / text / category / source /
  session_id / tags_json / uses / pinned / created_at / updated_at`。字段形状对齐 Odysseus
  memory entry,但落 platform-shell 的 SQLite(constraint 8ace2b3a)。`session_id` 取
  **nullable String**(非 FK 到 `chat.sessions`),避免 memory 跨 Room 硬耦合 chat。
- **`helm/memory/service.py`**(新增):`MemoryService`(list/get/create/update/delete/
  search/touch)+ `tokenize`/`keyword_similarity`(从 Odysseus `src/memory.py` 移植的
  Jaccard token 相似度)+ `memory_public` 序列化 + `CATEGORIES` 软校验集。
- **`helm/memory/routes.py`**(新增):`/api/memories` REST —— GET 列表(category/pinned 过滤)、
  POST 创建、GET `/search`(关键词排序)、GET/PATCH/DELETE `/{id}`。`/search` 注册在 `/{id}` 之前。
- **`helm/app.py`**(改):import + `include_router(memory_router)`(顺带在 routes 导入时把
  `memories` 表注册到 `Base.metadata`,沿用既有「import router 即注册模型」机制)。
- **`tests/test_memory.py`**(新增):7 个测试,覆盖 CRUD、404、输入校验、category/pinned 过滤
  与排序、关键词检索排序、`keyword_similarity` 单元、`touch` recall 计数。

## 决策(record_decision)

本轮自决均为**技术决策**(放手模式下自己定 + 分级留痕),无难撤产品决策需暂定。

1. **milestone 拆分计划**(decision `2cb56d3b`,ai_proposed):7 个垂直切片,见下「VibeHub 交互」。
2. **`session_id` 不设 FK 到 chat.sessions**(低风险技术,保守解):memory 是平台能力,被多个
   Room 复用,硬 FK 到 chat 会形成跨 Room 耦合(高风险跨 Room 契约)。取 nullable String 自由引用,
   未来若需强关联再加。依据:METHODOLOGY 跨 Room 抽象保守原则 + 已有 chat 用 int PK 不通用。
3. **m1 关键词检索在 Python 端打分**(低风险):单用户本地库,memories 表小,`list()` 全量
   + Python Jaccard 排序够用;m2 用 ChromaDB ANN 取代。已在 service docstring 写明。
4. **复用 Odysseus tokenize/get_text_similarity**(依据 constraint 8ace2b3a 复用 Odysseus 栈):
   逐字移植 `src/memory.py` 的两个函数,保证 recall 语义与源一致。

> 本轮无高风险技术决策(未碰数据迁移以外的 schema 风险、无对外 MCP 契约、无安全边界改动)。
> 新建表属本 Room 自有 schema,non-breaking。

## VibeHub / MCP 交互

**pull(读 context)**
- `get_feature_context(memory-rag-skills)` → 读到 4 intent(记忆/RAG/MCP 能力层/Skills 透视)+
  3 constraint(复用 Odysseus 栈、本地优先、JSON 导入导出)+ 1 条 ai_proposed decision(MCP client
  4 传输+OAuth,参考 AionUi)。据此定 m1 范围与 Room 整体拆分。

**write(留痕)**
- `record_decision` "放手模式新增档位"(`8dd20f44`,ai_proposed)— 上一阶段方法论。
- `record_decision` "memory-rag-skills milestone 拆分"(`2cb56d3b`,ai_proposed)。
- `create_ticket` "[tech-debt] Starlette TestClient 弃用 httpx"(`f029e4e5`,bound→dev-infra,
  priority low,github_synced)。

## Hooks / 自动化

- `commit-sync`:本轮提交走 feature-room commit-sync 流程(无本地 meta/,specs 在 VibeHub 服务端)。
- CI(`.github/workflows/ci.yml`):backend(pytest)/desktop/frontend 三 job,在 Room PR→main 时触发;
  本轮只在 feature 分支,CI 未触发(Room 收尾合 main 时才跑)。
- `.vibehub/vibehub-hook.mjs`:文件改动 hook(被动)。
- cron/loop:`/loop 5m` 放手模式(job `2dc539c2`),本轮为手动触发的第 1 轮。

## defer

无难撤产品 OQ 暂定,无 `add_question`。唯一推迟项是上面的 [tech-debt] ticket(httpx2 迁移,
属 dev-infra,非本 Room 范围)。

## 优化

- **后端**:`search` 全量加载 + Python 打分 —— m1 单用户本地库规模下不优化(m2 ChromaDB 取代,已注释)。
- **前端**:本轮纯后端,无前端改动。

## 验证

- `pytest tests/test_memory.py` → **7 passed**。
- `pytest`(全量后端)→ **77 passed**(此前 71 + 新增 6;含 touch 的第 7 个为 service 级)。
- 手验 POST 响应 `created_at`/`updated_at` 正确填充(server_default flush 后回读)。
- 无 GUI/人工目视项(纯后端 API,全部 headless 可断言)。

## review

自审(放手模式逐 milestone review):
- 路由顺序 `/search` 在 `/{id}` 前 —— 已确认,且 `{id}` 为 int 路径不会吞 "search"。
- server_default 时间戳在 commit 前经 flush+expire 回读填充 —— 手验通过,非 None。
- `touch()` 原未经测试 → **当场补 `test_memory_touch_bumps_uses`**(含 None 分支)。
- 未发现真 bug,无需 fixup。

## 熔断状态

未命中任何熔断条件(测试一次过、无打转、无越界、无 defer 堆积)。放手模式下本轮也无需"转 ticket 继续"。

## 下一步

`memory-rag-skills` / **m2 — 记忆向量检索(ChromaDB + fastembed ONNX 混合检索)+ recall 计数**。
需引入 chromadb / fastembed 依赖(constraint 8ace2b3a),把 `search` 升级为关键词+向量混合,
并把 `touch` 接到 recall 路径。Room 未收尾,继续下一个 milestone。
