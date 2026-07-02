# Helm 阶段 2 · 复查 Backlog（活的迭代账本）

> 阶段 2 每轮第 9 步的复查发现（代码 review + 完整性复查）记这里；每轮第 1 步先读它、清 P0/P1。
> 格式：`- [ ] [模块][P0/P1/P2][bug|gap|polish] 描述  (发现 <轮次/日期>)`，修掉改 `[x]` 并补 `→ 修于 <commit>`。
> 严重度：**P0 = blocking**（功能不能用/有 bug）· **P1 = 重要缺口**（该有没有）· **P2 = 打磨**。
> 收敛：P0 优先于拿新活；一个模块 open P0/P1 清空 + 完整性复查说"真能用没明显缺口"才算完。详见 `helm-loop-procedure.md`「复查与迭代」。

## Open（待处理，P0 在最上）

<!-- 新发现追加到对应严重度下；修掉移到「Done」或就地改 [x] -->

- [ ] [记录][P1][bug] cron next_run 后端按 UTC 计算：用户写 `0 9 * * *` 期望本地 9 点，实际 09:00 UTC 触发。前端已如实显示本地时间（会显 17:00 暴露错位），但语义修正需后端定 tz 策略（/api/tasks 为 notch 共用契约，不擅动）→ 已 add_question 待人定  (轮1/2026-07-02)
- [ ] [Chat][P1][gap] 多模型并排对比+盲测（room intent 4501c6dd 标 P1）未做——大特性，不阻塞"provider+流式+持久化"基本可用，排 Chat 二轮  (轮4/2026-07-02)
- [ ] [Chat][P2][gap] 会话无自动命名（title 一直 null 显示"会话 N"）；新会话表单未暴露 system_prompt；对话未接 RAG/项目上下文（intent 56910be6）  (轮4/2026-07-02)
- [ ] [外壳][P2][polish] Rail.svelte:60 `bind:this={btns['settings']}` 绑非响应式属性（Svelte dev 警告 binding_property_non_reactive）  (轮2/2026-07-02)
- [ ] [日历][P2][gap] 日程只有账本 agenda 列表，模块表提的周/月网格视图未做（agenda 已可用，网格视图待产品优先级）  (轮3/2026-07-02)
- [ ] [邮件][P2][bug] Mail.svelte（模式现禁用）toEvent 的 window.prompt 时间仍按裸本地串直发，重新启用邮件时需与日历 UTC 约定对齐  (轮3/2026-07-02)
- [ ] [记录][P2][gap] 任务表单只暴露 cron；后端 at/every/execution_mode(existing|new_conversation) 未露出  (轮1/2026-07-02)
- [ ] [记录][P2][gap] note→task 成功后速记行无「已转任务」标记（server 非破坏保留 note），可重复转出多任务；标记方式待产品定  (轮1/2026-07-02)
- [ ] [记录][P2][polish] Today↔JournalView 账本 CSS（head/row/gut/framed/cbx/act.pri ≈100 行）手抄两份已现漂移（framed padding、.pg tabular-nums），抽共享 ledger 样式/组件  (轮1/2026-07-02)
- [ ] [记录][P2][gap] 笔记不可编辑（后端 PATCH 有）、pinned/tags 未露出；日记附图（intent#2）与周/月回顾未做  (轮1/2026-07-02)
- [ ] [记录][P2][polish] 输入区 ⌘Enter 提交缺失；删除无确认/undo  (轮1/2026-07-02)

## Done（已修 / 已判定）

<!-- 修掉/wontfix 的条目归到这里，保留可追溯 -->

