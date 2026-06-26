# Loop Report · memory-rag-skills · m3

> 档位:🌙 放手模式。本轮为 `memory-rag-skills` 第 3/7 个 milestone（Round 3）。首次触及前端。

## 目标

`memory-rag-skills` / **m3 — 记忆 JSON 导入/导出 + 前端记忆面板**。
满足 constraint 463c14ca（记忆须支持 JSON 导入/导出），并交付 intent#1 的**用户可见**切片：
在 workspace-layout 外壳的 `memory` 模式里挂一个可用的记忆面板。非末个 milestone。

## 做了什么

**后端（JSON 导入/导出）**
- **`helm/memory/service.py`**（改）：`export_all()` → 全量 public dict；`import_entries(entries,
  replace=False)` → 逐条 create（忽略传入 id、重建向量索引、跳过空 text 行），`replace=True` 先清空。
- **`helm/memory/routes.py`**（改）：`GET /api/memories/export`（`{version:1, memories:[…]}`）、
  `POST /api/memories/import`（`{memories, replace}`）。静态路由排在 `/{memory_id}` 之前。
- **`tests/test_memory.py`**（改）：+2 测——export/import round-trip（pinned/tags 保真）、
  replace 清空 + 跳过空行。

**前端（记忆面板，首次触及前端）**
- **`frontend/src/lib/memory/memoryStore.svelte.ts`**（新增）：runes store，镜像 chatStore 的
  容错 `#json`。`load/setFilter/add/remove/togglePin/search/clearSearch/exportJSON/importJSON`。
  搜索结果（`results`）与浏览列表（`items`）分开存，搜索时不丢浏览态。
- **`frontend/src/lib/memory/Memory.svelte`**（新增）：面板——添加（文本 + 分类）、关键词/语义搜索、
  分类筛选（全部/fact/preference/decision）、置顶切换、删除、导出（Blob 下载，jsdom 守卫）、
  导入（文件读取）。
- **`frontend/src/lib/Shell.svelte`**（改）：`memory` 模式接 `<Memory/>`（此前落到通用 tab 占位）。
- **`frontend/src/lib/memory/{memory,MemoryView}.test.ts`**（新增）：store 单测 7 + 组件渲染 3 = 10。

## 决策（record_decision）

- **decision `e7f4f02b`**（ai_proposed）：导入/导出语义 + 前端面板。可逆语义决定——导入默认
  **append**（`replace=true` 才清空，避免误导入抹掉记忆）、**忽略传入 id**（防冲突）、空行跳过、
  导入重建向量索引。`replace` 清空是显式 opt-in 的破坏性操作（备份恢复），非猜测。
- 无难撤产品 OQ，无 `[needs-human]`。

## VibeHub / MCP 交互

**pull**：承接前两轮 context。本轮读了前端外壳源码（Shell/Rail/layout/chatStore）定面板挂载方式。
**write**：
- `record_decision` "m3 记忆 JSON 导入/导出…"（`e7f4f02b`，ai_proposed）。
- `create_ticket` "[perf] Monaco editor chunk 3.6MB 代码分割"（`8299f9b6`，bound→cockpit，low）。

## Hooks / 自动化

- `commit-sync`：本轮提交走流程。
- CI（`ci.yml`）：本轮改动触及后端 + 前端两 job；本地已跑 backend pytest / frontend vitest /
  svelte-check / build 全绿，等 Room 收尾合 main 时 CI 复核。
- cron/loop：`2dc539c2`，Round 3。

## defer

- [perf] Monaco chunk ticket（`8299f9b6`，cockpit）——非本 Room 范围，记 issue 不硬改。

## 优化

- **后端**：import 逐条复用 `create`（自动走向量索引同步），无重复逻辑；空行跳过避免整批失败。
- **前端**：search 结果与 items 分离避免搜索清空浏览态；导出/导入复用同一 `#json` 容错路径；
  Blob 下载与文件读取均为浏览器侧副作用，jsdom 下守卫不参与单测。

## 验证

- 后端 `pytest` → **85 passed, 1 skipped**（含 m3 +2）。
- 前端 `vitest`（全量）→ **85 passed**（含 memory 10）。
- 前端 `svelte-check` → **0 errors / 0 warnings**（修了 1 处 mock 签名类型错）。
- 前端 `npm run build` → **built ok**（遗留 Monaco 大 chunk 警告已建 ticket，非本轮引入）。
- 人工目视项：记忆面板的实际渲染/交互未做 GUI 目视（组件测试已 headless 覆盖渲染 + 添加流程）。

## review

自审 + svelte-check 当 reviewer：
- svelte-check 报 4 处类型错（memory.test.ts mock 单参签名 → `c[1]` 不存在）→ **当场修**
  （mock 加 `_init?: RequestInit`），复跑 0 错。
- 路由顺序 export/import 在 `/{id}` 前 —— 已确认。
- 导入忽略传入 id、重建索引 —— round-trip 测试覆盖。
- 未发现其它真 bug。

## 熔断状态

未命中熔断。本轮一个验证失败（svelte-check 类型错）属"测试/构建失败"，但**首次即修复通过**，
未达"连续 2 次"，按流程当场修干净，未触发放手模式的"转 ticket 绕行"。

## 下一步

`memory-rag-skills` / **m4 — RAG 文档索引（本地目录 PDF/Office/Markdown/代码 → ChromaDB）+ 检索 API**
（intent#2 后端）。Room 未收尾，继续。
