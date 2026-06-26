# Loop Report · deep-research · m4

> 档位:🌙 放手模式。`deep-research` 第 4 个 milestone（Round 15）。constraint e3f16816 点明的「本 Room 主要工作」。

## 目标

`deep-research` / **m4 — 报告前端视图**(intent#1 可视化 + constraint e3f16816「报告视图整合进驾驶舱前端」)。
`research` 模式面板:发起研究(连 /ws 看实时进度)+ 结构化带引用报告渲染。非末个(还剩 m5 喂 agent/写项目)。

## 做了什么

- **`frontend/src/lib/research/researchStore.svelte.ts`**（新增）:研究 WS 客户端。`handle` 纯 reducer
  (started/progress/done→openSession+loadSessions/error)可单测;`start` 用可注入 WebSocket;
  `loadProviders` 复用 chat `/api/providers` 选 provider+model;`openSession`/`loadSessions`/`stop`。
- **`frontend/src/lib/research/Research.svelte`**（新增）:问题输入 + provider/model 选择 + 开始/停止;
  运行时进度流;**报告视图**——摘要 + 关键结论(每 claim 来源 URL→`[n]` 编号引用链入来源列表)+
  来源有序表 + 迭代轮数;历史研究 details。
- **`frontend/src/lib/Shell.svelte`**（改）:`research` 模式接 `<Research/>`(此前落通用 tab)。
- **测试**:`research.test.ts`(reducer + start/stop/WS,6 测)+ `ResearchView.test.ts`(空态 / 带引用报告
  渲染([1][2]链对 / 来源)/ 进度流,3 测)。

## 决策(record_decision)

- **decision `db18b595`**（ai_proposed）:research 面板 + 引用渲染。技术+可逆 UI 决定。
- 引用把 claim.sources 映射为 report.sources 的 `[n]` 索引,直观可追溯(贴 constraint 180077c3)。
- 研究"可视化"取结构化+引用链;富图表属未来 polish 不进 MVP。**无难撤产品 OQ → 0 条 `[needs-human]`**。

## VibeHub / MCP 交互

**pull**:读 Shell research 模式渲染 + chatStore 的 provider 加载 + WS 客户端范式(chatStore/agentStore)。
**write**:`record_decision`（`db18b595`,ai_proposed）。无新 ticket。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:触及前端;本地 vitest/svelte-check/build + 后端 pytest 全绿。
- cron/loop:`2dc539c2`,Round 15。

## defer

- 富可视化(charts/图表):intent#1「可视化」当前取结构化+引用链满足;图表需 LLM 产结构化图数据,属未来 polish,未建 ticket(投机性)。
- 真实研究端到端目视:依赖 `[needs-human]` `3e4b06cf`(真 provider 跑)。

## 优化

- **前端**:handle reducer 与 WS 解耦可测;provider/model 复用 chat 既有 /api/providers(不重造);
  引用 `[n]` 索引复用 report.sources 顺序(零额外映射状态);进度流 + 报告 + 历史三态清晰。
- **后端**:本轮无后端。

## 验证

- 前端 `vitest`（全量）→ **114 passed**(含 research 9)。
- 前端 `svelte-check` → **0/0**(修了 1 处 progress 类型 cast,via unknown);`build` → ok。
- 后端 `pytest` → **142 passed, 1 skipped**(无回归)。
- 人工目视项:面板实际外观 + 真实研究流未 GUI 目视(reducer/渲染/引用链 headless 覆盖;真实流依赖 [needs-human])。

## review

自审:
- reducer:progress 累积、done→openSession+loadSessions、error —— 有测试。
- start:空问题/无 provider 拒绝;WS 发 {provider_id,model,question};stop 发 {type:'stop'} —— 有测试。
- 报告:摘要 + claims 的 [1][2] 引用链对应来源 url + 来源列表 —— 渲染测试。
- 一处 svelte-check 类型错(progress cast)**当场修**,via unknown 双重 cast。
- 无真 bug。

## 熔断状态

未命中熔断。一次 svelte-check 失败首次即修复,未达连败 2 次。

## 下一步

`deep-research` / **m5 — 报告喂 agent / 写项目**(intent#3,Room 末个 milestone):把报告结论/片段
导出给驾驶舱 agent(经 m6 已建的 memory 或直接 prompt)或写入项目文件。做完进入 Room 收尾。
