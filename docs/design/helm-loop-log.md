# Helm 主工作台 对齐 Loop · 处理流水

> 每把 `helm-pro.html`(锁定设计稿/只读)+ `DESIGN.md`(token/规则)的一块对齐进 Svelte 前端,loop 在这里追加一条。格式见 `helm-loop-procedure.md` 附录 C。
> 设计稿只读、不改。**阶段 1**(前端外壳保真,已完成/合入 main):改 `frontend/src/`,硬门 `npm run build`+`check`+`test`。**阶段 2**(逐模块完善·让所有功能真能用):每个模式从占位做成端到端可用——设计视图(按 DESIGN.md 系统)+ 建 Svelte UI + 接真 `/api` + 守 notch 契约;硬门追加 `pytest`(改后端)/ `cd notch && swift build && swift test`(改 notch 契约)。视觉门:browse dark/light,做成真能用不是画壳。
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

## 2026-07-02 13:52 · phase2-round3-calendar（夜间模式）· F7 日历切片
- 对齐: 阶段2 第3轮——日历视图座舱化(清 backlog P1)+ e2e 抓到并修掉事件创建 UTC 往返错位(P0)
- 设计基线: DESIGN.md(账本/accent 界标/mono 配给/禁 emoji;未改)
- Svelte 改动: `notes/Calendar.svelte`(重写:AGENDA 账本按本地日分组+accent 日期界标+mono 工具钮+caret 输入+来源标 LOCAL|CALDAV+×删+空态;🗑 清除);`mail/calendarStore.svelte.ts`(add 转 UTC ISO 再发);新增共享 `lib/time.ts`(toLocal/localHHMM/localDate/localDateTime),JournalView 迁移同一套;+CalendarView.test(2 测:分组/本地时间/来源标/空态)
- 功能可用性: e2e 实测(真后端):加事件 09:30→显示 09:30(修前显 17:30)→按日分组→删除→空态;导入导出/CalDAV 面(账户表单/同步钮)保留原功能
- 取舍: 全天事件按原始日期分组(不过 UTC 解析,避免漂移一天);周/月网格视图未做(agenda 先可用)记 P2;Mail.svelte(禁用)toEvent 同病记 P2;真实 CalDAV 服务器联调仍归既有 needs-human
- 复查: e2e 即抓 P0(时区往返)当轮修;时间工具第三处复用前抽 lib/time.ts(altitude);新增 P2×2、清 P1×1+P0×1,详 backlog
- 契约/notch 影响: 无(未动端点;notch 不消费 calendar 写路径)
- VibeHub: record_decision「阶段2·轮3 日历座舱化+UTC 修复+lib/time.ts」→ 11cd8ac3 (ai_proposed, F7 room)
- 验证: npm build ✓ / check 0 错 0 警(245 文件)/ test 151 通过(+2);视觉: dev 5174 dark+light agenda 截图核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 13:42 · phase2-round2-backlog-p1（夜间模式）· 清 P1×2
- 对齐: 阶段2 第2轮——按收敛规则先清 backlog open P1:task_runs 运行历史 UI(F6)+ jsonFetch 列表守卫基建(跨模块)
- 设计基线: DESIGN.md（mono 子账本/语义色配给/发丝分隔;未改）
- Svelte 改动: `lib/api.ts`(+jsonList<T> 类型化列表守卫:null=请求失败/[]=形状缺失);9 个 store 16 处直取全迁移 + skillsStore 就地守卫;`tasksStore`(+TaskRun/runsFor/toggleRuns);`JournalView`(任务行「N 次」→ 展开按钮 + mono 运行抽屉:状态点/本地时间/输出省略/空态);tasks.test +1
- 功能可用性: e2e 实测(真后端):建任务→展开抽屉(空态兜底)→收起→删除联动收抽屉;全模式(Chat/Research/Memory/Cockpit/Today)回归点击无报错
- 取舍: 运行抽屉有数据态走 vitest mock 覆盖(真运行=到点付费触发 agent,不在夜间实跑);skillsStore 混合形状不套 jsonList 就地守卫
- 复查: 自查 + 回归扫(迁移语义严格更安全:旧行为 200 缺 key 赋 undefined 后崩,新为 []);新发现 P2×1(Rail bind:this dev 警告)记 backlog;本轮清 P1×2 标 [x]
- 契约/notch 影响: 无(只新消费既有 GET /api/tasks/{id}/runs)
- VibeHub: record_decision「阶段2·轮2 清 backlog P1×2」→ 5a07641d (ai_proposed)
- 验证: npm build ✓ / check 0 错 0 警(243 文件)/ test 149 通过(+1);视觉: dev 5174 dark+light 抽屉截图核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无(cron tz question 8d6ac767 仍待人)

