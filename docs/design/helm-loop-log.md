# Helm 主工作台 对齐 Loop · 处理流水

> 每把 `helm-pro.html`(锁定设计稿/只读)+ `DESIGN.md`(token/规则)的一块对齐进 Svelte 前端,loop 在这里追加一条。格式见 `helm-loop-procedure.md` 附录 C。
> 设计稿只读、不改。**阶段 1**(前端外壳保真,已完成/合入 main):改 `frontend/src/`,硬门 `npm run build`+`check`+`test`。**阶段 2**(逐模块完善·让所有功能真能用):每个模式从占位做成端到端可用——设计视图(按 DESIGN.md 系统)+ 建 Svelte UI + 接真 `/api` + 守 notch 契约;硬门追加 `pytest`(改后端)/ `cd notch && swift build && swift test`(改 notch 契约)。视觉门:browse dark/light,做成真能用不是画壳。
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

## 2026-07-02 18:40 · phase2-round12-today-real（夜间模式）· F8 Today 真数据·模块清单收官
- 对齐: 阶段2 第12轮——Today 五节全接真 /api(模块清单最后一块),版式不动空态兜底
- 改动: `lib/Today.svelte`(数据层重写:任务/日记/Agent 运行/项目/日程 NEXT+真日期头+tabular 计数+30s 刷新);`Today.test.ts`(重写为真数据断言,5 测)
- 功能可用性: e2e 种真数据:任务显本地 17:00(cron 本地语义连通)、今日日记摘要、项目点击开驾驶舱、下个日程 19:29;五节空态各自兜底;checkbox=真启停;种子清净
- 契约/notch 影响: 无(orchestration/runs 只读消费)
- 取舍: 邮件行按用户 6-28 决定改「日程/NEXT」;context 遥测块/状态栏 tok 仍 mock(遥测流属 F5 后续)记 P2
- VibeHub: record_decision「阶段2·轮12 Today 真数据收官」→ 922ccf7e (ai_proposed, F8)
- 验证: npm build ✓/check 0 错 0 警(250 文件)/test 159(+1);视觉 dev 5174 dark+light 真数据截图核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜里程碑:模块清单 10 项全部端到端可用｜❓需确认: 无

## 2026-07-02 17:55 · phase2-cleanup-round（清账轮)· backlog open 全处置
- 对齐: 用户指示「把 pause 前遇到的问题全部完成」——backlog open P1×1+P2×15 全处置:可动的 15 项全修,5 项判 defer/wontfix 并注明理由
- 后端: cron 改本地墙钟语义(收口 question 8d6ac767,e2e 验 0 9 * * *→本地 09:00 +08:00,DTO 不变 notch 无影响);会话自动命名(首条用户消息);summary +days 窗口(周回顾)
- 前端: 笔记/日记行内编辑(PATCH);任务三模式调度(cron/every/at,at 本地转 UTC);已转任务徽章;⌘Enter 提交;ConfirmGate 二段删除(速记/日记/任务/日历/记忆,共享 util);日历月网格(列表|月 双视图);Chat system_prompt 暴露+CMP 徽章;Research 无 provider 提示;Monaco 主题热更;Rail bind 警告;Mail toEvent UTC;Today .pg tabular 合规+framed 漂移对齐
- 仍留人(open P2×5): 日记附图(schema 迁移不猜)/Chat 接 RAG 上下文(架构切片)/Skills 真遥测(需 CC hook)/notch 侧设置/对比历史重开
- 验证: 前端 build ✓/check 0 错 0 警(250 文件)/test 158(+2);后端 pytest 184 绿;e2e:cron 本地时间/编辑往返/二段删除武装→确认/月网格 dark 截图
- VibeHub: record_decision F6「cron 本地语义+记录清账」→ 591d9140;F8「跨模块扫尾」→ a75a45ec (ai_proposed)
- 状态: ✅ commit(feat/design-shell-today,未合 main)｜❓需确认: cron 本地语义为代拍板,VibeHub 待你确认

