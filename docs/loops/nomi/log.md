## R01 · 2026-07-07 00:05 · 块① NOMI token 重铸
- 对齐: app.css 全套 token 换血——浅色转正(#f6f6f7 画布/白 chrome/墨色字族),深色改 NOMI 深面板(#0f0f11/#1d1d21 卡),新增 --card/--pill/--g1/--g2/--grad/--shadow(-lg)/--radius 族+--onink;--grid 置 transparent(点阵退场);系统跟随逻辑反转(默认浅)。变量名向后兼容,旧组件零改动整体换皮。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r01-tokens-light.png(旧骨架+新皮肤,预期;逐块重塑在后续轮)
- 疑问: 每日 accent 机制(theme store 覆写 --acc)与 NOMI 固定橙紫渐变的关系待用户拍板——暂保留每日色,accent 默认改渐变紫端 → backlog
- commit: feat/nomi-reskin
## R02 · 2026-07-07 00:10 · 块② 侧栏全局导航 + logo
- 对齐: Rail.svelte 整件重写——ORAGE 细丝竖条(58px icon rail/锚点/脉冲)退场,NOMI 白侧栏(250px)上位:娃娃脸 logo+Helm 品牌行/中文标签导航(图标+文字,--pill 胶囊激活)/底部两圆钮(记一条=openCapture,⌘K=openPalette)。Shell grid 列宽 --rail-w→--side-w。memory 入口保留(设计稿未画,功能不减)。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r02-sidebar.png——与稿侧栏一致(hover/激活胶囊/圆钮)
- 缺口: 导航计数(记录 12/对话 3)未接真数据 → backlog P2;titlebar/statusbar 仍 ORAGE mono(后续壳块)
## R03 · 2026-07-07 00:17 · 块③ 今日板块
- 对齐: Today.svelte 整件重写——问候(时段词,Victor)+日期摘要行 → CaptureDock → NOMI 七卡网格(任务/日程/日记/智能体/最近项目/今日收藏/简报·世界输入)。真数据 derived 全量移植(tasks/notes/agent/cockpit/calendar/briefing);A×C v3 时钟锚/区块聚光/右柱退场,briefing 功能收进第七卡(功能不减)。新增今日收藏卡(AI 管线产出:meta.type 色点+标签)。
- 修型: 4 个 check 错(Task.schedule_kind/CalEvent.summary/inspiration 枚举/prompt null)当轮修
- 门: build ✓ / check 0/0 / test 204 全绿(Today.test 断言随新结构更新,语义保留)
- 视觉: shots/r03-today.png——问候/卡网格/空态/HN 简报真数据 ✓
- 缺口: CaptureDock 仍 ORAGE 皮(独立块) → backlog P1
## R04 · 2026-07-07 00:20 · CaptureDock NOMI 化(backlog P1 清)
- 对齐: 逻辑层零改动,纯换皮——白卡容器(圆角+阴影,L 角/边框退场)/kind 胶囊(黑激活)/任务双轨渐变胶囊/灰胶囊输入行/渐变发送钮(disabled=灰胶囊)/问大脑答案卡(白卡+spark)。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r04-capture.png——今日板块(问候+坞+七卡)整体成型
## R05 · 2026-07-07 00:24 · 记录页整体换皮
- 对齐: JournalView 皮肤层——tab 白胶囊容器+黑激活/输入行灰胶囊盒+渐变主钮/天组白卡化(圆角+阴影)/收藏卡圆角浅底/AI 小结框圆角化(L 角退场)/日界标 sans 化/标题中文化(记录)。结构与功能(编辑/四向转化/确认删/收藏卡/待办/定时/日历)零改动。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r05-journal.png——速记流已是 NOMI 脸(白卡天组+圆角收藏卡)
- 缺口: 三视图信息架构(Timeline/Canvas/Calendar 黑胶囊)未动——现仍是 速记/日记/任务/日历 四 tab;Canvas 视图不存在 → backlog P1;Calendar.svelte 仍 ORAGE 皮 → backlog P1
## R06 · 2026-07-07 00:29 · 对话板块换皮
- 对齐: Chat.svelte——消息流从账本(YOU/MODEL 左标)改 NOMI 气泡(用户黑胶囊右对齐/AI 白卡+spark「Helm 大脑」);会话列表白卡化(激活=描边环);composer 灰胶囊+黑发送;新会话表单胶囊输入;act 钮系胶囊化。流式/停止/删除/对比/Provider 功能零动。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r06-chat.png(会话列表真数据白卡 ✓)
- 缺口: CompareView/ProviderSettings 两个子面板未换皮 → backlog P2
## R07 · 2026-07-07 00:34 · 研究 + 设置换皮
- 对齐: Research(标题 sans 中文/问题输入灰圆角盒/act 渐变主钮/report·framed 白卡化)+Settings(标题中文/act·sel 胶囊化;主题段/AI provider 段功能原样)。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r07-research.png + r07-settings.png
- 缺口: 驾驶舱家族(3187 行)未换皮 → backlog P1(单独轮);Research 历史列表/badge 细节待精修 P2
## R08 · 2026-07-07 00:45 · 记录三视图重构(P1 清)
- 对齐: JournalView 信息架构 → 稿的三视图:黑胶囊 Timeline/Canvas/Calendar + 分类 chips(全部/速记/日记/任务,role=tab)。Timeline=原四 tab 功能全量收编(速记流·日记天组+AI 小结·任务派发/待办/定时,由 filter 切换,compose 智能路由);Canvas=新组件 CanvasView(白卡/收藏卡自由拖拽,位置 localStorage,真数据);Calendar=原样待周视图轮。深链 journalIntent 旧值兼容映射;noteToTask 跳 timeline+task。
- 门: build ✓ / check 0/0(修 line-clamp 双写) / test 204 全绿(旧测试语义靠 chips role=tab 无缝通过)
- 视觉: shots/r08-timeline.png + r08-canvas.png(Canvas 真收藏卡+拖拽 ✓)
- 缺口: Canvas 连线/cluster 需关系数据(后端无此概念) → backlog P2 add_question;分类 chips 未迁全局侧栏 → P2;收藏细分(视频/论文/灵感)未做 → P2
## R09 · 2026-07-07 00:55 · Calendar 周视图(P1 清)
- 对齐: Calendar.svelte 新增周视图并设为默认(周/列表/月三档,月·列表功能原样保留=功能不减):7 列虚线格(8-22 × 44px)/白浮卡(日程紫左沿·任务绿左沿,按分钟定位)/今天列高亮/当前时刻线(橙点+线)/周导航+今天+GMT 标签——对齐稿 Calendar。
- 门: build ✓ / check 0/0 / test 205 全绿(agenda 两条断言改为先切列表;新增周视图落格测试)
- 视觉: shots/r09-week.png
## R10 · 2026-07-07 01:02 · 驾驶舱 chrome 换皮(P1 清)
- 对齐: Sidebar(搜索胶囊/项目行圆角胶囊激活)+DockHost(zone tab mono 下划线→sans 胶囊)。终端本体保黑(稿同款黑终端块);dock 拖拽/吸附/布局持久化功能零动。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/r10-cockpit.png(浅 chrome+胶囊 tab+黑终端,真终端在跑)
- 剩余: FileBrowser/PreviewPane 内部细节(按钮/列表行)P2 精修
## R11 · 2026-07-07 01:10 · 壳 chrome NOMI 化(P2)
- 对齐: titlebar(HELM wordmark/假遥测 meta 删,细白拖拽条+右缘真后端状态点)/ORAGE fiducial+坐标 chip 装饰整体退场/statusbar 假遥测段(tok/RAG/NEXT/◇chrome)删,保留真功能四钮(上下文/终端/⌘K/⌘N),sans 淡字胶囊化。孤儿样式清零。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/r11-shell.png——全站再无 mono 骨架残留
## R12 · 2026-07-07 01:17 · P2 批扫:Provider/Compare 面板 + 导航真计数
- 对齐: ProviderSettings+CompareView 的 act 家族/输入定点胶囊化(7 处 patch);Rail 导航计数接真 store(记录=notes.length/对话=sessions.length,>0 才显示)——对齐稿侧栏计数。
- 门: build ✓ / check 0/0 / test 205 全绿
## R13 · 2026-07-07 01:25 · 分类过滤迁全局侧栏 + 收藏细分(P2 清)
- 对齐: journalFilter 提升为 layout 共享状态;Rail 在记录模式渲染稿的两段分类(记录:全部/速记/日记/任务 · 收藏:全部收藏/视频/论文/灵感,胶囊激活),与页内 chips 同源双入口;noteItems 支持 collect(meta.url)/youtube/paper/inspiration 细分过滤。
- 门: build ✓ / check 0/0 / test 205 全绿(共享 store 测试间重置)
- 视觉: shots/r13-sidecats.png——「全部收藏」过滤流只剩链接收藏,与稿侧栏结构一比一
## R14 · 2026-07-07 14:10 · 残留清剿:全局表单皮 + Calendar 内部 + 记忆板块(用户指正)
- 对齐: ①全局 select/datetime 皮(app.css:胶囊+自绘 SVG 箭头,原生外观退场——研究/记忆/派发/加事件全部受益),清掉盖它的 scoped 残留;②Calendar 内部(周/列表/月·导入导出 CalDAV·加事件→胶囊,黑激活;事件标题/时间输入→胶囊盒;AGENDA 标签 sans 化,7 patch);③记忆板块(漏网):MEMORY→记忆中文标题/黑胶囊 tab/chips 胶囊/输入胶囊(BrainPanel+Memory 共 6 patch)。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/r14-memory.png + r14-calendar.png
## R15 · 2026-07-07 14:35 · 溢出 bug + 全局可拖分割条(用户指正)
- 修 bug: 会话卡标题溢出(.st 缺 min-width:0 flex 截断链断)+侧栏横向滚动条(overflow-x hidden);Chat scoped select 盖住全局皮(残留清)。
- 新能力: 通用 Resizer.svelte(拖 CSS 变量+localStorage 持久,hover 细线高亮)——四处接入:主侧栏(--side-w 180-360)/上下文面板(--ctx-w)/对话会话栏(--chat-side 180-380)/驾驶舱侧栏(--cockpit-side 160-360)。所有分割线可拖,宽度记住。
- 门: build ✓ / check 0/0 / test 205 全绿(Resizer localStorage 防御测试环境)
- 视觉: shots/r15-chat.png(截断/胶囊 select/计数 ✓)
## R16 · 2026-07-07 15:05 · 记录详情弹层 + option 字体修(用户反馈)
- 新组件 NoteDetail.svelte:点速记/收藏正文打开白大卡详情——kind 徽章+时间/hero 大图/标题/原文全文/AI 摘要盒(spark)/来源+标签+时间地点线索/操作(打开原链接·编辑·→任务·关闭),遮罩+Esc 关。
- 修: select option 原生弹层 serif 回退(CSS 变量在原生弹层不解析→显式字体栈)。
- 后端核验: 单进程 83761 在跑,healthz ok(用户问数据库——数据一直从 SQLite 来)。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/r16-detail.png
## K1 · 2026-07-07 16:30 · 速记瀑布卡墙(批次 2)
- 对齐: Timeline 速记/收藏视图 → masonry 墙(columns 250px 自适应):收藏卡(封面/徽章/标题/摘要 3 行钳/站点+标签)+便签卡(N 徽章+原文),hover 浮操作行(编辑/四转化/确认删全保留),点标题/正文开详情。破图 onerror 隐藏;阅读容器放宽 1180。孤儿样式(mcard 家族/note body)清零。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/k1-wall.png(用户真实数据在墙上)
## K2 · 2026-07-07 16:45 · 速记详情「原文主角」重排
- 对齐: NoteDetail 重写——原文 17px/1.85 主位(URL 内联紫高亮短显);「提到的内容」附件卡(徽章/标题/一行摘要/来源·已解析/打开,当前单链接,K3 后自动多张);标签+时间地点线索胶囊;AI 注脚一行(hover 展开);meta.when 存在时主钮=「→任务 · 线索」(线索变行动);纯收藏(内容≈链接)保留 hero 大图态。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/k2-detail.png(用户真实速记:原文主场,AI 一行注脚)
## K3 · 2026-07-07 17:05 · 后端多链接解析
- 对齐: enrich 管线 all_urls(去重保序,上限 5)——每个 URL 各抓一份 meta,落 meta.links[];顶层字段=第一个链接(向后兼容:notch/旧前端零破坏,纯加字段)。前端 NoteMeta.links 类型+NoteDetail attachments 优先接 links(fallback 单链接)。
- 门: pytest 216 全绿(+2:all_urls 去重/多链接接线) / 前端 build·check·test 全绿
- e2e: 真实一条两链速记 → links=[youtube, paper] ✓ 顶层=YT ✓;后端已重启
## K4 · 2026-07-07 17:30 · 日记纸页
- 对齐: filter=journal → 640px 纸栏:统计行(今日字数/连续天数+AI 今日小结/周回顾)/小结白卡(spark)/「今天的页」置顶(大 textarea+⌘⏎+渐变写入)/一天一页(N月N日+周X+字数,md 正文,hover 编辑/确认删)。共用 compose 行让位(journal 由纸页自写);旧日记样式(day/entry/framed/sumbtns)清零;测试日期断言随新格式(6月27日)。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/k4-paper.png(真数据:14 字·今天/2 天连续/专注记录在页上)
## K5 · 2026-07-07 17:50 · 日记页详情
- 对齐: 新组件 PageDetail——点纸页日期头开全页阅读态:大日期/全文 md/专注块(regex 聚合当天「专注 N 分钟」,紫左沿)/这天的碎片时间线(当日速记/收藏/待办,时间+摘要行)/编辑这页。Esc/遮罩关。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/k5-page.png(真数据:专注 1 段 1 分钟·工作/三条碎片时间线)
## K6 · 2026-07-07 18:20 · 任务操作台
- 对齐: filter=task → 派发胶囊条(输入/cron 三模式胶囊/渐变加定时,fromNote chip 保留)+双列:待办清单(圆 checkbox 勾选=渐变勾+划线+800ms 完成即清,点正文开详情,hover →交给 agent)/定时卡(渐变 switch 启停/cron chip/下次时间/运行历史抽屉 rdot 红绿/确认删)。旧行式任务 UI 退场,孤儿样式清零;runbtn aria/rstatus 保测试契约。
- 门: build ✓ / check 0/0 / test 205 全绿
- 视觉: shots/k6-tasks.png
- 取舍: 待办无 done 字段(后端 Note 无状态列)→「完成即清」语义(勾选=划线动画+删除);要保留完成历史需后端加列 → backlog P2
## K7 · 2026-07-07 18:35 · 智能判类
- 对齐: CaptureDock 输入即判——规则实时判定(链接→收藏/时间词→任务/叙事→日记/疑问→问大脑),kind chip 自动切换+「AI · 判定原因」徽章(点击→手动);用户点 chip=手动接管(显示「手动·点回 AI」);发送后回自动。发送落库沿用后端 enrich(AI 摘要/标签/线索照旧)。
- 门: build ✓ / check 0/0 / test 206 全绿(+1 判类行为测试)
- 视觉: shots/k7-verdict.png(「明早 9 点跑回归」→任务+时间词徽章+双轨)
- 取舍: LLM 兜底判类(规则不确定时调后端)记 backlog P2——规则版零延迟已覆盖常见 4 类。
## K8 · 2026-07-07 18:55 · 专注链路(批次 2 全清)
- 对齐: 全局 FocusStore(focus.svelte.ts)——start(what)/stop→写「专注 N 分钟 · what」进今日日记/mmss/圆环 deg。速记墙顶活卡(conic 圆环计时+任务名+渐变停止);待办 hover「开始专注」(带着待办内容发起并跳速记);CaptureDock 专注 kind 改走 store(与墙顶活卡同一状态)。闭环:任务发起→速记区活着→归宿日记→PageDetail 专注块聚合。
- 门: build ✓ / check 0/0 / test 206 全绿
- 视觉: shots/k8-live2.png(活卡 00:03 计时中;墙上还见 enrich 实时新卡)
## R+ · 2026-07-08 · 记录页顶部重设计 + Calendar 视图补稿 + 整卡可点(用户三点反馈)
- 稿(helm-journal-kinds.html): 顶部重构=标题行+「视图(Timeline/Canvas/Calendar)×分类」两组控制一行;新增 Calendar pane(周历落格四色分类沿+时刻线+『分类 chips 同样作用』说明);旧账本元素不再出现在稿中。
- 实现: 记录页旧 compose 行/gut(随手/收集)/SCRATCH mono 标签全退场——顶部换智能捕获坞(CaptureDock,K7 判类内置,一个入口自动分流);墙区脱账本壳直接铺;头部计数中文化(10 条速记·3 篇日记·0 个任务);墙卡整卡可点开详情(操作钮/编辑态 stopPropagation,键盘 Enter 同开)。
- 门: build ✓ / check 0/0 / test 206 全绿
- 视觉: shots/top-clean.png + spec-cal.png
## R+ · 2026-07-08 · 信息架构定稿:分类为主,双 icon 切展示,日历=全量(用户拍板)
- 结构: 大视图胶囊组退场——分类 chips(全部/速记/日记/任务/日历)为主维度;Canvas/Timeline 只是速记·日记内部展示方式,右上两枚小 icon(☰ 列表/⊞ 画布,用户给的图形);任务/日历无 icon。
- Calendar 全量: 周历落格所有记录——events(紫)/tasks(绿)/速记·收藏(蓝)/日记(琥珀)按时间上格。
- 稿(helm-journal-kinds.html)同步同构。门: build ✓ / check 0/0 / test 206 全绿。
- 视觉: shots/f1-chips.png + f1-cal.png(日记琥珀卡/速记蓝卡已在周历上)
## 批次3 · 2026-07-08 · 捕获坞去重 + AI 归类 + 日记画布(用户确认稿后实现)
- 捕获坞: kind chips 行撤——输入行内 AI 判定徽章(点=轮换 note→journal→task→ask)/判为任务双轨浮现/⏱ 专注钮/疑问句→问大脑;测试改语义(207)。
- AI 归类: 后端 enrich 双 prompt 出 meta.topic(2-6 字集合名);NotePatch+service 支持 meta 整份回写(纠错)。前端:墙顶「按时间/按主题·AI」;主题分区(计数+AI 维护)+未归类;卡上主题胶囊 hover ×=移出集合(PATCH 回写);涌现:≥3 条未确认→虚线建议卡,创建/忽略记 localStorage(helm.topics.ack)。
- 日记画布: JournalCanvas 页卡(日期/首行/字数/专注·碎片徽章)自由拖放,位置 localStorage,点开=PageDetail 全页回放;日记分类也吃双 icon。
- 门: 前端 build/check 0/0/test 207 全绿;pytest 217 全绿;后端已重启。
- 视觉: shots/b3-dock.png / b3-topics.png / b3-jcanvas.png
## T1 · 2026-07-08 · 后端分诊管线
- 契约: KINDS 收编 task/idea(顺带修捕获坞「给自己的任务」kind:task 落库 422 活 bug);NoteBody 加 triage:bool(默认 false,notch 不传不受影响);POST 响应加 triage 回执块;meta 新增 when/where/due/triage(by:rule|llm, confident)。
- 实现: helm/notes/triage.py——规则判类(链接→任务→想法→日记→速记,与前端 K7/设计稿 demo 同口径,后端为准)+ 人话时间(明早/明晚/今晚/明后天/周X/X点前/每天…→ label+due 本地 ISO;recurring 结果是 T2 人话排期的地基)+ 地点(懒匹配+动词边界前瞻,宁缺毋滥不吞动词);enrich 改 meta 合并不覆盖(规则种子优先,LLM 只补空),LLM 兜底改判仅从 confident=False 升格、用户 enrich 期间手动改类不覆盖。
- 门: pytest 240 全绿(+23:triage 单元+API+兜底)/ 前端 build ✓ check 0/0 ✓ test 207 全绿(8 个 unhandled 为 cockpit FileBrowser jsdom 既有噪音,本块未动前端)
- 取舍: 判任务=kind:task 落库即前端待办列(todoItems 既有契约),不建独立 task 行,无 task_id;「分诊记住纠正」记 backlog [T1+] P2。
- T5 提醒: 契约已变(只加不减),T5 块通知 notch 线接回执 UI。
## T2 · 2026-07-08 · 人话排期
- 契约: TaskBody 的 name/schedule_kind/schedule_value 全部可省——POST /api/tasks {prompt} 整句即可,排期从句子解析(顺带修捕获坞/notch「交给 agent」只发 {prompt} 的 422 活 bug);新增 GET /api/tasks/parse(实时徽章,与提交同一解析器);to-task 收 schedule_nl。原句在 task.prompt,人话标签存 schedule_value.nl(compute_next_run 不受额外键影响);显式 schedule 老契约不动。
- 实现: helm/tasks/nl.py——每天/每晚/每周X/工作日/每月N号→cron,每N小时/分钟→every,一次性(明早9点/周五下午3点)复用 T1 triage.parse_when→at(本地转带时区 ISO);「每周」没说哪天默认周一(注明可纠)。前端:派发条三模式表单(cron/every/at select+输入)退场→单输入行+250ms 防抖 /parse 徽章(spark+人话)+「交给 agent」渐变钮;fromNote 流改为 chip+人话时间输入(toTaskNL);定时卡 chip 显示 schedule_value.nl,无 nl 的老任务退回模式名。
- 门: pytest 254 全绿(+14)/前端 build ✓ check 0/0 ✓ test 213 全绿(+6,含 fromNote 新语义改写)
- e2e: 真发「每天早上9点汇总未读邮件」→ 卡片 chip「每天 09:00」+ expr "0 9 * * *" ✓;试发任务已删,后端已重启(8769)。
- 视觉: shots/t2-dispatch.png(输入行+徽章)/ t2-card.png(定时卡人话 chip)
- 发现: next_run 时区显示漂移(9点显示17:00)为 K6 期既有 bug → backlog [T2+];无时间任务默认行为 → backlog Q-T2(现 422 提示,不猜)。
## T3 · 2026-07-08 · 前端对齐 kinds 稿(回执/徽章/两层待办)
- 对齐: ① 捕获坞自动挡改走后端分诊(POST triage:true 不带 kind,后端为准)→ 发送后结构化回执 toast(类型 chip[想法蓝/任务渐变]+when/where chips+「→ 已入待办」+「改」轮换纠类=PATCH kind 回流);手动接管仍显式 kind 不走分诊;判类规则补「想法」档(CYCLE note→idea→journal→task→ask)。② 速记墙收编 idea/task:想法卡蓝 tag;任务回执卡橙左沿+tag+抽取 chips+「已入待办 →」跳任务列。③ 待办两层任务行:标题行/chips 行(when[24h 内含过期=橙 duesoon]/@where/spark 速记分诊),due 临近升序在上、无 due 按新旧;操作(专注/→ agent)hover+focus-within 浮现;创建时间戳退场。
- 后端小补: PATCH 改类到 journal 自动补 journal_date(纠错不落「未注明日期」)。
- 门: pytest 254 全绿 / 前端 build ✓ check 0/0 ✓ test 216 全绿(+3,含 CaptureDock 自动/手动挡契约)
- e2e: 真发「明晚8点在家帮荣荣姐做龙虾」→ 回执 toast[任务·明晚 20:00·@家]+墙上回执卡+待办两层行全链路 ✓;试发已删,截图 shots/t3-receipt.png / t3-todo.png。
- 取舍: 「完成沉底+已完成分区」依赖 K6 done 列(待拍板)→ [T3+] 备位;深色 duesoon 用橙透明底(稿只给浅色值)。
## T4 · 2026-07-08 · 日记每天一篇
- 对齐: ① 天内段落按 created_at 升序拼一篇(journalByDate 单源改序,纸页/PageDetail 同吃),\n\n 段落语义与 notch journalToday 一致;② Today 日记卡:字数+连续天数保留,新增今日聚合全文预览(pre-line,clamp 5 行)+空态引导+foot「N 段 · 续写 →」(journalIntent=journal 落到记录页日记 tab 今天的页)。
- 修 bug: JournalView.today() 用 toISOString()=UTC,凌晨 0-8 点「今天的页」错一天(实测 02:02 显示 7月7日)——改本地拼日;全仓无同类。
- 门: pytest 254 全绿 / 前端 build ✓ check 0/0 ✓ test 219 全绿(+3:Today 卡拼序/续写导航/空态,纸页升序)
- 视觉: shots/t4-today.png(卡:39 字·连续 3 天·两段升序预览·续写→)/ t4-paper.png(修复后今天的页=7月8日);测试日记两条已删。
- 口径差记录: notch journalToday 按 createdAt 日过滤、主 app 按 journal_date——跨日补写(凌晨写昨天)两边归属不同,T5 通知 notch 线对齐(建议 notch 改吃 journal_date)。