## 2026-07-02 13:30 · phase2-round1-journal-module（夜间模式）· F6 记录模块 切片1
- 对齐: 阶段2 第1轮——记录模式(速记/日记/任务/日历壳)从旧浅色线框做成 DESIGN.md 座舱账本 + 端到端真能用
- 设计基线: DESIGN.md（账本读数/框选视口/mono-sans 硬切/禁 emoji/双主题 token）+ Today.svelte 既有 ledger 语汇（helm-pro 未画此模式，按系统新设计；设计稿未改）
- Svelte 改动: `lib/notes/JournalView.svelte`（重写：JOURNAL 仪表头+tabular 计数、accent 底线 tab、账本行、caret 输入、AI 小结框选视口、日期 accent 界标、×删除、860px 行长、Calendar 缩进包裹+TODO、providers/日历按 tab 懒加载）；`notesStore`（+toTask 接 POST /api/notes/{id}/to-task、mutation 起始清 error、load 守卫）；`tasksStore`（同守卫+清 error）；测试 +3（toTask body / →任务 pin 流 / 原有全绿）
- 功能可用性: 端到端实测通（dev 5174 + 真后端 8769）：建速记→列表（本地时间）→ →任务 pin 跳 tab→cron 建任务（linked_note_id 留）→日记 Markdown 按日分组→任务启停/删→空态/错误兜底；AI 小结无 provider 正确报「先配置」；烟测数据已清
- 取舍: emoji(📅✨🗑)全清；cron 的 UTC 语义不擅动（notch 共用契约）→ add_question 留人定，前端先如实显示本地钟；.cbx 纯色勾选态遵 helm-pro 原样（复查建议不采纳）；Calendar 重设计留 F7 轮
- 复查: 3 finder（逐行/删除行为/跨文件+契约/复用/精简/效率/altitude/公约）→ 修 7（UTC 时间戳、error 不清、stale pin 404 误导、双发丝线、草稿覆盖、行长、懒加载）、refuted 1（reduced-motion 全局已有）、wontfix 1（cbx 遵设计）；新增 backlog open 9 条（P1×4：cron tz / task_runs UI / jsonFetch 守卫基建 / F7 Calendar；P2×5），详 helm-review-backlog.md
- 契约/notch 影响: 无（未动共用端点，只新消费既有 to-task；notch 不受影响，未跑 swift）
- VibeHub: record_decision「阶段2·轮1 记录模式重设计+note→task 打通」→ 2179029a (ai_proposed)；add_question「cron 按本地 tz 还是 UTC」→ 8d6ac767 (ai_proposed)
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 148 通过（+3）；视觉: dev 5174 dark+light 双主题截图核过（账本/框选视口/空态/数据态）
- 状态: ✅ 夜间自 commit（feat/design-shell-today，未合 main）｜❓需确认: cron tz 语义（question 8d6ac767）

