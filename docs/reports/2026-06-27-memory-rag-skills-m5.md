# Loop Report · memory-rag-skills · m5

> 档位:🌙 放手模式。`memory-rag-skills` 第 5/7 个 milestone（Round 5）。

## 目标

`memory-rag-skills` / **m5 — RAG 前端（文档源管理 + 检索 UI）**（intent#2 UI）。
把 m4 的 RAG 后端接到 workspace-layout 外壳，让用户能注册文档源、看索引状态、语义检索。非末个。

## 做了什么

- **`frontend/src/lib/rag/ragStore.svelte.ts`**（新增）：runes store，镜像 memoryStore `#json`。
  `load`(sources+stats)/`addSource`(带 `busy` 守同步索引)/`removeSource`/`reindex`/`search`/`clearSearch`。
- **`frontend/src/lib/rag/Rag.svelte`**（新增）:知识库面板——统计条(源/文件/块,向量关时提示)、
  添加源(路径输入,索引中禁用)、源列表(路径 + 状态徽章 + 计数 + 重索引/删除)、语义检索 + 结果片段(path+score+snippet)。
- **`frontend/src/lib/memory/BrainPanel.svelte`**（新增）:`memory` 模式下的分段控件【记忆 | 知识库】,
  在 Memory 与 Rag 间切换——RAG 与记忆同属本 Room,共用一个 Rail 槽,不占用 deep-research 的 `research` 模式。
- **`frontend/src/lib/Shell.svelte`**（改）:`memory` 模式由 `<Memory/>` 改挂 `<BrainPanel/>`。
- **`frontend/src/lib/rag/{rag,RagView}.test.ts`**（新增）:store 单测 4 + 组件/切换渲染 3 = 7。

## 决策（record_decision）

- 可逆产品小决定(放手模式自决,UI 组织):RAG UI 挂在 `memory` 模式内、用分段控件与记忆并列,
  而非占用 `research` 模式(留给 deep-research Room)。改回只需调 Shell 一处。**未单独 record**——
  纯 UI 归属、可逆,按分级留痕属"一句话"级,记于本 report + 代码注释(BrainPanel.svelte)。
- 无难撤产品 OQ,无 `[needs-human]`。

## VibeHub / MCP 交互

**pull**：读前端外壳(Shell/layout/memoryStore)确认挂载点与 store 模式;确认无 Shell 渲染测试会因
改 memory 模式而破。
**write**：本轮无新 decision/ticket（m5 是 m4 的 UI 接线,无新增技术分歧;同步索引 UX 缺口已由
m4 的 ticket `7842c722` 覆盖,不重复建）。

## Hooks / 自动化

- `commit-sync`：本轮提交走流程。
- CI：本轮触及前端;本地 vitest / svelte-check / build 全绿。
- cron/loop：`2dc539c2`，Round 5。

## defer

- 无新 defer。native 目录选择器(替代手输路径)属桌面壳增强,价值低、暂不建 ticket。

## 优化

- **前端**:results 与 sources 分开渲染(检索态不丢源列表);addSource/reindex 用 `busy` 防重复提交并
  给"索引中…"反馈;复用 memoryStore 的 `#json` 容错形态,零新网络样板。
- **后端**:本轮无后端改动。

## 验证

- 前端 `vitest`（全量）→ **92 passed**（含 rag 7）。
- 前端 `svelte-check` → **0 errors / 0 warnings**（修了 1 处 mock 签名类型错,同 m3 模式）。
- 前端 `npm run build` → **built ok**（遗留 Monaco 大 chunk 警告,已建 ticket `8299f9b6`）。
- 后端 `pytest` → **93 passed, 1 skipped**(无回归)。
- 人工目视项:面板实际外观未做 GUI 目视(组件测试已覆盖渲染/切换/检索结果 headless)。

## review

自审 + svelte-check 当 reviewer:
- svelte-check 报 2 处类型错(rag.test.ts reindex mock 单参签名)→ **当场修**,复跑 0 错。
- BrainPanel 切换默认 memory 视图;Rag 空态/源列表/检索结果三态都测到。
- 改 Shell memory 模式不破已有测试(无 Shell 渲染测试,App.test 只查 rail/状态)。
- 未发现其它真 bug。

## 熔断状态

未命中熔断。一次 svelte-check 失败首次即修复,未达"连败 2 次"。

## 下一步

`memory-rag-skills` / **m6 — MCP 能力层 server(把 memory/RAG 暴露给终端 Claude Code)**(intent#3)。
⚠ 高风险对外契约(MCP 工具签名),record 写满 + add_constraint + report 置顶。Room 未收尾,继续。