## 2026-07-02 16:35 · phase2-round11-settings（夜间模式·pause 前末轮）· 设置模式
- 对齐: 阶段2 第11轮——Settings 模式落地(主题三态持久化+今日 accent 换色+后端/MCP 状态);用户「pause」后本轮收尾即停
- 设计基线: DESIGN.md(账本行/mono act/色块 3px 例外/LOCAL 角标;未改)
- 改动: 新增 `lib/Settings.svelte`(主题 radio 三态/accent 10 色块/healthz 状态/MCP 注入状态+按钮);`Shell.svelte` 挂 settings 模式替占位;`theme.svelte.ts`(+localStorage 持久化+init 恢复);theme.test +1(持久化,内存 stub localStorage)
- 功能可用性: e2e 真后端:切暗→reload 仍暗(持久化闭环)→accent 现场换色→复原跟随系统;后端 ok·v0.0.1 与 MCP NOT INJECTED 真状态渲染;注入按钮未实点(改用户 .mcp.json 留显式操作)
- 取舍: 本机 hook/媒体源属 notch 伴侣侧、K/V-secrets 管理 UI、accent 持久化(设计定当日轮换)记 P2
- 复查: 清 P1(settings 占位+主题无入口+不持久化);新增 P2×1
- 契约/notch 影响: 无(只读消费 /api/orchestration/mcp 与 /healthz)
- VibeHub: record_decision「阶段2·轮11 Settings 落地」→ 083ea1be (ai_proposed, F8)
- 验证: npm build ✓/check 0 错 0 警(249 文件)/test 156(+1);视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无｜⏸ loop 已按用户指令暂停(cron d509f1a7 已删)