## 2026-07-02 01:57 · design-11-terminal-edge（夜间模式）· F8 外壳收官
- 对齐: 折叠态终端边条（40px 竖排 TERMINAL ⟩）——补齐外壳网格第4列
- 设计基线: helm-pro.html 外壳 40px `.edge` / grid 58 250 1fr 40（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte`（折叠态渲 .term-edge 竖排按钮点击展开，展开态仍原 aside；+.term-edge 样式走 token）
- 取舍: 补上后外壳网格与 helm-pro 精确一致（此前默认折叠第4列不渲染）；这是 F8 外壳最后一个具体设计稿细节
- VibeHub: record_decision「折叠态终端边条 + F8 外壳收官」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 右侧竖排 TERMINAL ⟩ 到位
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜里程碑：F8 工作台外壳+全局 overlay 全对齐 helm-pro，阶段1 在 F8 范畴收官（剩各模式归各 Room + 阶段2 接后端）｜❓需确认: 无

## 2026-07-02 01:54 · design-10-quick-capture（夜间模式）
- 对齐: 速记 ⌘N QuickCapture token 化（次级表面·全局入口）
- 设计基线: DESIGN.md 双主题 token + helm-pro.html 模态观感（只读对照，未改）
- Svelte 改动: `lib/QuickCapture.svelte`（仅 <style>）——overlay 模糊背景、capture 暗面板、textarea/hint/save token 化（save=accent）
- 取舍: 逻辑/结构不动（测试无损）。至此 ⌘K/⌘N 两个全局 overlay 都 token 化完；F8 外壳+全局入口收齐，loop 近自然边界（各模式视图归各 Room、helm-pro 未画）
- VibeHub: record_decision「速记 ⌘N token 化」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 开速记，暗面板+模糊+accent 保存与暗壳一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜边界：F8 外壳+全局 overlay 收齐，深入各模式属阶段2/各 Room｜❓需确认: 无

## 2026-07-02 01:52 · design-09-command-palette（夜间模式）
- 对齐: 命令面板 ⌘K token 化（次级表面·全局入口）
- 设计基线: DESIGN.md 双主题 token + helm-pro.html `.setdlg` 模态观感（只读对照，未改）
- Svelte 改动: `lib/CommandPalette.svelte`（仅 <style>）——overlay 模糊背景、palette 暗面板走 token、input/row/选中/group token 化
- 取舍: 逻辑/结构/role/文案全不动（测试无损）；各模式视图（Chat/Research 等）helm-pro 未画、归各自 Room，不在本 loop 靶内，故转做全局 overlay
- VibeHub: record_decision「命令面板 ⌘K token 化」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 开面板，暗面板+模糊背景+accent 选中+mono group 与暗壳一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:48 · design-08-orage-chrome（夜间模式）· 阶段1 核心八块收官
- 对齐: ORAGE chrome（阶段1 第8块）——点阵底纹 + 散落准星 fiducial + 坐标 chip + 强弱切
- 设计基线: helm-pro.html `.app::before` 点阵 / `.fidmark` / `.coord` / `.weak` / DESIGN.md「ORAGE Chrome 词汇 + 强度可切」（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte`（.center 点阵背景层 + .chrome overlay 准星/坐标，弱默认强可切）；`lib/layout.svelte.ts`（+chromeStrong/toggleChrome）；状态栏加「◇ chrome」切
- 取舍: 点阵做成 background 层避 z-index 坑；弱默认（f1/f2）符合「日常偏弱」，强模式（.strong）显 f3/f4；强度切暂在状态栏，未来挪设置（TODO）
- VibeHub: record_decision「ORAGE chrome + 阶段1 收官」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 弱默认点阵+坐标+准星到位，整体=helm-pro A+ORAGE
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜里程碑：阶段1 Shell/Today 核心八块全对齐｜剩余（loop 可续）：各模式视图/命令面板/速记/设置 modal 上妆；之后阶段2 接后端+notch｜❓需确认: 无

