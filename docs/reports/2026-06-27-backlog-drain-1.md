# Loop Report · B 轨收尾 · drain #1

> 档位:🌙 放手模式。A 轨(PRD 10 Room)已全部合 main → 进入 B 轨收尾(限额 drain 自消化技术 backlog)。Round 27。

## 目标

清自消化技术 backlog。本轮 drain **ticket `4527c95c`[refactor]**:前端各 store 的 `#json` fetch 容错 helper 重复 → 抽共享工具。

## 做了什么

- **`frontend/src/lib/api.ts`**（新增）:`jsonFetch(path, init)` —— fetch + 非 2xx/网络/解析错 → null 的统一容错。
- **10 个 store**（改）:`memory/rag/skills/chat/research/orchestration/notes/tasks/mail/calendar` 的私有
  `#json` 改为 `async` 委托 `return jsonFetch(...)`,消除 10 份重复的 try/catch 容错逻辑;各加 `import { jsonFetch } from '../api'`。

## review(本轮重点 —— 抓到真回归)

- 初版把委托 `#json` 去掉 `async`(直接 `return jsonFetch(...)`)→ load 早一个 microtask 解析,
  **4 个时序敏感的组件渲染测试失败**(RagView/JournalView/tasks;逻辑不变,纯渲染时序)。
- 用 `git stash` 对照确认:净 main 140 全过,refactor 后 4 挂 → 确系本改动引入。
- **修复:保留 `async` 委托**(`async #json(...) { return jsonFetch(...) }`),恢复原 microtask 时序 → 140 全过。
- 这是 review/验证门该抓的:纯重构也可能因时序细节引入回归。

## 决策(record_decision)

- **decision `60256557`**（ai_proposed）:抽共享 jsonFetch + 委托;ticket `4527c95c` 已消化。
- `#post` 不在本 ticket 范围,保留(未来另起)。

## 验证

- 前端 `vitest` → **140 passed**;`svelte-check` → 0;`build` → ok。
- 后端 `pytest` → **183 passed, 1 skipped**(无关,未改)。

## 熔断状态

未命中熔断。一次测试失败(refactor 时序回归)首次即修复。

## 下一步

继续 B 轨 drain 其它自消化技术 ticket(`8299f9b6` Monaco 代码分割、`5582cd77` file_changes 清理、`7842c722` RAG 后台索引、
`f029e4e5` httpx2、`b005c5de` 打包体积…),直到只剩 `[needs-human]`。本轮先合这条。