## 2026-07-02 15:35 · phase2-round10-agentview（夜间模式）· F5 编排切片
- 对齐: 阶段2 第10轮——AgentView 座舱化(清 backlog P1;此前 10 个 emoji 图标违禁最重)
- 设计基线: DESIGN.md(框选视口=活的输出/mono 标签/语义色配给/禁 emoji;未改)
- 改动: `orchestration/AgentView.svelte`(重写:AGENT 观测 tag+状态描边徽章、caret 指令输入、ACP 事件流=框选视口+mono 类型标签 SESS/MSG/TOOL/OK/ERR/PERM/RATE/END+语义色调、历史发丝行;事件文案与 reducer 一字未动)
- 功能可用性: 视图渲染+空态 e2e 核过;真跑 agent=付费 Claude Code 不实跑(m3 stub 测试链覆盖;真实格式核对归既有 needs-human df66321e);只读消费 /api/orchestration/runs(notch 共用端点未改)
- 取舍: tool_call 联动驾驶舱高亮(既有)保留;多后端/多 agent Teams 仍 P1 期(用户已拍板)
- 复查: 清 P1×1;全部 8 个模式视图至此全部座舱化完毕
- 契约/notch 影响: 无(未改共用端点,只读消费)
- VibeHub: record_decision「阶段2·轮10 AgentView 座舱化」→ 27dbe441 (ai_proposed, F5)
- 验证: npm build ✓/check 0 错 0 警(248 文件)/test 155;视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 15:20 · phase2-round9-cockpit（夜间模式）· F1 驾驶舱切片1
- 对齐: 阶段2 第9轮——驾驶舱主视图(分栏/文件瓦片/预览)座舱化 + Monaco Diff 跟随双主题
- 设计基线: DESIGN.md(瓦片零圆角/发丝/accent 底线 tab/语义绿=活动;未改)
- 改动: `cockpit/CockpitView.svelte`(tab+分栏发丝)、`FileBrowser.svelte`(mono 路径栏/↑/跟随 act/发丝瓦片/selected accent/changed 绿闪/徽章 mono;⬆→↑)、`PreviewPane.svelte`(mono 标题/tab/tile code 块/token Markdown)、`DiffView.svelte`(Monaco theme 跟随 isDark,修暗色下白块)
- 功能可用性: e2e 真后端:开 /Users/victor/work/AI-workspace/helm→瓦片列出→选 DESIGN.md→Markdown 预览+预览/Diff tab;文件浏览/预览/终端/监听/diff 功能未动(m1-m6 既有)
- 取舍: 文件类型图标保留 FanBox 实体色(功能性着色同语法高亮);xterm 黑底终端惯例保留(P2 记账);Monaco 不随主题热更(P2)
- 复查: 清 P1(驾驶舱旧线框);新增 P1×1(AgentView 归 F5 轮)+P2×1
- 契约/notch 影响: 无
- VibeHub: record_decision「阶段2·轮9 驾驶舱座舱化+Monaco 双主题」→ 96a52d30 (ai_proposed, F1)
- 验证: npm build ✓/check 0 错 0 警(248 文件)/test 155;视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 15:05 · phase2-round8-research（夜间模式）· F3 研究视图
- 对齐: 阶段2 第8轮——Research 报告视图座舱化(模块清单下一项)
- 设计基线: DESIGN.md(仪表头/描边徽章/框选视口=活的过程/mono 配给;未改)
- 改动: `research/Research.svelte`(重写:RESEARCH 仪表头+status 徽章+SESSIONS 计数、caret 提问、mono 控件、进度框选视口、CLAIMS/SOURCES tag、引用 [n] accent mono、历史发丝行+状态徽章;🔍清)
- 功能可用性: start/stop/进度流/引用映射/存记忆/导出 Markdown(拒覆盖)/历史全保留未动;真实研究=真 web 搜索+付费 LLM,夜间不实跑(fake-provider 测试链已覆盖 WS 流/中断/恢复/报告渲染,m3/m4 既有)
- 取舍: 无 provider 时下拉光秃记 P2;富图表可视化仍属未来 polish(m4 决策)
- 复查: 清"旧线框"账(研究视图);新增 P2×1
- 契约/notch 影响: 无
- VibeHub: record_decision「阶段2·轮8 Research 座舱化」→ be1d869b (ai_proposed, F3)
- 验证: npm build ✓/check 0 错 0 警(248 文件)/test 155;视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 14:50 · phase2-round7-rag-skills（夜间模式）· F4 大脑切片2·模块收口
- 对齐: 阶段2 第7轮——知识库(RAG)+Skills 透视座舱化(清 backlog P1);F4 三视图齐
- 设计基线: DESIGN.md(账本行/描边徽章/语义色配给/禁 emoji;未改)
- 改动: `rag/Rag.svelte`(重写:stats mono/caret 路径输入/检索/源账本行+状态徽章/命中行 path+score+片段;📚🗑↻ 清)、`skills/Skills.svelte`(重写:计数 mono/账本行+方形启停+健康徽章+触发计数;⚡清)
- 功能可用性: e2e 真后端:建 1 文件源→UI 添加→后台索引 indexed(vector_count 1,真 embedder)→语义检索命中 score 0.6594→UI 移除,库净;Skills 真扫描 72 个渲染(72 健康);启停不实测(避免动用户 skill 态,单测覆盖)
- 取舍: Skills 触发计数恒 0/启停不真禁 Claude Code=既有已知限制(归 F5 集成),降 P2 留账
- 复查: 清 P1×1;F4 完整性:记忆(增/混检/置顶/删/导入导出)+知识库(源管理/索引/检索)+Skills(扫描/健康/启停)全可用,MCP 4 工具契约未动 → 模块判定基本可用
- 契约/notch 影响: 无
- VibeHub: record_decision「阶段2·轮7 RAG+Skills 座舱化,F4 收口」→ b7668756 (ai_proposed, F4)
- 验证: npm build ✓/check 0 错 0 警(248 文件)/test 155;视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 14:35 · phase2-round6-memory（夜间模式）· F4 大脑切片1
- 对齐: 阶段2 第6轮——大脑模式壳(BrainPanel)+记忆视图座舱化;修搜索结果不同步 bug
- 设计基线: DESIGN.md(仪表头/账本行/accent 配给/禁 emoji;未改)
- 改动: `memory/BrainPanel.svelte`(MEMORY 仪表头+三计数+accent 底线 tab)、`memory/Memory.svelte`(重写:分类 chips/导入导出 act/caret compose/搜索行/账本行 FACT tag+score+PIN+×/置顶 accent 左栏)、`memoryStore`(置顶/删除同步 patch 搜索 results)
- 功能可用性: e2e 真后端:加记忆→计数 001→混合检索命中(score 0.5913,向量检索 live)→置顶持久化→删除→空态;烟测清净
- 取舍: RAG/Skills 子视图仍旧线框(记 P1 下一轮);emoji 🧠📌📍🗑 全清(PIN 用 mono 文字钮)
- 复查: e2e 抓到搜索结果视图 pin/删不反映(store 只刷 items)当轮修;新增 P1×1(Rag/Skills 视图)
- 契约/notch 影响: 无(MCP 工具契约 ca4b5e64 未触碰)
- VibeHub: record_decision「阶段2·轮6 大脑壳+记忆座舱化」→ 56d20d32 (ai_proposed, F4)
- 验证: npm build ✓/check 0 错 0 警(248 文件)/test 155;视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 14:22 · phase2-round5-compare（夜间模式）· F2 多模型对比
- 对齐: 阶段2 第5轮——清 backlog P1:多模型并排对比+盲测(intent 4501c6dd),零后端改动
- 设计基线: DESIGN.md(框选视口=活的输出/mono 配给/accent 语汇;未改)
- 改动: 新增 `chat/compareStore.svelte.ts`(N 路:每 lane 真会话+独立 WS,delta 按 key 路由,stopAll/reveal/label)、`chat/CompareView.svelte`(2-3 路选择+盲测+caret composer+框选视口 lane 网格+STREAMING 标+揭晓)、`Chat.svelte`(COMPARE 侧栏入口,与 PROVIDERS 互斥;卸载断开 compare);+compare.test 3 测
- 功能可用性: e2e 真后端:加 Ollama→两路盲测运行→并行错误帧各自回显(模型 A/B)→揭晓显真名;跑完侧栏会话列表刷新;烟测数据清净
- 取舍: 对比会话持久化留档(不建后端 compare 端点,复用 sessions+ws——一能力一契约);真流式对比=付费未实跑(store 测+错误路径 e2e 覆盖);对比会话无侧栏标记/不可重开成对比视图记 P2
- 复查: backlog 清 P1×1;新增 P2×1;store 防重入/双路以下拒跑有测钉住
- 契约/notch 影响: 无(零后端改动)
- VibeHub: record_decision「阶段2·轮5 多模型对比+盲测」→ 805b58e7 (ai_proposed, F2)
- 验证: npm build ✓/check 0 错 0 警(248 文件)/test 155(+3);视觉 dev 5174 dark+light 对比网格截图核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