## 2026-07-02 01:44 · design-07-statusbar-hud（夜间模式）
- 对齐: 状态栏 CLI 面包屑 HUD 补全（阶段1 第7块）
- 设计基线: helm-pro.html `.sbar`（seg 分段 / NEXT / 001/009 / tok / RAG）/ DESIGN.md「三招牌·遥测状态栏」（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte` statusbar——加 CLAUDE·tok 14.2k、60ms·RAG idle、NEXT + 001/009（tabular）、path 段高亮；保留 toggle 与 backendStatus
- 取舍: tok/latency/NEXT/001/009 mock（真实遥测阶段2 接流）；保留 toggle 按钮与 backendStatus（App.test 依赖）
- VibeHub: record_decision「状态栏 CLI 面包屑 HUD」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 面包屑 HUD 与 helm-pro 一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:41 · design-06-context-telemetry（夜间模式）
- 对齐: context 遥测面板（阶段1 第6块）——当前项目 + Today 导航 + 会话遥测块 + 坐标 chip + LOCAL 角标
- 设计基线: helm-pro.html `.ctx`(cproj/slab/nrow/telem/coord/cornertag) / DESIGN.md「ORAGE Chrome 词汇·会话遥测块」（只读对照，未改）
- Svelte 改动: 新增 `lib/ContextPanel.svelte`（当前项目+Today 导航+SESSION/MODEL/TOKENS 遥测+坐标 chip+LOCAL 角标，走 token，mock）；`lib/Shell.svelte` 用 ContextPanel 替换旧占位、删 MODES/modeLabel 与无用 .ctx-* 样式
- 取舍: 旧「打开 Tab」占位无测试依赖，安全移除；遥测/导航计数 mock（真实值阶段2 接 orchestration/session 流，保持版式）
- VibeHub: record_decision「context 遥测面板」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 与 helm-pro context 一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜里程碑：外壳+Rail+Today+context 全齐，整体达 helm-pro 观感｜❓需确认: 无

## 2026-07-02 01:37 · design-05-today-readout（夜间模式）
- 对齐: Today 无卡片仪表读数（阶段1 第5块）——任务/日记/agent 框选视口/项目/邮件/快速动作
- 设计基线: helm-pro.html `.rd`(rdrow/gut/task/jr/framed/agl/projline/mailn/qa) / DESIGN.md「三招牌动作·无卡片 Today」（只读对照，未改）
- Svelte 改动: `lib/Today.svelte`（重写为读数：左槽 mono + 发丝行 + 各节 mock + 框选视口 L 角 + ✻ 旋转/caret 闪烁 + 快速动作 wired）；`lib/Today.test.ts`（更新到新读数断言，修 helm 文本重复→用 /feat\/notch/ 唯一定位）
- 取舍: 清掉旧卡片+emoji（🔍📝）；数据用设计稿同款 mock（真实数据阶段2 接 /api 保持版式）；旧 Today.test 的线框断言作废，改断言新读数行为
- VibeHub: record_decision「Today 无卡片仪表读数」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 146 通过；视觉：dev 5174 dark+light 与 helm-pro 读数基本一致（当天 accent 青）
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:33 · design-04-filament-rail（夜间模式）
- 对齐: 细丝 Rail（阶段1 第4块）——1px accent 活线 + 锚点滑移 + agent 脉冲 + emoji→单色 SVG
- 设计基线: helm-pro.html `.rail`(fil/anchor/pulse/ric/logo) / DESIGN.md「三招牌动作·细丝 Rail」（只读对照，未改）
- Svelte 改动: `lib/Rail.svelte`（重写）——ICONS 单色 SVG 映射（{@html}）、HELM logo、fil/anchor/pulse、$effect 读激活按钮 offset 让锚点滑移对齐、34px ric 走 token
- 取舍: 落实禁 emoji（不再用 MODES.icon 的 emoji，Rail 自带 SVG 映射）；锚点用 offsetTop 计算而非死值（settings 底部自动跟到）；pulse 常驻 mock（真实 agent 流阶段2）；rail 无 mail（MODES 已禁 mail，按路由 truth）。当天 accent=青 #34D6C0 证明每日变色生效
- VibeHub: record_decision「细丝 Rail」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 147 通过；视觉：dev 5174 dark，logo/锚点/图标/细丝都对，emoji 全清
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:27 · design-03-shell-chrome（夜间模式）
- 对齐: 外壳 Shell chrome（阶段1 第3块）——titlebar + token 网格 + CLI 面包屑状态栏
- 设计基线: helm-pro.html `.app` 网格 + titlebar + `.sbar` / DESIGN.md「Spacing 骨架 / Layout」（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte`（chrome 重构，功能逻辑不动）——titlebar（交通灯+HELM+路径+meta）、grid 加 title 行+列走骨架变量、context/center/terminal/tabbar 全改 token、statusbar 重做 CLI 面包屑 HUD（live accent 点+mono 分段+toggle 分段）
- 取舍: 保留 mode 路由/tabs/收起/palette/capture 不破；Rail 内部与 Today 内容仍旧浅样式透出=预期（各自块在后）；terminal 未做 40px edge（TODO）。视觉门 dev 端口 5174（5173 被他项目 Euka 占，后续截图用 5174）
- VibeHub: record_decision「外壳 Shell chrome」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 147 通过；视觉：dev 5174 截图 dark 纯黑 chrome + 纸白双主题都对（titlebar/context/statusbar/canvas 正确，Rail/Today 待其块）
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:24 · design-02-theme-store（夜间模式）
- 对齐: 主题/accent 系统（阶段1 第2块）——dark/light/跟随系统 + 每日 accent + 对比压暗
- 设计基线: helm-pro.html 的 theme 切换/darken()/palette + DESIGN.md「Themes / Color 每日变色」（只读对照，未改）
- Svelte 改动: 新增 `lib/theme.svelte.ts`（runes 单例 theme：mode/accent、apply→<html> data-theme+--acc/--acc-ink、dailyAccent/darken、init 监听系统翻转、jsdom 守卫）；`main.ts` mount 前 theme.init()；新增 `lib/theme.test.ts`（+3 测）
- 取舍: 每日 accent 走 palette[dayIndex%10]（当天稳定午夜轮换）；darken 复刻 helm-pro r*.5 g*.5 b*.42；system 模式移除 data-theme 交给 @media。视觉门本块仍有限（组件未消费，仅 body 变暗），下块外壳起对比。TODO: MODES emoji 图标留给 Rail 块换 SVG
- VibeHub: record_decision「主题/accent 系统 theme store」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 147 通过（+3）；视觉：待下块外壳组件消费后 dark/light 对比
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:20 · design-01-tokens（夜间模式）
- 对齐: 设计 token 系统（阶段1 第1块）——把 helm-pro.html/DESIGN.md 的 token 落进全局 CSS
- 设计基线: helm-pro.html `:root`+`[data-theme]` 双主题 / DESIGN.md「Themes / Typography / Spacing / Motion」（只读对照，未改）
- Svelte 改动: `frontend/src/app.css`（重写）——字体硬切变量、招牌缓动+时长档、骨架尺寸、双主题 token（暗默认+暖纸白，@media prefers-color-scheme 实现默认跟随系统）、语义色配给、accent 默认留给 theme store 覆写、body/selection/scrollbar 走 token、reduced-motion
- 取舍: 纯 token 块，尚无组件消费 → 视觉门本块暂无可比（下一块起对比）。accent 每日推导+压暗留给下一块 theme store。light token 在 @media 与 [data-theme=light] 各写一份（避免 CSS 变量间接引用的复杂度）。禁 emoji 保持。
- VibeHub: record_decision「app.css 双主题 token 落地」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（240 文件）/ test 144 通过；视觉：本块纯 token 无可比，待下块组件消费后 dark/light 对比
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无
