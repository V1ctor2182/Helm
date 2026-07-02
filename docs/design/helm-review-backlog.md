# Helm 阶段 2 · 复查 Backlog（活的迭代账本）

> 阶段 2 每轮第 9 步的复查发现（代码 review + 完整性复查）记这里；每轮第 1 步先读它、清 P0/P1。
> 格式：`- [ ] [模块][P0/P1/P2][bug|gap|polish] 描述  (发现 <轮次/日期>)`，修掉改 `[x]` 并补 `→ 修于 <commit>`。
> 严重度：**P0 = blocking**（功能不能用/有 bug）· **P1 = 重要缺口**（该有没有）· **P2 = 打磨**。
> 收敛：P0 优先于拿新活；一个模块 open P0/P1 清空 + 完整性复查说"真能用没明显缺口"才算完。详见 `helm-loop-procedure.md`「复查与迭代」。

## Open（待处理，P0 在最上）

<!-- 新发现追加到对应严重度下；修掉移到「Done」或就地改 [x] -->

- [ ] [F8][P2][gap] context 面板会话遥测(SESSION/MODEL/TOKENS)与状态栏 tok/latency 仍 mock——规划中的遥测流(可并进 orchestration WS)未建,属 F5 后续  (轮12/2026-07-02)
- [ ] [记录][P2][gap] 日记附图(intent#2)未做——Note 无附件字段,需 schema 迁移(不可逆),留人拍板  (轮1/2026-07-02;清账轮复确认)
- [ ] [Chat][P2][gap] 对话接 RAG/项目上下文(intent 56910be6)未做——上下文注入点(持久化语义/token 预算)是架构切片,建议单独一轮设计后做  (轮4/2026-07-02;清账轮复确认)
- [ ] [大脑][P2][gap] Skills 触发计数恒 0、启停不真禁 Claude Code——需 Claude Code hook 集成(F5 大件),既有已知限制  (轮7/2026-07-02)
- [ ] [设置][P2][gap] 本机 hook / 媒体源设置属 notch 伴侣侧;K/V settings 与 secrets 管理 UI 未做;accent 手动选择不持久化(设计定当日轮换,待产品确认)  (轮11/2026-07-02)
- [ ] [Chat][P2][polish] 对比历史不可从会话列表重新打开成对比视图(侧栏 CMP 标已加)  (轮5/2026-07-02;清账轮部分消化)

## Done（已修 / 已判定）

<!-- 修掉/wontfix 的条目归到这里，保留可追溯 -->

- [x] [F8][P1][gap] Today 全 mock(模块清单最后一块)→ 修于 轮12 commit(五节全接真:任务←/api/tasks(checkbox 真启停+下次本地时间+1h 内 hot)、日记←今日 entries 摘要、Agent 框选视口←/api/orchestration/runs(notch 共用只读)、项目←/api/cockpit/projects(点击开驾驶舱)、邮件行按用户 6-28 决定改「日程/NEXT」←下个未来事件;真日期头+计数 tabular;五节空态兜底;测试重写为真数据断言(159 绿);e2e 种真数据全节点亮+清净)  (轮12/2026-07-02)
- [x] [记录][P1][bug] cron next_run 按 UTC 计算(question 8d6ac767)→ 修于 清账轮 commit(用户授权「全部完成」:cron 表达式按本地墙钟解释,croniter 在本地 tz 迭代,返回 tz-aware;e2e 验证 `0 9 * * *`→次日本地 09:00(+08:00);DTO 形状不变 notch 契约无影响;测试改锁本地语义)  (轮1→清账轮/2026-07-02)
- [x] [Chat][P2][gap] 会话自动命名 → 修于 清账轮 commit(首条用户消息前 30 字设为无标题会话标题,后端 add_message;测试钉住)  (轮4→清账轮/2026-07-02)
- [x] [Chat][P2][gap] 新会话未暴露 system_prompt → 修于 清账轮 commit(新会话表单 +system prompt 输入)  (轮4→清账轮/2026-07-02)
- [x] [Chat][P2][polish] 对比会话侧栏无标记 → 修于 清账轮 commit(标题「对比 ·」前缀显 CMP mono 徽章)  (轮5→清账轮/2026-07-02)
- [x] [外壳][P2][polish] Rail bind:this 非响应式警告 → 修于 清账轮 commit(btns 改 $state({}))  (轮2→清账轮/2026-07-02)
- [x] [日历][P2][gap] 周/月网格视图 → 修于 清账轮 commit(列表|月 双视图:周一起 7 列月网格+今日 accent+事件条 accent 左沿+«»翻月;测试+e2e)  (轮3→清账轮/2026-07-02)
- [x] [邮件][P2][bug] Mail toEvent 裸本地串直发 → 修于 清账轮 commit(转 UTC ISO 与日历约定一致;测试同步)  (轮3→清账轮/2026-07-02)
- [x] [记录][P2][gap] 任务只暴露 cron → 修于 清账轮 commit(调度模式 select:cron/every(秒)/at(本地时间转 UTC);→任务 pin 流同用)  (轮1→清账轮/2026-07-02)
- [x] [记录][P2][gap] note→task 无已转标记 → 修于 清账轮 commit(linked_note_id 派生「已转任务」mono 徽章)  (轮1→清账轮/2026-07-02)
- [x] [记录][P2][gap] 笔记/日记不可编辑 → 修于 清账轮 commit(notesStore.update PATCH + 行内编辑(编辑→textarea→保存/取消);e2e 实测)  (轮1→清账轮/2026-07-02)
- [x] [记录][P2][polish] ⌘Enter 提交缺失 → 修于 清账轮 commit(速记/日记 textarea ⌘/Ctrl+Enter 提交)  (轮1→清账轮/2026-07-02)
- [x] [记录][P2][polish] 删除无确认 → 修于 清账轮 commit(ConfirmGate 二段确认:×→「确认」3s 内再点放行;覆盖速记/日记/任务/日历/记忆;e2e 实测武装→确认→删)  (轮1→清账轮/2026-07-02)
- [x] [记录][P2][gap] 周/月回顾未做 → 修于 清账轮 commit(summary 端点 +days 窗口(周回顾=7 天区间),前端「周回顾」按钮;后端测试)  (轮1→清账轮/2026-07-02)
- [x] [驾驶舱][P2][polish] Monaco 不随主题热更 → 修于 清账轮 commit($effect setTheme)  (轮9→清账轮/2026-07-02)
- [x] [研究][P2][polish] 无 provider 下拉光秃 → 修于 清账轮 commit(「去 Chat 的 PROVIDERS 配一个」提示)  (轮8→清账轮/2026-07-02)
- ~~wontfix~~ [记录] Today↔Journal 账本 CSS 全量抽共享 — 判定不抽:Svelte scoped style 是惯例,机械抽全局类反增耦合;漂移实处已修(framed padding 对齐 + Today .pg 补 tabular-nums 达 DESIGN 规)  (轮1→清账轮/2026-07-02)
- ~~wontfix~~ [驾驶舱] xterm 黑底不接双主题 — 终端惯例黑底,保留(轮9 已记决策)  (轮9/2026-07-02)

- [x] [设置][P1][gap] settings 模式只有通用 tab 占位、主题切换无 UI 入口、主题模式不持久化 → 修于 轮11 commit（Settings.svelte:主题三态(跟随系统/暗/亮,持久化 localStorage,init 恢复)+今日 accent 10 色现场换+后端连接状态(healthz 点+版本)+MCP 注入状态/注入按钮(合并+备份);Shell 挂 settings 模式;theme store +持久化+测试;e2e:切暗→reload 仍暗→换 accent 生效→复原跟随系统）  (轮11/2026-07-02)
- [x] [驾驶舱][P1][gap] AgentView 旧样式+10 个 emoji 图标(🟢💬🔧⚠️🔐⏳📊🏁🔴🤖,违禁 emoji 硬规) → 修于 轮10 commit（ACP 事件流=框选视口+mono 类型标签(SESS/MSG/TOOL/OK/ERR/PERM/RATE/END)+语义色调;caret 指令输入;状态/历史描边徽章;文案与事件逻辑不动测试全保)  (轮9→轮10/2026-07-02)
- [x] [驾驶舱][P1][gap] CockpitView/FileBrowser/PreviewPane 旧线框(⬆/圆角卡/硬编码 hex/Monaco 亮主题暗模式白块) → 修于 轮9 commit（accent 底线 tab;文件=1px 发丝瓦片零圆角+selected accent 边+changed 绿闪(token);路径栏 mono+↑/跟随 act;预览 mono 标题+tile code 块+Markdown token;Monaco theme 跟随 isDark;e2e 开真项目→浏览→选 DESIGN.md→Markdown 预览+预览/Diff tab 全通）  (轮9/2026-07-02)
- [x] [研究][P1][gap] Research.svelte 旧线框+emoji(🔍) → 修于 轮8 commit（RESEARCH 仪表头+status/badge 描边徽章(running accent/done 绿/error 红)+caret 提问+mono 控件+进度框选视口+CLAIMS/SOURCES section tag+引用 [n] accent mono+历史发丝行;全 token 双主题）  (轮8/2026-07-02)
- [x] [大脑][P1][gap] Rag/Skills 子视图旧线框(📚⚡🗑↻ emoji+胶囊+硬编码 hex) → 修于 轮7 commit（知识库:账本源行+状态 mono 徽章(indexed 绿/indexing 橙/error 红)+重索引/×+检索命中行(path+score+片段);Skills:账本行+方形启停+健康徽章+触发计数+路径;e2e:真源索引(vector 1)+语义检索命中 0.6594+移除;Skills 真扫描 72 个渲染）  (轮6→轮7/2026-07-02)
- [x] [大脑][P1][gap] BrainPanel/Memory 旧线框+emoji(🧠📌📍🗑) → 修于 轮6 commit（MEMORY 仪表头+tabular 三计数+accent 底线 tab;记忆=分类 chips+caret 输入+分类 select+搜索行+账本行(FACT tag/score/PIN/×)+置顶 accent 左栏;e2e 增/混合搜索(score 0.59)/置顶/删全通）  (轮6/2026-07-02)
- [x] [大脑][P2][bug] 搜索结果视图里置顶/删除不同步反映（load 只刷 items 不刷 results）→ 修于 轮6 commit（store 同步 patch results）  (轮6/2026-07-02)
- [x] [Chat][P1][gap] 多模型并排对比+盲测（intent 4501c6dd）→ 修于 轮5 commit（compareStore N 路并行:每 lane 真会话+独立 WS 流;CompareView 框选视口 lane 网格+STREAMING 标+盲测 模型 A/B/C+揭晓;COMPARE 侧栏入口;3 store 测;e2e 两路并行错误帧+揭晓实测）  (轮4→轮5/2026-07-02)
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