## 2026-07-02 14:10 · phase2-round4-chat（夜间模式）· F2 Chat 切片
- 对齐: 阶段2 第4轮——Chat/ProviderSettings 座舱化 + 会话/provider 删除全链路 + e2e 抓修 3 个真 bug
- 设计基线: DESIGN.md(账本无气泡/mono-sans 硬切/accent 活栏/语义色配给;未改)
- 改动: 前端 `chat/Chat.svelte`+`ProviderSettings.svelte`(重写:侧栏会话列表 accent 活栏、账本消息流 YOU/MODEL、assistant Markdown、流式 caret、自动贴底、composer、KEY 标、×删除)、`chatStore`(+deleteSession/deleteProvider/onerror 兜底)、`vite.config.ts`(proxy ws:true);后端 `chat/sessions.py`(+delete_session,先 flush 子行)、`chat/routes.py`(+DELETE /api/sessions/{id};provider 有会话引用 409);tests(前端 +1 后端补场景)
- 功能可用性: e2e(真后端):模板→加 Ollama provider→测试(错误路径)→建会话→发消息→WS error 帧回显→删会话/删 provider 204;流式协议(delta/done/stopped)后端 fake-stream 测试+store 单测覆盖(真流式=付费,夜间不实跑)
- 三个 e2e 抓出的真 bug: ① vite 字符串代理不转发 WS→dev 下聊天完全不通(P0);② WS 连不上 streaming 卡 true 冻死 composer;③ 删带消息会话 FK 崩 500(无 relationship flush 排序)——全修+测试钉住
- 取舍: 多模型对比(intent P1)/会话自动命名/system_prompt 暴露/RAG 上下文留 backlog;PROVIDERS 入口文字化(⚙ 属 emoji 禁区)
- 复查: e2e 驱动(本轮 review 重点=真链路);backlog 清 P1×2(旧样式+无删除)+修 P0×2/P1×1,新增 P1×1(多模型对比)+P2×2
- 契约/notch 影响: 无(chat 端点 notch 不消费;后端改动跑全量 pytest 绿)
- VibeHub: record_decision「阶段2·轮4 Chat 座舱化+删除链路+3 bug」→ 013988b5 (ai_proposed, F2)
- 验证: 前端 build ✓/check 0 错 0 警(245 文件)/test 152;后端 pytest 184+11skip;视觉 dev 5174 dark+light 核过
- 状态: ✅ 夜间自 commit(feat/design-shell-today,未合 main)｜❓需确认: 无

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
