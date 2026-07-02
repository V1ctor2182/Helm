# Helm 阶段 2 · 复查 Backlog（活的迭代账本）

> 阶段 2 每轮第 9 步的复查发现（代码 review + 完整性复查）记这里；每轮第 1 步先读它、清 P0/P1。
> 格式：`- [ ] [模块][P0/P1/P2][bug|gap|polish] 描述  (发现 <轮次/日期>)`，修掉改 `[x]` 并补 `→ 修于 <commit>`。
> 严重度：**P0 = blocking**（功能不能用/有 bug）· **P1 = 重要缺口**（该有没有）· **P2 = 打磨**。
> 收敛：P0 优先于拿新活；一个模块 open P0/P1 清空 + 完整性复查说"真能用没明显缺口"才算完。详见 `helm-loop-procedure.md`「复查与迭代」。

## Open（待处理，P0 在最上）

<!-- 新发现追加到对应严重度下；修掉移到「Done」或就地改 [x] -->

- [ ] [记录][P1][bug] cron next_run 后端按 UTC 计算：用户写 `0 9 * * *` 期望本地 9 点，实际 09:00 UTC 触发。前端已如实显示本地时间（会显 17:00 暴露错位），但语义修正需后端定 tz 策略（/api/tasks 为 notch 共用契约，不擅动）→ 已 add_question 待人定  (轮1/2026-07-02)
- [ ] [记录][P1][gap] 任务运行历史未接：后端有 `GET /api/tasks/{id}/runs`（task_runs），UI 看不到任务执行结果  (轮1/2026-07-02)
- [ ] [基建][P1][gap] jsonFetch 无类型化列表守卫：calendar/memory/rag store 仍未守卫 `body.xs` 直取，后端返回异常包裹（200 + `{}`）会崩视图；应在 `lib/api.ts` 加通用 list helper 并统一各 store  (轮1/2026-07-02)
- [ ] [日历][P1][gap] `Calendar.svelte` 仍是旧线框样式（硬编码 hex/圆角/emoji 风格外），归 F7 日历模块轮按 DESIGN.md 重设计（JournalView 已留 TODO）  (轮1/2026-07-02)
- [ ] [记录][P2][gap] 任务表单只暴露 cron；后端 at/every/execution_mode(existing|new_conversation) 未露出  (轮1/2026-07-02)
- [ ] [记录][P2][gap] note→task 成功后速记行无「已转任务」标记（server 非破坏保留 note），可重复转出多任务；标记方式待产品定  (轮1/2026-07-02)
- [ ] [记录][P2][polish] Today↔JournalView 账本 CSS（head/row/gut/framed/cbx/act.pri ≈100 行）手抄两份已现漂移（framed padding、.pg tabular-nums），抽共享 ledger 样式/组件  (轮1/2026-07-02)
- [ ] [记录][P2][gap] 笔记不可编辑（后端 PATCH 有）、pinned/tags 未露出；日记附图（intent#2）与周/月回顾未做  (轮1/2026-07-02)
- [ ] [记录][P2][polish] 输入区 ⌘Enter 提交缺失；删除无确认/undo  (轮1/2026-07-02)

## Done（已修 / 已判定）

<!-- 修掉/wontfix 的条目归到这里，保留可追溯 -->

- [x] [记录][P0][bug] UTC 时间戳直显：速记 HH:MM 与任务「下次」直接 slice ISO 显示 UTC 钟（本地 UTC+8 差 8h）→ 修于 轮1 commit（toLocal 补 Z 解析 + 本地格式化）  (轮1/2026-07-02)
- [x] [记录][P1][bug] store error 一旦置上永不清除（失败后重试成功仍显示失败）→ 修于 轮1 commit（各 mutation 起始 error=null）  (轮1/2026-07-02)
- [x] [记录][P1][bug] pin 的速记被删后提交 to-task 404 却报「检查 schedule」误导 + chip 卡死 → 修于 轮1 commit（检测 note 已删，明确报错并解 pin）  (轮1/2026-07-02)
- [x] [记录][P2][bug] `.row:first-of-type` 永不匹配（.seg 抢占 first-of-type）→ tab 条下双发丝线 → 修于 轮1 commit（`.seg + .row`）  (轮1/2026-07-02)
- [x] [记录][P2][polish] →任务 覆盖手打任务草稿、取消不还原 → 修于 轮1 commit（promptValue $derived，取消自动还原草稿；title-only note 可提交）  (轮1/2026-07-02)
- [x] [记录][P2][gap] 旧版 max-width 阅读约束丢失、Calendar 左贴边 → 修于 轮1 commit（.jnt 860px + .calwrap gutter 缩进）  (轮1/2026-07-02)
- [x] [记录][P2][perf] onMount 齐发 5 请求（calendar/caldav/providers 未开 tab 也拉）→ 修于 轮1 commit（notes+tasks 首载，其余按 tab 懒加载）  (轮1/2026-07-02)
- ~~wontfix~~ [记录] `.cbx` 勾选态纯 accent 色块对比不足 — 与锁定设计源 helm-pro `.cbx.done` / Today 完全一致，遵设计稿不改  (轮1/2026-07-02)
- ~~refuted~~ [记录] caret blink 缺 prefers-reduced-motion 守卫 — app.css 已全局杀动画（141-147 行）  (轮1/2026-07-02)