- [x] [Chat][P0][bug] vite 代理不转发 WebSocket（字符串简写缺 ws:true）→ dev 环境 Chat 流式完全不通 → 修于 轮4 commit（proxy 对象形式 + ws:true）  (轮4/2026-07-02)
- [x] [Chat][P0][bug] 删除带消息的会话 FK 崩 500（messages↔sessions 无 ORM relationship，flush 排序错）→ 修于 轮4 commit（先 flush 子行；后端测试补"带消息删除"场景）  (轮4/2026-07-02)
- [x] [Chat][P1][gap] 会话/provider 无删除（后端缺 DELETE /api/sessions/{id}；UI 两者都没入口）→ 修于 轮4 commit（+端点+store+×按钮；provider 被会话引用时 409 明确提示而非 FK 500）  (轮4/2026-07-02)
- [x] [Chat][P1][bug] WS 连不上时 send 排队等 open、streaming 永久卡 true（composer 冻死）→ 修于 轮4 commit（onerror 兜底清 streaming+报错）  (轮4/2026-07-02)
- [x] [Chat][P1][gap] Chat/ProviderSettings 旧线框+emoji(⚙🔑) → 修于 轮4 commit（座舱化：账本消息流 YOU/MODEL+流式 caret+assistant Markdown+自动贴底滚动+会话 accent 活栏+KEY 标+模板 act 钮，全 token 双主题）  (轮4/2026-07-02)
- [x] [日历][P1][gap] Calendar.svelte 旧线框样式 → 修于 轮3 commit（重设计为座舱账本 agenda：按本地日分组 + accent 日期界标 + mono 工具/来源标 LOCAL|CALDAV + caret 输入 + 空态；emoji 🗑→×；全 token 双主题）  (轮1→轮3/2026-07-02)
- [x] [日历][P0][bug] 事件创建时区往返错位：datetime-local 本地墙钟裸串直发、显示层按 UTC 解释（输 09:30 显 17:30，e2e 抓到）→ 修于 轮3 commit（calendarStore.add 转 UTC ISO 再发；共享 lib/time.ts 抽出 toLocal/localHHMM/localDate/localDateTime，JournalView 同步迁移）  (轮3/2026-07-02)
- [x] [记录][P1][gap] 任务运行历史未接（GET /api/tasks/{id}/runs 有、UI 无）→ 修于 轮2 commit（tasksStore.toggleRuns + 任务行「N 次」按钮展开 mono 子账本抽屉：状态点/本地时间/输出省略；空态兜底；e2e 实测展开/收起/删除联动）  (轮2/2026-07-02)
- [x] [基建][P1][gap] jsonFetch 无类型化列表守卫 → 修于 轮2 commit（lib/api.ts +jsonList<T>(path,key)：null=请求失败、[]=形状缺失；chat/memory/rag/mail/calendar/research/orchestration/notes/tasks 全部 16 处迁移，skillsStore 混合形状就地守卫）  (轮2/2026-07-02)

- [x] [记录][P0][bug] UTC 时间戳直显：速记 HH:MM 与任务「下次」直接 slice ISO 显示 UTC 钟（本地 UTC+8 差 8h）→ 修于 轮1 commit（toLocal 补 Z 解析 + 本地格式化）  (轮1/2026-07-02)
- [x] [记录][P1][bug] store error 一旦置上永不清除（失败后重试成功仍显示失败）→ 修于 轮1 commit（各 mutation 起始 error=null）  (轮1/2026-07-02)
- [x] [记录][P1][bug] pin 的速记被删后提交 to-task 404 却报「检查 schedule」误导 + chip 卡死 → 修于 轮1 commit（检测 note 已删，明确报错并解 pin）  (轮1/2026-07-02)
- [x] [记录][P2][bug] `.row:first-of-type` 永不匹配（.seg 抢占 first-of-type）→ tab 条下双发丝线 → 修于 轮1 commit（`.seg + .row`）  (轮1/2026-07-02)
- [x] [记录][P2][polish] →任务 覆盖手打任务草稿、取消不还原 → 修于 轮1 commit（promptValue $derived，取消自动还原草稿；title-only note 可提交）  (轮1/2026-07-02)
- [x] [记录][P2][gap] 旧版 max-width 阅读约束丢失、Calendar 左贴边 → 修于 轮1 commit（.jnt 860px + .calwrap gutter 缩进）  (轮1/2026-07-02)
- [x] [记录][P2][perf] onMount 齐发 5 请求（calendar/caldav/providers 未开 tab 也拉）→ 修于 轮1 commit（notes+tasks 首载，其余按 tab 懒加载）  (轮1/2026-07-02)
- ~~wontfix~~ [记录] `.cbx` 勾选态纯 accent 色块对比不足 — 与锁定设计源 helm-pro `.cbx.done` / Today 完全一致，遵设计稿不改  (轮1/2026-07-02)
- ~~refuted~~ [记录] caret blink 缺 prefers-reduced-motion 守卫 — app.css 已全局杀动画（141-147 行）  (轮1/2026-07-02)
