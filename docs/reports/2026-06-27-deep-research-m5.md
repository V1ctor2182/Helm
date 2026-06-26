# Loop Report · deep-research · m5

> 档位:🌙 放手模式。`deep-research` 第 5/5 个 milestone（Round 16）—— **Room 最后一个 milestone**。

## 目标

`deep-research` / **m5 — 报告喂 agent / 写项目**(intent#3)。把研究报告导出到记忆(终端 agent 经 MCP 可读)
或写入项目 Markdown 文件。做完 Room 收尾。

## 做了什么

- **`helm/research/export.py`**（新增）:`report_to_markdown`(摘要 + claims 带 `[n]` 编号引用 + 来源链接 + 轮数)
  + `report_to_memory_text`(问题+结论一段)。
- **`helm/research/service.py`**（改）:`export_to_memory`(注入 MemoryService 建 `source=research` 记忆——
  终端 agent 经 m6 MCP 的 `helm_memory_search` 即可读到,闭合"喂 agent")+ `write_report_file`(写 Markdown 到 path,
  **文件已存在则拒绝覆盖**,不 clobber)。
- **`helm/research/routes.py`**（改）:`POST /{id}/export/memory`、`POST /{id}/export/file`(无报告→404,覆盖→400)。
- **前端**:`researchStore` 加 `exportToMemory`/`exportToFile`+`exportMsg`;`Research.svelte` 报告视图加
  「存入记忆」+「导出 Markdown 到项目」(路径 `cockpit.cwd/research-<id>.md`,无 cwd 禁用)+ 状态反馈。
- **测试**:后端 `tests/test_research_export.py` 5(markdown 编号引用 / 存记忆 / 写文件+拒覆盖 / 无报告 raise / 路由)
  + 前端 research 2(exportToMemory/exportToFile)。

## 决策(record_decision)

- **decision `70daee8a`**（ai_proposed）:导出到记忆/文件。技术+可逆产品小决定。
- 写文件拒覆盖把"不可逆破坏(clobber 用户文件)"挡在门外。**无难撤产品 OQ → 0 条 `[needs-human]`**。

## VibeHub / MCP 交互

**pull**:复用 `MemoryService.create`(存记忆)+ cockpit.cwd(写文件目标)。
**write**:`record_decision`（`70daee8a`,ai_proposed）。无新 ticket。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:触及前后端;本地全绿。
- cron/loop:`2dc539c2`,Round 16。

## defer

- 无新 defer。

## 优化

- **后端**:`_completed_report` 复用(memory/file 两导出共用取报告+校验);写文件拒覆盖防 clobber;
  存记忆复用既有 MemoryService(不重造)→ 自动进向量索引(若开)。
- **前端**:export 复用 `#post` 容错;文件路径基于 cockpit.cwd 零额外状态;无 cwd 时按钮禁用并提示。

## 验证

- `pytest tests/test_research_export.py` → **5 passed**。
- `pytest`（全量后端）→ **147 passed, 1 skipped**(m4 142 → +5)。
- 前端 `vitest` → **116 passed**(含 research export 2);`svelte-check` → 0;`build` → ok。
- 人工目视项:导出按钮实际点击 + 记忆/文件落地未 GUI 目视(逻辑 headless 全覆盖)。

## review

自审:
- export_to_memory 建 source=research 记忆(agent 经 MCP 可读)、write_report_file 拒覆盖 —— 有测试。
- markdown `[n]` 编号引用对应来源顺序 —— 有测试。
- 无报告→404、覆盖→400、未知会话→404 —— 路由测试。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。

## 下一步 —— Room 收尾

`deep-research` 5 个 MVP milestone **全部完成**。进入 Room 收尾:limited drain backlog → 前后端优化扫描 →
全量验证 → room-status → 全绿自动合 main → 切下一个 Room(`journal-notes-tasks`)。
详见 `2026-06-27-deep-research-roomclose.md`。
