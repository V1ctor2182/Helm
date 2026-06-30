# Notch 优化 Loop · 处理流水

> 每把 `helm-notch-pro.html` 设计的一块对齐进 Swift App,loop 在这里追加一条。格式见 `notch-loop-procedure.md` 附录 C。
> (下面 2026-06-30 那批是早期"改 HTML"阶段的历史记录,现 loop 已改为「HTML 只读、改 Swift」。)
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

## 2026-07-01 00:34 · swift-align-11-focus-timer
- 设计源: helm-notch-pro.html(cap focus 态 / startFocus / stopFocus / renderBar focus 分支 / .focusrun / .bfocus)
- 界面: 专注计时(capture focus kind + 折叠条专注态)
- 做了: Core CaptureKind +.focus;NotchModel +focusOn/focusWhat/focusStartedAt +focusElapsed(at:)/startFocus/stopFocus(at:);submit .focus no-op;viewHeight cap focus 268/300(+3 测)。App captureCell focus 分支 focusBody(未开始=输入+开始专注;进行中=大计时 mm:ss 脉冲点+focusWhat+停止并记录);折叠条专注态 左 timer+what、右 mm:ss accent(TimelineView 1s)。
- 取舍: focus 选 4th CaptureKind(chips 现 速记/日记/任务/专注);stopFocus 暂只算分钟不发后端(POST /api/focus 待后端 TODO);ask 仍未端口(TODO)。计时用开始时间推导(可测+TimelineView 平滑)。
- 改动: HelmNotchCore/Models.swift(+.focus)、NotchModel.swift(+focus 态/viewHeight/submit)、Tests(+3)、HelmNotchApp/NotchView.swift(captureCell focus 分支/focusBody/collapsedLeft·Right focus 态/placeholder)
- VibeHub: record_decision「专注计时」→ f00784c8-9f18-4a1a-940d-30c0cd62117e (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,42 测 0 失败(+3:start 取 what/空回退、stop 150s→3min、focus viewHeight)。逐项对照 HTML CSS:focusrun ft 42px+dot 脉冲、fstop accent、bfocus mm:ss accent。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: /api/focus 发送、ask(问大脑)kind(均 TODO)

## 2026-07-01 00:29 · swift-align-10-permission-banner
- 设计源: helm-notch-pro.html(bannerHTML / notch.banner / render banner 分支 / S.mode==waiting)
- 界面: 等权限 banner 态(顶层覆盖折叠/展开,620×208)
- 做了: shell 加 banner 分支:有 needsAttention session 时弹 permissionBanner(橙点+Permission Request·folder+⌘Y/⌘N 提示+⚠︎ pendingTool+pendingDetail 等宽黑块+Deny 白/Allow accent 双钮→resolveLocalPermission)。Controller canvasSize 宽加 640 下限容纳 620;host.activeSize 在 localAttentionCount>0 返回 620×208。
- 取舍: HTML banner 显代码 diff(硬编码 demo),hook 目前只传 tool/detail → 显真实 pendingDetail 不伪造 diff(真 diff 需 hook 传,TODO);⌘Y/⌘N 键盘快捷暂不接(面板非 key,TODO);resolve 后 waiting 清零自动回正常。无新 Core(复用已测 resolveLocalPermission)。
- 改动: HelmNotchApp/NotchView.swift(body waiting 计算、shell banner 分支、permissionBanner)、NotchController.swift(canvasSize 640 下限、activeSize banner 尺寸)
- VibeHub: record_decision「等权限 banner 态」→ ac8c75a4-ddaf-4de9-8993-bbfdac1fffb2 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,39 测 0 失败(无新 Core)。逐项对照 HTML CSS:banner 620×208、perm ph 橙、diff 黑块、bbtn allow accent/deny 白 10%。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: 真实代码 diff 传输、⌘Y/⌘N 快捷键(均 TODO)

## 2026-07-01 00:25 · swift-align-09-capture-enrich
- 设计源: helm-notch-pro.html(V.cap / .ttog / .capatt / .recents / S.taskTo·capWhen·capWhere·showRecent)
- 界面: 速记模块丰富化(captureCell)+ Core 速记附加态
- 做了: Core +TaskTarget(me/agent) +taskTarget/captureWhen/captureWhere/captureShowRecent;viewHeight cap +showRecent→+64(min360);submit 折时间/地点进内容并清空(+3 测)。App captureCell 加:任务态 给自己/交给 agent 段切换;note/task 态 时间/地点 附件 chip(无值虚线 add→demo 值,有值实心+×删);最近卡片条(「最近X ▾」toggle 横滑卡片,按 kind 过滤 seed)。
- 取舍: focus(计时)/ask(问大脑)两 kind 暂不端口(独立功能,TODO),仍 3 kind chip;时间/地点 demo 固定值(选择器 TODO);最近 seed(后端 recents TODO);taskTarget=agent 暂走 /api/tasks(Cockpit 通道 TODO)。
- 改动: HelmNotchCore/Models.swift(+TaskTarget)、NotchModel.swift(+附加态/viewHeight/submit)、Tests(+3)、HelmNotchApp/NotchView.swift(captureCell+taskTargetToggle/attachmentRow/attachmentChip/recentsSection + recentSeed)
- VibeHub: record_decision「速记模块丰富化」→ 4824bc01-8de5-43ae-bc9f-47e4af88a7ef (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,39 测 0 失败(修 1 轮:viewHeight switch 表达式混 return → 内联)。逐项对照 HTML CSS:ttog 段、achip/aadd 胶囊、rcard 160 卡片+k 标签。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: focus/ask kind、时间地点选择器、最近真源、agent 派发通道(均 TODO)

## 2026-07-01 00:20 · swift-align-08-settings-dark-modal
- 设计源: helm-notch-pro.html(settingsHTML / setdlg / 外观·后端·本机·媒体分区)
- 界面: 设置窗口重做成深色分区 modal
- 做了: SettingsView 重写为深色 #161719 分区(外观/HELM 后端/本机 CLAUDE CODE/媒体),发丝分隔行;接有真实 backing 的控件——主题色 palette 10 dot(点击→fixed+index,选中白环)+ 配色模式胶囊段(daily/hue/fixed→themeMode);连接状态行(model.connection);hook 安装/卸载+状态;默认播放源(点击 cycleMediaSource)。AppDelegate 窗改 440×540+darkAqua+深底。
- 取舍: HTML 的背景材质玻璃/开机自启/点外收起/每天随机 toggle 无后端支撑 → 不端口假开关(以「打开 Helm 完整设置」承接,TODO)。Core 已有 themeMode/fixedColorIndex/connection/mediaSource,纯 App 改。
- 改动: HelmNotchApp/SettingsView.swift(全重写)、AppDelegate.swift(窗尺寸+深色)
- VibeHub: record_decision「设置窗深色分区 modal 重做」→ c82ae547-1b70-477c-959f-ade83abc9e61 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,36 测 0 失败(纯 App UI)。逐项对照 HTML CSS:setsec 9 大写、accdot 24+选中环、模式胶囊 accent、setrow 发丝线、sdot 状态。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: 材质/自启/点外收起/每天随机 toggle 待后端支撑(TODO)

## 2026-07-01 00:16 · swift-align-07-swipe-gestures
- 设计源: helm-notch-pro.html(notch wheel handler / switchModule / switchDev)
- 界面: 触控板滑动手势(横滑切模块 · Dev 内纵滑分页)
- 做了: NotchController 装 NSEvent.addLocalMonitorForEvents(.scrollWheel);仅展开+未锁+指针在可见 shell 矩形内响应,0.35s 冷却=一次滑一步。映射同 HTML:Dev 内 |dy|>|dx|>6→switchDev(夹紧);否则 |dx|>|dy|>6→switchModule(环绕)。AppKit delta 取负翻转(右滑→下一模块、下滑→下一页)。
- 取舍: 只做触控板 scroll 路径(MBP 主路径);鼠标拖拽切换暂不做(怕与 dock/按钮 tap 冲突,dock 点击已可用,TODO)。delta 符号实机可能需翻(TODO)。switchModule/switchDev 逻辑 block1 已测;本块纯 App 接线。
- 改动: HelmNotchApp/NotchController.swift(scrollMonitor nonisolated(unsafe)/installScrollMonitor/handleScroll;deinit 移除)
- VibeHub: record_decision「触控板滑动手势」→ 28654ce3-ebea-401f-ad52-af534f007a73 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,36 测 0 失败(修 1 轮:deinit 非 Sendable 访问 scrollMonitor → nonisolated(unsafe))。手势实机目视待用户(符号方向)。
- 状态: ✅ 待 review  |  ❓需确认: scroll delta 符号方向实机校准;鼠标拖拽切换(均 TODO)

## 2026-07-01 00:12 · swift-align-06-per-view-auto-height
- 设计源: helm-notch-pro.html(viewHeight() / VH / DEVSECS[].h / --eh / NTOP)
- 界面: 展开面板高度按当前模块自适应 + 切换平滑过渡(Core 算高 + shell 用之)
- 做了: Core viewHeight()(dash172/media330/clip232/cal 月312周240/dev 204·248·252·252/cap task300·其余256)+topBarHeight30+autoExpandedHeight。App shell 展开高度改 autoExpandedHeight + .animation(.42s timingCurve, value: autoExpandedHeight) 平滑过渡;Controller host.activeSize 高度同改;resize handle 改仅宽度。
- 取舍: 与 decision 09eb9245「用户可拖拽持久化尺寸」冲突 → 按 loop 忠实实现 HTML 自适应高度,开 [needs-human] question 7597d8c5 等拍板;持久化高度暂留可回退;cap 的 recents/focus/ask 高度分支未端口(只覆盖 note/journal/task,TODO)。canvas 大画布不变(slack 容纳最高 360)。
- 改动: HelmNotchCore/NotchModel.swift(+viewHeight/topBarHeight/autoExpandedHeight)、Tests(+4)、HelmNotchApp/NotchView.swift(shell 高度+过渡动画、resize 仅宽)、NotchController.swift(activeSize 高度)
- VibeHub: record_decision「per-view 自适应高度端口」→ 21778dfc-f9fd-4cb1-a13a-ee8f278c4fe8 (ai_proposed);add_question「[needs-human] 自适应高度 vs 拖拽持久化」→ 7597d8c5-d12f-4df2-9715-e5d996410eb8 (ai_proposed)
- 自检: 硬门 swift build + swift test 全绿,36 测 0 失败(+4 高度:各模块/dev 子页/cal·cap 态/autoExpanded 加顶栏)。视觉实机待用户(切模块高度过渡)。
- 状态: ✅ 待 review  |  ❓需确认: 面板高度策略(已开 7597d8c5);cap 非 task 态高度细分待 cap 丰富化块

## 2026-07-01 00:08 · swift-align-05-calendar-week-month-agenda
- 设计源: helm-notch-pro.html(V.cal / calhd2 / wstrip / mgrid / mrail / agenda / S.calExpand·calSel·calOff)
- 界面: Calendar 模块(calendarModule 取代复用周条 cell);Core 加日历视图态
- 做了: Core +calMonthView(默认月)/calMonthOffset/calSelectedDay(今天)+nav/toggle/select(+3 测)。App calhd2(月名17+年+Today pill+grid/rows 段 toggle+‹›)+ calbody 左右:左 月网格(MON..SUN+6 周+首列月份导轨,格出月淡/今天白圆深字/选中 accent 环/点击选日)或周条(大月名年+7 列,今天 accent/选中环);右 议程(选中日标题+计数+事件行 evtime+summary+accent 点 / 空态「这天没有安排·＋到 Helm 新建」)。Monday-first (weekday+5)%7。
- 取舍: 议程事件仅「选中日=今天 且 model.events 非空」时显示(per-day 需后端日期范围查询,TODO);HTML CAL_ITEMS 多日 demo 不照搬(不虚构后端数据)。网格日期数学用 Foundation Calendar 在 View 构建。
- 改动: HelmNotchCore/NotchModel.swift(+日历态/nav)、Tests(+3)、HelmNotchApp/NotchView.swift(calendarModule/calhd2/calWeekStrip/calMonthGrid/calMonthRail/calMonthCell/calAgenda + seg/nav 按钮;calendar 路由)
- VibeHub: record_decision「Calendar 模块端口(周⇄月+议程)」→ 30dd9072-b00b-4581-a07c-df3070c56dfe (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,32 测 0 失败(+3 日历 nav/toggle/默认)。逐项对照 HTML CSS:calhd2 cseg 25×22 accent、mgrid 30+7 列、mcell 今天白圆 26、mrail 缩写+月号+点、议程 evtime 44 mono+evdot。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: per-day 事件数据源待接(TODO)

## 2026-07-01 00:05 · swift-align-04-dev-rail-subpages
- 设计源: helm-notch-pro.html(V.dev / devrail / V.ports / V.prs / V.stats / PORTS / PRS / HEAT / SPARK)
- 界面: Dev 模块(devModule 取代复用单 agentCell);竖向 rail 分页四子页
- 做了: devModule = devStage(左,fill)+ devRail(右 width20:4 分页点,选中 5×18 accent 圆角条/其余 5×5 点,点击切 devSection)。四子页:agents 复用 agentCell;ports 端口 V.ports(PORTS 种子,状态点+:端口 mono+名+↗打开+发丝线);reviews 端口 V.prs(PRS 种子,单色缩写头像圆+标题截断+repo#num+GH/GL 单色徽标+accent↗);stats 端口 V.stats(热力图 19×7+token 2.4M+spark 7 条+commits/PR 两 mini tile,GeometryReader 1.45:1)。
- 取舍: ports/reviews/stats 全 HTML 静态种子(真实需 lsof/GitHub API/token 追踪,各 TODO)。热力图等级 HTML 用 Math.random → Swift 确定性 hash(sin*43758 取小数)保证可复现、分布近似。switchDev 逻辑 block1 已测;本块纯 App UI。
- 改动: HelmNotchApp/NotchView.swift(devModule/devStage/devRail/devPorts/devReviews/devStats/heatmap/statMini + portSeed/prSeed/sparkSeed + heatLevel/heatOpacity/heatHash;dev 路由)
- VibeHub: record_decision「Dev 模块端口(rail 四子页)」→ 50189722-bf3d-4b03-8984-9a4a017fd351 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,29 测 0 失败(无新 Core)。逐项对照 HTML CSS:devrail dri 5/18 accent、ports pp2 56 mono、prs pav26/psrc 徽标、hmap 19×7 gap3 + l0-l4 opacity、spark/tile r12。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: ports/reviews/stats 真实数据源待接(均 TODO)

## 2026-07-01 00:02 · swift-align-03-media-fullscreen
- 设计源: helm-notch-pro.html(V.media / .mfull / .bgcov / .lyrics / .mwave / SOURCES / srccycle)
- 界面: Media 模块全屏(mediaModule 取代复用小 cell);Core 加播放源状态
- 做了: Core MediaSource 枚举(system/appleMusic/spotify/browser 纯文本名)+ NotchModel.mediaSource/cycleMediaSource(环绕,+1 测)。App mediaModule:模糊封面背景(blur34/scale1.3/opacity.6+黑 scrim.45)+ mtop(‹返回→dash · 源 chip ●Source⌄→cycle)+ mrow(左190:bigcov84 r14 阴影/标题/艺人/进度条+圆 knob/控制 ◀◀❚❚21▶▶;右 lyrics 静态 demo 当前句高亮+上下渐隐 mask,2.6s 推进)+ Waveform 44 条(sine 基高、错位 delay 动画、暂停冻结、两端 mask)。
- 取舍: 歌词 = HTML 静态 demo(真同步歌词需 provider,TODO);per-view 自适应高度 VH.media=330 未端口(TODO,暂用可调面板高度);封面/进度/控制接真实 nowPlaying,无时长时进度回退 HTML 静态 42%/0:42·1:31。
- 改动: HelmNotchCore/Media.swift(+MediaSource)、NotchModel.swift(+mediaSource/cycle)、Tests(+1)、HelmNotchApp/NotchView.swift(mediaModule/mediaBgCover/coverArt/mediaProgress/lyricsColumn + Waveform struct;media 路由)
- VibeHub: record_decision「全屏 Media 模块端口」→ 34586cc4-99a6-4c9e-91aa-93a2ea826916 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,29 测 0 失败(+1 mediaSource 循环 wrap)。逐项对照 HTML CSS:bgcov blur/scale/scrim、bigcov 84/r14、mbar2 白条+10 圆 knob、mctrl2 21pp、lyrics .38/.22-.78 mask、mwave 44/sine/两端 mask。视觉实机待用户目视。
- 状态: ✅ 待 review  |  ❓需确认: per-view 自适应高度待后续块;歌词真源待定(均 TODO)

## 2026-06-30 23:58 · swift-align-02-dock-toolbar-router-dashboard
- 设计源: helm-notch-pro.html(#panel / .ntop / .dock / renderDock / V.dash / V.clip)
- 界面: 展开面板重构为「顶栏 + 单模块视图 + dock」;Dashboard 与 Clipboard 模块端口
- 做了: expandedPanel 替换 2×2 grid;topBar(Helm logo accent 圆角方+深色 H 字形、齿轮、锁定态 X)、dockBar(5×34圆按钮 单色字形 ⊞✎◫⌘⧉,选中 accent 环、Dev 橙 badge);moduleBody 路由:dashboard 端口 V.dash 三栏(NOW PLAYING/TODAY 甜甜圈+任务/本机 CLAUDE CODE,GeometryReader 精确 1.6:1:1 + 发丝竖线,卡片点击进 media/dev),clipboard 端口 CLIP 列表;capture/calendar/dev/media 暂复用 cell body。
- 取舍: 设计稿 dock 模型取代 2×2(grid/cell/vline/hline/topControls 暂留可回退,标 TODO 引用 question 3edd9817)。TODAY 甜甜圈 3/11 与 CLIP 为 HTML 静态种子(无后端任务计数/剪贴板源)→ 照搬并标 TODO。dev 子页 rail、全屏 media 歌词+波形留后续块。视觉门:NSPanel 刘海窗无头不可靠截图 → 改「对照 HTML CSS 逐值还原」+ build/test 硬门,实机目视留用户早上。
- 改动: notch/Sources/HelmNotchApp/NotchView.swift(expandedPanel/topBar/logoMark/dockBar/dockButton/moduleBody/dashboard 三 widget/clipboardBody;shell 用 expandedPanel)
- VibeHub: record_decision「dock+顶栏+模块路由;Dashboard/Clipboard 端口」→ fde8fdde-5a13-4fee-8e42-cdd14d165238 (ai_proposed);add_question 无(架构切换沿用已开 3edd9817);add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,28 测 0 失败(无新 Core 逻辑,纯 App UI)。逐项对照 HTML CSS:dock 34/圆/accent 环、logo 16+H、dashrow 1.6:1:1+发丝线、封面 64/r12、甜甜圈 54、clip 行 26 ic。视觉实机目视待用户。
- 状态: ✅ 待 review  |  ❓需确认: 沿用 2×2→dock 架构 question(3edd9817);视觉实机待早上目视

## 2026-06-30 23:51 · swift-align-01-module-dock-statemachine
- 设计源: helm-notch-pro.html(MODULES / S.view / switchModule / DEVSECS / switchDev)
- 界面: Core 状态机(NotchModule / DevSection / NotchModel module 切换)——本块无 UI delta
- 做了: 把设计稿「dock + 单模块视图切换」架构的状态机落进 Core:新增 NotchModule 枚举(dock 顺序 dash/cap/cal/dev/clip + 单色字形 ⊞✎◫⌘⧉ + title;media 为 zoom 目标不进 dock)、DevSection 枚举(agents/ports/reviews/stats + ◉⇄⎇▤);NotchModel +module/devSection +selectModule/switchModule(环绕)/switchDev(夹紧)。
- 取舍: 设计稿已从 2×2 演进为 dock+模块,与已拍板 decision 09eb9245「2×2 不变形」冲突 → 按 loop 指令忠实实现 HTML,开 [needs-human] question 等用户早上拍板;2×2 cell 代码暂不删,可回退。先落纯 Core(可测、零 UI 破坏)再后续接 UI。字形全单色 Unicode,守禁 emoji 规则。
- 改动: notch/Sources/HelmNotchCore/NotchModule.swift(新)、NotchModel.swift(+module/devSection 状态与切换)、Tests/HelmNotchCoreTests/NotchModelTests.swift(+NotchModuleTests 8 测)
- VibeHub: record_decision「原生 Swift App 改为 dock+单模块视图切换架构」→ 37497171-98e2-4536-a828-c63a1cc53d01 (ai_proposed);add_question「[needs-human] 是否正式从 2×2 切到 dock+模块」→ 3edd9817-c20c-44cd-b3e3-c38d8dcaa168 (ai_proposed);add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,28 测 0 失败(+8 新:dock 排除 media/前后向环绕/media 回退 dock 起点/进 dev 重置子页/switchDev 两端夹紧/逐页前进)。Core-only 块,无 browse 视觉靶图可比(dock UI 下一块再截图比对)。
- 状态: ✅ 待 review  |  ❓需确认: 2×2 → dock 架构切换(已开 question)

## 2026-06-30 14:26 · media-source
- 参考: refs/done/2026-06-30-media-source.png
- 界面: Media 放大态顶栏(`V.media` 的 `.mtop`)
- 做了: 「‹ 返回」同排右侧加一个播放源切换 chip(`● <源> ⌄`),点击循环 System/Apple Music/Spotify/Browser 并 flash。
- 取舍: 只取「切换播放器/源」这个价值;砍掉参考的「Pick an app」桌面空状态 + 彩色品牌 logo(Apple Music/Spotify/YouTube)→ 单色 chip + accent 圆点 + 文本源名。
- 改动: helm-notch-pro.html(`S.mediaSrc`、`SOURCES`、`.mtop/.msrc` CSS、`srccycle` handler)
- 自检: 一次过;查了 遮挡·溢出·居中·比例·feature·无回归(波形/歌词/控制完好)
- 状态: ✅ 待 review

## 2026-06-30 14:26 · dev-reviews
- 参考: refs/done/2026-06-30-dev-reviews.png
- 界面: Dev 新增第 4 个子页「Reviews」(`V.prs`,DEVSECS 插在 Ports 与 Stats 之间)
- 做了: PRs/MRs 待评审列表:单色头像(缩写)+ 标题(截断)+ repo#num + 源徽标 + accent 打开箭头;右轨多一项 Reviews。
- 取舍: 进现有 Dev 模块/右轨/纵向分页体系(不加外来 chrome);GitLab 彩标 → 单色 `GH/GL` 徽标;彩色头像 → 单色缩写圆。h 先 226 自检发现末行被 dock 裁切 → 提到 252,二轮通过。
- 改动: helm-notch-pro.html(`PRS`、`V.prs`、`devPage` 数组、`DEVSECS` 加项、`.prs/.pav/...` CSS)
- 自检: 修 1 轮(高度);查了 遮挡·溢出·居中·比例·feature·无回归
- 状态: ✅ 待 review

## 2026-06-30 14:12 · media-waveform
- 参考: refs/done/2026-06-30-media-waveform.png
- 界面: Media 放大态(`V.media`)
- 做了: 在歌词/控制下方加一条满宽单色波形可视化(44 根条、正弦基高 + 错位动画、两端 mask 渐隐)。
- 取舍: 只取「波形可视化」这个价值;砍掉参考里那排桌面级 chrome(Browser 按钮、刷新/下载/info/eye/visualizer 图标)。颜色走每日 `--accent` 而非彩色;暂停时 `animation-play-state:paused` 冻结。VH.media 300→330 容纳。
- 改动: helm-notch-pro.html(`V.media` 末尾加 `.mwave`、`.mwave` CSS、VH.media)
- 自检: 一次过;查了 遮挡·溢出·居中·比例·feature·无回归(歌词/控制/dock 完好)
- 状态: ✅ 待 review

## 2026-06-30 14:12 · module-rail(❓需确认,未改代码)
- 参考: refs/done/2026-06-30-module-rail-needsconfirm.png
- 界面: —(右侧竖排模块图标条的局部裁切)
- 做了: 暂不改代码。
- 取舍: 这张只是 MacNotch 右侧「竖排模块 dock」的放大裁切,意图不明确。我们现有体系是**底部 dock + 左右滑切模块**;改成右侧竖排 rail 会和既有手势模型冲突,属结构性大改,不宜瞎猜。
- 改动: 无
- 自检: —
- 状态: ❓需确认: 你是想要「右侧竖排模块 rail」替换/补充现在的底部 dock 吗?还是只是图标风格参考?给方向我下一轮做。

## 2026-06-30 14:12 · event-reminder
- 参考: refs/done/2026-06-30-event-reminder.png
- 界面: 新增「日程提醒 banner」(`remindHTML()`,与权限 banner 并列)
- 做了: 临近日程到点时弹一条 wide-short banner:单色日历字形 + 标题 + 时间/时长 + 地点(PIN)+ 加入/稍后/忽略。模拟开关在 controls「日程提醒」。
- 取舍: 复用既有 banner 机制(不加外来 chrome);"Join Microsoft Teams" 品牌按钮 → 单色 `--accent`「加入」;Teams/Zoom 彩色 emoji → 单色字形;"Focus/Started 1s ago" → 「现在开始」。独立 `.notch.remind` 尺寸(更矮 152px)。
- 改动: helm-notch-pro.html(`S.remind`、`REMINDER`/`CALSVG`、`remindHTML()`、render banner 分支、`.notch.remind`/`.rmd*` CSS、ctl-remind 控件+接线)
- 自检: 一次过;查了 遮挡·溢出·居中·比例·feature·无回归
- 状态: ✅ 待 review
