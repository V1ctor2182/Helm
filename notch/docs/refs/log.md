# Notch 优化 Loop · 处理流水

> 每把 `helm-notch-pro.html` 设计的一块对齐进 Swift App,loop 在这里追加一条。格式见 `notch-loop-procedure.md` 附录 C。
> (下面 2026-06-30 那批是早期"改 HTML"阶段的历史记录,现 loop 已改为「HTML 只读、改 Swift」。)
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

## 2026-07-01 06:56 · swift-fix-anim-durations(实机反馈)
- 对齐: 滑动 + hover 展开收起动画稍慢一点
- 做了: 滑动(module/dev transition + scroll withAnimation)0.3→0.36;hover 展开收起(value:expanded)0.46→0.54。dock .12 保持快切;模块切换高度 reflow 保持 0.46(HTML)。
- Swift 改动: NotchView.swift(expanded 0.54、module/devSection 0.36)、NotchController.swift(animatedSwitch 0.36)
- 验证: swift build ✓ / swift test 61 通过;手感待实机
- 状态: ✅ 待实机复验

## 2026-07-01 06:44 · swift-fix-scroll-hover-feel(实机反馈)
- 对齐: 滑动偶发闪跳 + hover 收起慢
- 做了: ① hover 收起延迟 220ms→80ms(HTML 是立即,留少量防抖)。② scroll 切换加 0.30s 冷却(防新滑动打断在飞的过渡→snap)+ 包 withAnimation(NSEvent 回调有时不触发隐式 .animation → 偶发瞬跳,显式动画兜底)。
- Swift 改动: NotchModel.swift(hover 延迟 80)、NotchController.swift(冷却+animatedSwitch withAnimation)
- VibeHub: record_decision → (见下)
- 验证: swift build ✓ / swift test 61 通过;手感待实机
- 状态: ✅ 待实机复验

## 2026-07-01 06:30 · swift-fix-jank(实机反馈)
- 对齐: 打字/hover/滑动卡顿 + 剪贴板底部被 dock 遮挡(Image #8)
- 根因(卡): shell 里 collapsedBar 与 expandedPanel 一直在树里(opacity 切),collapsedBar 的 EqualizerBars 等 repeatForever 即使不可见也常跑 → 常驻重渲染 → 卡。
- 做了: ① shell 改条件渲染(expanded→只 expandedPanel、else→只 collapsedBar),.transition(.opacity) 由外层单一 .46s grow 动画统一驱动;② moduleBody 去 .clipped()(外层 NotchShape 裁剪够);③ clipboardBody 加 ScrollView(HTML .clip overflow-y:auto)修遮挡。
- Swift 改动: NotchView.swift(shell 条件渲染、moduleBody 去 clipped、clipboardBody 滚动)
- VibeHub: record_decision「治卡+剪贴板滚动」→ 3c610bdb-f63f-4ebf-8f39-a486a183fdad (ai_proposed)
- 验证: swift build ✓ / swift test 61 通过;卡顿改善待实机;若切模块仍卡→查 .id 重建 heatmap/GeometryReader 成本
- 状态: ✅ 待实机复验

## 2026-07-01 06:14 · swift-fix-scroll-while-typing(实机反馈)
- 对齐: 速记打字时切不走(上轮 !locked 拦截引入的回归)
- 根因: 上轮给 handleScroll 加了 !model.locked guard,打字时 locked=true → scroll 全被挡。
- 做了: 去掉 handleScroll 的 !locked guard。打字时也能滑切模块;setModule 清锁(上轮)让切走后能收起。TAB 走独立 keyMonitor 不受影响。
- Swift 改动: NotchController.swift(handleScroll guard 去 !locked)
- 验证: swift build ✓ / swift test 61 通过
- 状态: ✅ 待实机复验

## 2026-07-01 06:05 · swift-fix-panel-hpadding(实机反馈)
- 对齐: 展开面板左右内容离边太近 → 加 padding
- 做了: expandedPanel 加 .padding(.horizontal, 8),topBar/模块/dock 统一往里收,不动内部间距。真机渲染 dash 确认 logo/列有更多留白。
- Swift 改动: NotchView.swift(expandedPanel horizontal padding)
- VibeHub: record_decision → (见下)
- 验证: swift build ✓ / swift test 61 通过;真机 dash 留白改善
- 状态: ✅ 待实机复验

## 2026-07-01 05:56 · swift-fix-device-batch3(实机 debug)
- 对齐: 速记切走后不收起 + 折叠条去 demo
- A(不收起): 根因 hover 收起条件 !locked && captureText.isEmpty,切走后 text 非空一直挡;切走 locked 未清。修:setModule 离 capture 清 locked;hover 条件改「!locked && !(module==.capture && text 非空)」。
- C(输入时滑还能切): handleScroll 已 guard !locked,配合 A 清锁,流程正常。
- B(折叠还显 demo): collapsedLeft 用真实 model.nowPlaying(nil→Helm 点)、collapsedRight 用真实 localSessions;demo 只留展开面板。
- Swift 改动: NotchModel.swift(setModule 清锁/hover 条件)、NotchView.swift(collapsedLeft/Right 真实数据)、Tests(+1)
- VibeHub: record_decision「切走收起+折叠去 demo」→ 1f214758-0b2e-40ed-bd74-23f98e5c439a (ai_proposed)
- 验证: swift build ✓ / swift test 61 通过;待实机复验
- 状态: ✅ 待实机复验

## 2026-07-01 05:42 · swift-fix-dock-icon-anim(实机反馈)
- 对齐: dock 图标切换动画(用户:切模块时 dock 图标不该有这种变化,参考 HTML)
- 根因: 切模块时 module 与 autoExpandedHeight 同变,shell .animation(value:autoExpandedHeight)(.46s)把 dock 激活态(accent 色/背景圆/1.5 环)卷进慢曲线 → dock 图标 0.46s 缓慢 morph;HTML .dk 只 .12s 快切。
- 做了: dockBar 加 .animation(.easeOut(0.12), value: model.module),激活态用独立 .12s(=HTML .dk),与高度/滑动慢动画解耦。dock 随高度纵移保留(HTML 同)。
- Swift 改动: NotchView.swift(dockBar 动画)
- VibeHub: record_decision「dock 图标快切」→ 5e090543-93db-463a-b3f6-fd22dc459363 (ai_proposed)
- 验证: swift build ✓ / swift test 60 通过;待用户实机复验
- 状态: ✅ 待用户实机复验

## 2026-07-01 05:30 · swift-fix-device-batch2(实机反馈三修)
- 对齐: 折叠曲名截断 / 速记 TAB 循环 / cap 留白
- 做了: ① 折叠曲名去 maxWidth:90 → lineLimit+tail 用满侧槽。② Core cycleCaptureKind(环绕)+ NotchController keyMonitor(Tab keyCode48,expanded+capture+locked+!focusOn 循环 note→journal→task→focus→ask,Shift 反向,consume;返 Bool 避 NSEvent Sendable)。③ cap 高度调低:note 256→214/task 300→258/focus idle 268→240/showRecent +64(min320),测同步。
- Swift 改动: NotchView.swift(折叠曲名)、NotchModel.swift(cycleCaptureKind+cap 高度)、NotchController.swift(keyMonitor)、Tests(+1,高度值更新)
- VibeHub: record_decision「实机三修」→ b3a91778-a15f-415b-b4dc-8445705c4cea (ai_proposed)
- 验证: swift build ✓ / swift test 60 通过;待用户实机复验
- 状态: ✅ 待用户实机复验

## 2026-07-01 05:12 · swift-fix-agent-row-overflow(实机反馈)
- 对齐: agent 行长文本溢出裁切(用户实机 hook 真实 session)
- 根因: 真实 folder/长 bash·git activity 溢出面板右边被裁,非省略号。dashAgentWidget 缺尾 Spacer;agentCell activity 未强制尾截断。
- 做了: 两处 agent 行——folder layoutPriority(1)、activity lineLimit(1).truncationMode(.tail)、dashAgentWidget 补 Spacer(minLength:0)、agentCell phaseShort fixedSize。demo(短 activity)重渲染无回归。
- Swift 改动: NotchView.swift(dashAgentWidget/agentCell 行截断)
- VibeHub: record_decision「agent 行溢出截断」→ 8efdae8b-f759-45a6-ae55-1f2fdb5fd61e (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过;demo 无回归;真实长文本待实机复验
- 状态: ✅ 待用户实机复验

## 2026-07-01 05:00 · swift-fix-scroll-gesture-onestep(实机反馈)
- 对齐: scroll 手感(用户实机反馈:一下子切过去 + 缺渐变)
- HTML 基线: notch wheel handler + switchModule 的 animating 锁
- 根因: 触控板一次 swipe 产生一串 wheel 事件(+momentum 惯性尾),0.35s 冷却挡不住 → 一次划切 2-3 个;多切又盖掉单次淡入淡出。
- 做了: handleScroll 用 NSEvent.phase/momentumPhase——惯性事件全忽略;.began 重置累积器;累积 delta 过 22px 阈值切一次,gestureSwitched 忽略本手势剩余;.ended 复位。鼠标滚轮仍走 0.35s 冷却。→「一次物理滑动=切一个」。渐变:notchSlide 本有 offset+opacity,一次一切后应显现。
- Swift 改动: NotchController.swift(handleScroll 重写 + gestureAccum/Switched 状态)
- VibeHub: record_decision「scroll 一次一切」→ 0011a585-c7b7-41b1-abf6-01835c6bdedd (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;手感待用户实机复验
- 状态: ✅ 待用户实机复验(切换是否一次一个 + 渐变是否显现)

## 2026-07-01 04:42 · swift-align-41-transition-timings
- 对齐: 展开/折叠过渡时长到 HTML 确切值(用户 #1)
- HTML 基线: #bar opacity .14s / #panel open opacity .34s ease .12s、close .3s
- HTML↔实际对比: 我 collapsedBar .12/.22、expandedPanel .3 delay .12 —— 和 HTML 确切值有微差。
- 做了: collapsedBar 动画统一 .14s;expandedPanel 展开 .34s(收起 .3s)delay .12。折叠↔展开淡入淡出时长对齐 HTML。
- 取舍: reminder banner 无法快照(snapshot 无 runloop 跑不了 async 事件注入);其 UI 与已验证的 permission banner 同构,信其正确。
- Swift 改动: NotchView.swift(shell collapsedBar/expandedPanel 动画时长)
- VibeHub: record_decision「过渡时长对齐」→ 37c8ce19-66f3-403e-b5e2-c8e817985a60 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;时长参数逐值对齐 HTML(手感需实机)
- 状态: ✅ 待 review

## 2026-07-01 04:34 · swift-align-40-snapshot-settings
- 对齐: 设置 modal 真机核对(靶图 /tmp/notchshots/swift-settings.png)
- HTML 基线: settingsHTML
- HTML↔实际对比(真机渲染): 初次全黑——ImageRenderer 不渲染 ScrollView 内容。重构 SettingsView 抽出 content(去 ScrollView 正文),snapshot 渲 .content。重渲染成功,与 HTML 对齐:标题+版本/外观(材质 4chip+主题色 10dot+配色模式+随机一套+每天随机)/HELM 后端(连接+完整设置)/本机(hook)/媒体(播放源)。
- 差异: ① HTML 自定义 modal 有 ✕,我原生窗用标题栏关闭钮。② 每天随机 toggle 在 ImageRenderer 渲成 🚫(Toggle 无头限制,非真 bug)。
- Swift 改动: SettingsView.swift(抽 content)、NotchSnapshot.swift(渲 .content)
- VibeHub: record_decision「设置可快照+对齐」→ 4de767de-85c4-483b-8200-7ece5a77201e (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机设置 modal 对齐 HTML
- 状态: ✅ 待 review  |  harness caveat 汇总:TextField/Material/Toggle/独立 ScrollView 无头渲不出

## 2026-07-01 04:24 · swift-align-39-snapshot-materials
- 对齐: Snapshot 扩玻璃材质 + 验证对比 accent(靶图 /tmp/notchshots/swift-mat-lightglass.png)
- HTML 基线: MATS / randomTheme 对比逻辑
- 发现(真机渲染): ① ImageRenderer 无头渲不出 SwiftUI Material(lightglass 成实心黄绿非真模糊,无窗口合成)→ 玻璃观感必须实机验。② 对比 accent 生效——lightglass 上 accent 调暗成深 teal 可读(donut/进度/dock 环)。③ 张力:白玻璃白正文字浅壁纸下对比不足(HTML 同问题)。
- 做了: NotchSnapshot 加 mat-darkglass/lightglass/vibrant 三档;不改 materialBackground(实机才准)。开 [needs-human] question。
- Swift 改动: HelmNotchApp/NotchSnapshot.swift(3 材质条目)
- VibeHub: record_decision「玻璃 harness+对比 accent 生效」→ fdf88d05-5e55-441e-b177-e0212aafc184;add_question「[needs-human] 白玻璃白字对比」→ bae51057-87b7-... (均 ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:玻璃需实机(harness 渲不出 Material)
- 状态: ✅ 待 review  |  ⚠️ 玻璃观感待实机;❓白玻璃白字对比待拍板

## 2026-07-01 04:16 · swift-align-38-snapshot-permission-banner
- 对齐: Snapshot harness 扩到等权限 banner + 真机核对(靶图 /tmp/notchshots/swift-banner-permission.png)
- HTML 基线: bannerHTML(等权限横幅)
- 做了: NotchSnapshot 加 banner-permission(applyHook 注入 PermissionRequest);frame 按 banner 尺寸(560×152 / 620×208)。真机渲染对比 HTML:●Permission Request·notch 橙 + ⌘Y/⌘N + ⚠︎Edit + 路径 + Deny 白/Allow accent——结构配色布局都对。
- HTML↔实际对比: 唯一差=中间 HTML 是代码 diff(ctx/del/add),我显目标路径——hook 只传 tool/detail 无 diff(已知 TODO,不虚构)。
- Swift 改动: HelmNotchApp/NotchSnapshot.swift(banner 条目+banner 尺寸)
- VibeHub: record_decision「harness 扩 banner」→ da6565ad-9db3-47b9-9989-b3dcb6661de8 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机 banner 结构对齐 HTML
- 状态: ✅ 待 review  |  reminder banner 需事件注入(异步),下块补

## 2026-07-01 04:08 · swift-align-37-snapshot-agent-rows
- 对齐: 真机快照 · agent 行 shimmer/stag(靶图 /tmp/notchshots/swift-dev-agents.png)
- HTML 基线: V.agents srow(.think/.shine/.stag)
- HTML↔实际对比(真机渲染): ① 我给所有 running 行加 ✻+shine,HTML 只「思考中」行(notch)有,具体活动(app Bash)显纯灰。② HTML stag「运行中 ›」我缺「›」。
- 做了: agentCell + dashAgentWidget running 行——activity 非空且≠「正在思考…」显纯灰文本,否则 ✻+shimmer;phaseShort running/waiting 加「›」。重渲染 notch=✻思考、app=灰 Bash、都「运行中 ›」。
- Swift 改动: NotchView.swift(phaseShort、agentCell/dashAgentWidget running 行)
- VibeHub: record_decision「agent 行 shimmer/stag」→ e3fdb05d-4125-48fe-83f9-bf806eabd920 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机重渲染与 HTML dev-agents 一致
- 状态: ✅ 待 review

## 2026-07-01 04:00 · swift-align-36-agenda-scroll
- 对齐: 议程垂直滚动(修上块周视图溢出遗留)
- HTML 基线: V.cal .agenda overflow-y:auto
- HTML↔实际对比: 周视图 240 高议程 4 项裁末项;HTML agenda 内滚。
- 做了: calAgenda 事件列表外包 ScrollView(.vertical,隐指示器),固定高度内滚动而非裁切;月视图事件多时同样可滚。
- Swift 改动: NotchView.swift(calAgenda ScrollView)
- VibeHub: record_decision「议程滚动」→ e19686be-e972-4c11-8115-80df85c5aede (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败
- 状态: ✅ 待 review

## 2026-07-01 03:52 · swift-align-35-snapshot-calweek-daynum
- 对齐: 真机快照 · 周条日号换行(靶图 /tmp/notchshots/swift-cal-week.png)
- HTML 基线: V.cal wstrip .wnum
- HTML↔实际对比(真机渲染): 周条两位日号(30)在窄列换行成「3」「0」两行。
- 做了: calWeekStrip wnum Text 加 .lineLimit(1).fixedSize() 防换行 + verbatim 防千分位。重渲染「29 30 1 2 3 4 5」一行,今天/事件点对齐 HTML。
- 取舍: 遗留小项——周视图(240 高)议程 4 项溢出裁末项(HTML agenda scroll),下块可加滚动。
- Swift 改动: NotchView.swift(calWeekStrip wnum)
- VibeHub: record_decision「周条日号换行」→ 4dcdedcc-5899-4995-81a1-faf7b078a1aa (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机重渲染周条一行
- 状态: ✅ 待 review

## 2026-07-01 03:44 · swift-align-34-snapshot-stats-pr-tile
- 对齐: 真机快照 · Stats PR tile 混排(靶图 /tmp/notchshots/swift-dev-stats.png)
- HTML 基线: V.stats .sv2 / small
- HTML↔实际对比(真机渲染): PULL REQUESTS 截成「3 ope...」——我 statMini 全 18pt「3 open · 12」放不下;HTML 大数字+small(11)单位词能塞下。
- 做了: statMini→statTile(@ViewBuilder 富文本);PR tile Text 拼接(3/·12 用 18heavy、open/merged 用 11+t2)+minimumScaleFactor;commits 37 也走 statTile。重渲染显「3 open · 12…」结构对。
- Swift 改动: NotchView.swift(statTile、commits/PR tile 富文本)
- VibeHub: record_decision「Stats PR tile 混排」→ 76851cdc-6f51-445d-8e78-761932a5f7d1 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机重渲染 PR tile 数字大词小
- 状态: ✅ 待 review  |  已核 dev-ports/clip/dev-stats 真机对齐 HTML

## 2026-07-01 03:34 · swift-align-33-snapshot-collapsed-width
- 对齐: 真机快照 · 折叠条侧槽宽度(靶图 /tmp/notchshots/swift-collapsed.png)
- HTML 基线: #bar grid 1fr/auto(160)/1fr
- HTML↔实际对比(真机渲染): 曲名截成「C…」——侧槽太窄。HTML 每侧 (360-160)/2=100px,我 collapsedWidth=notchWidth+150 每侧仅 75px,减 art+eq 后文字空间太少。
- 做了: collapsedWidth 改 notchWidth+200(每侧~100px 对齐 HTML);NotchController activeSize 折叠宽同改。重渲染曲名显「Countin…」(符合 HTML 截断)。
- Swift 改动: NotchView.swift(collapsedWidth)、NotchController.swift(activeSize 折叠宽)
- VibeHub: record_decision「折叠条加宽」→ b1a209a5-9138-470a-96b4-356dad1199a1 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机重渲染确认曲名不再截成单字
- 状态: ✅ 待 review

## 2026-07-01 03:26 · swift-align-32-snapshot-diff-number-grouping
- 对齐: 真机快照对比 → 修数字千分位 bug(靶图 vs /tmp/notchshots/swift-cal-month.png)
- HTML 基线: V.cal 年份 / V.ports 端口
- HTML↔实际对比(真机渲染): ① cap 输入框 ImageRenderer 渲成黄条+🚫 = TextField 无头限制(非真 bug,harness caveat)。② cal-month 年份显示「2,026」——SwiftUI Text("\(Int)") 加千分位分组;端口同理会「:3,000」。
- 做了: 年份 + 端口改 Text(verbatim: String(...))/Text(verbatim: ":\(port)") 绕本地化。重渲染确认「2026」「:3000」正确。cal-month 修后与 HTML 基本像素吻合。
- Swift 改动: NotchView.swift(calendarModule/calWeekStrip 年份、devPorts 端口 verbatim)
- VibeHub: record_decision「数字千分位 bug」→ 194c22d5-6259-4cb6-b398-1ef164c26aa7 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机 cal-month 重渲染确认年份对
- 状态: ✅ 待 review  |  harness caveat:TextField 无头渲染是黄条(非真 bug)

## 2026-07-01 03:16 · swift-align-31-snapshot-harness
- 对齐: 无头 Snapshot harness(首次真机对比 Swift vs HTML)+ 波形条形状
- HTML 基线: 全 view / .mwave
- 做了: HelmNotchApp 加 --snapshot <dir>(NotchSnapshot.render 用 ImageRenderer scale2 把 10 个 view 渲成 PNG,exit);无需 GUI/权限。实测 10 张全成功。首次真机 Swift 渲染对比 HTML 靶图:dash/media 高度吻合(布局/字号/间距/dock/波形/歌词/进度全对)。
- HTML↔实际对比(靠真机渲染): 发现波形条我用 Capsule(全圆像圆点),HTML .mwave i border-radius:2px 细条 → 改 RoundedRectangle(cornerRadius:2)。
- Swift 改动: HelmNotchApp/NotchSnapshot.swift(新)、HelmNotchApp.swift(--snapshot 分支)、NotchView.swift(Waveform Capsule→RoundedRect2)
- VibeHub: record_decision「Snapshot harness + 波形条」→ 132944eb-b8a2-4c47-85c0-f81a31d002ad (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:真机渲染 /tmp/notchshots/*.png,dash/media 对比 HTML 吻合
- 状态: ✅ 待 review  |  基础设施:后续每轮可 swift-* vs html-* 像素对比

## 2026-07-01 03:08 · swift-align-30-visualdiff-media-demo
- 对齐: 视觉 diff · 媒体 demo 回退(折叠左/dash widget/折叠右计数)
- HTML 基线: renderBar 左媒体 / V.dash NOW PLAYING / renderBar 右 ✻N
- HTML↔实际对比: HTML 处处显 demo 歌「Counting My Blessings」,我用真实 nowPlaying(nil)→折叠左「Helm 点」/dash「未在播放」。
- 做了: shownNowPlaying(真实 else HTML demo 歌 42/91)+ mediaFraction(真实 livePosition/demo 静态);collapsedLeft 去 Helm 点统一 shownNowPlaying;dashMediaWidget 去「未在播放」;dashMiniBar 用 mediaFraction;collapsedRight 计数改 displaySessions(默认 ✻2)。mediaModule 已有 demo 文案。
- 取舍: ⚠️ 折叠条常驻,现无真实数据永久显 demo 歌+✻2(和 HTML 一样但真机常态一直 demo),已 flag 用户可否决;真实数据一来即顶替。
- Swift 改动: NotchView.swift(shownNowPlaying/mediaFraction、collapsedLeft/Right、dashMediaWidget/dashMiniBar)
- VibeHub: record_decision「媒体 demo 回退」→ 04d00064-5009-44f6-aaaa-9bf5933b60e4 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:折叠+dash 媒体已和 HTML 一致
- 状态: ✅ 待 review  |  ⚠️ 折叠条永久 demo(待用户定是否接受)

## 2026-07-01 03:00 · swift-align-29-visualdiff-agents-demo
- 对齐: 视觉 diff · 本机 agent demo 回退(靶图 /tmp/html-dev-agents.png、dev-stats.png)
- HTML 基线: V.agents / dash agr(demo notch/app/helm)
- HTML↔实际对比: HTML 显 demo 三条 agent,我用真实 localSessions(无 hook 空)→「无 agent/未装 hook」。stats 页(heatmap/token/tiles)已基本一致。
- 做了: displaySessions(真实非空用真实,否则回退 HTML demo:notch running「正在思考…」/app running「Bash: swift build」/helm ended);agentCell + dashAgentWidget 改用之,活跃数从 displaySessions 算,去掉空态文案。
- 取舍: 无 hook 默认显 demo(一模一样),真实 session 顶替;等权限 banner 仍只由真实 localSessions 触发(demo 无 waiting)。PR tile「12 merged」小差留后修。
- Swift 改动: NotchView.swift(displaySessions、agentCell、dashAgentWidget)
- VibeHub: record_decision「agent demo 回退」→ 37269084-b1fd-481a-9be5-660ed296ba2a (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:HTML 靶图对比,dev agents/dash 已对齐
- 状态: ✅ 待 review

## 2026-07-01 02:52 · swift-align-28-visualdiff-calendar-mock
- 对齐: 视觉 diff · 日历 mock 事件 + 议程布局(靶图 /tmp/html-cal-month.png)
- HTML 基线: EVENTS / CAL_ITEMS / CAL_EVDAYS / .evr(evtime/evbody/evdot)
- HTML↔实际对比: 我议程用 model.events(后端空)→ 空态,HTML 显 4 demo 事件;月/周格无事件点(HTML 有橙点)。
- 做了: calMockItems 复刻 EVENTS/CAL_ITEMS(今天 4 项+邻近几天 demo,(_td±n)%28+1)、calEventDays 复刻 CAL_EVDAYS;calAgenda 完整行布局(evtime start 大 accent+end 小灰 / title+location PIN mappin / 每事件独立色点);月格+周条加事件点(accent 4px)。
- 取舍: 议程/点用 mock(HTML 一模一样优先);折叠条下个日程/提醒仍用 model.events(小不一致,可后续统一)。
- Swift 改动: NotchView.swift(CalMockItem/calMockItems/calEventDays/calAgenda 重写、calMonthCell+calWeekStrip 事件点)
- VibeHub: record_decision「日历 mock 事件+议程布局」→ d81c4dff-667e-4423-8e61-9ac1ddf47db0 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:HTML 靶图对比,议程+事件点已对齐
- 状态: ✅ 待 review

## 2026-07-01 02:44 · swift-align-27-visualdiff-capture-layout
- 对齐: 视觉 diff · 速记模块布局(靶图 /tmp/html-cap.png)
- HTML 基线: V.cap(.vh / .capin / .caprow / .sendb)
- HTML↔实际对比: ① 头部 HTML「速记→Helm」+「TAB 切换模式」,我是「✎ 速记」+「●输入中」。② 输入框 HTML 全宽独立行、发送钮在下面 caprow(和时间/地点同排右对齐),我把 send 塞进 textfield HStack。③ 发送钮 HTML ✈+文字(发送/派发/问/发送并归档),我是 arrow.up.circle 图标。
- 做了: 头部按 kind 显「速记/专注→Helm」+TAB 提示;输入框全宽独立(font14/r12);新 caprow(note/task 显 attachmentRow、其余 hint,右 sendButton);sendButton=paperplane+sendLabel(按 kind/文件/taskTarget);captureHint 按 kind。
- Swift 改动: NotchView.swift(captureCell 头部+重构、sendButton/sendLabel/captureHint)
- VibeHub: record_decision「速记布局对齐 HTML」→ c517a0c1-8f42-4280-b335-4a7ec48a4e5e (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:HTML 靶图对比,布局已对齐
- 状态: ✅ 待 review

## 2026-07-01 02:36 · swift-align-26-visualdiff-transport-glyphs
- 对齐: 视觉 diff 首轮(browse 截 HTML dash/media 靶图逐项对比)
- HTML 基线: V.dash npctrl / V.media mctrl2 / .coverexp(靶图 /tmp/html-dash.png、html-media.png)
- HTML↔实际对比: ① 媒体控制 HTML 用文本字形 ◀◀/❚❚(播)·▶(停)/▶▶,我用了 SF Symbols(形状不同)。② dash 封面 HTML 有 .coverexp 小展开图标(bottom-right),我漏了。
- 做了: dash + media 控制改 HTML 同款文本字形(dash 12/media 15·pp21);dash 封面加展开字形(19×19 圆角黑底 + SF arrow.up.left.and.arrow.down.right)。
- 取舍: 文本字形单色非 emoji 守规则;展开图标用 SF 近似 HTML 4 角括号 SVG。
- Swift 改动: NotchView.swift(dashMediaWidget/mediaModule 控制、dashCover coverexp)
- VibeHub: record_decision「媒体控制文本字形+封面展开图标」→ 093fda1a-e73b-4526-9eb4-5ce8f22399c6 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:HTML 靶图已截对比,Swift 已对齐字形
- 状态: ✅ 待 review

## 2026-07-01 02:28 · swift-align-25-media-zoom
- 对齐: 媒体 zoomTo 缩放钻入(用户 #1 列了 zoomTo)
- HTML 基线: zoomTo(scale .97 淡出 .16s → scale .955→1 淡入 .34s cubic-bezier)
- HTML↔实际对比: dash↔media 我原用横滑,HTML 用缩放钻入。
- 做了: moduleTransition 加 media 特例(module==.media 时 scale insertion .955→1 / removal→.97 + opacity),其它模块仍横滑。利用 SwiftUI 保留被移除视图 transition 的特性,让 media 进/离场缩放。
- 取舍: dash 侧仍横滑(HTML 两侧对称缩放,.id/.transition 模式难两侧对称,不做大重构);media 是显著视图,zoom 已抓住精髓,TODO 实机看混搭;enter .3s(HTML .34s 近似)。
- Swift 改动: NotchView.swift(moduleTransition media 分支)
- VibeHub: record_decision「媒体 zoomTo 缩放钻入」→ cdbf1a8a-78c0-4967-968d-11a48460adc0 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败;视觉:动效待实机(参数对齐 HTML zoomTo)
- 状态: ✅ 待 review  |  滑动三件(slideTo/slideDev/zoomTo)全对齐

## 2026-07-01 02:20 · swift-align-24-daily-random-theme
- 对齐: 「每天随机一套」dailyRandTheme(随机主题最后一块)
- HTML 基线: dailyRandTheme()(di 日种子 LCG 选材质+palette+while 对比≥3.2)+ cfg.dailytheme toggle
- HTML↔实际对比: 我有 randomTheme 但没每天自动版。
- 做了: Core +dailyRandomTheme cfg + nonisolated dailyThemeChoice(di 种子 LCG,当天稳定/午夜变);refreshTheme 重构(开时走日种子+applyingTheme 重入守卫);randomTheme 先关 dailyRandomTheme。设置加 toggleRow(.switch tint accent)(+2 测)。
- 取舍: 开时 daily 接管(盖过手动 mode/material,合 HTML 语义);日种子确定性(每天稳定+变化即可)。
- Swift 改动: HelmNotchCore/NotchModel.swift(dailyRandomTheme/refreshTheme/dailyThemeChoice)、HelmNotchApp/SettingsView.swift(toggleRow+开关)、Tests(+2)
- VibeHub: record_decision「每天随机一套」→ 31c94ee2-19cd-4d97-b94d-c81ae0163810 (ai_proposed)
- 验证: swift build ✓ / swift test 59 通过 0 失败(修 1 轮 nonisolated);视觉:逻辑对齐 HTML,实机待用户
- 状态: ✅ 待 review  |  随机主题(randomTheme+dailyRandTheme)全端口完

## 2026-07-01 02:12 · swift-align-23-random-theme
- 对齐: 「随机一套」randomTheme(用户「html 里面还有随机什么的」)
- HTML 基线: randomTheme()(随机材质+随机 palette+while 对比≥3.2+applyMat/applyAccent+flash)
- HTML↔实际对比: 我没有随机主题功能;Core 已有 contrastSafeAccent → randomTheme 简化为随机 material + 随机 fixed accent(refreshTheme 自动保对比)。
- 做了: NotchModel.randomTheme()(themeMode=.fixed + 随机 fixedColorIndex + 随机 backgroundMaterial,didSet 触发对比矫正);设置 外观 加「随机一套 ↻」按钮(+1 测)。
- 取舍: Swift 用 Int.random(运行时 UI 随机 OK);HTML 的 flash 对比值气泡暂不做(TODO toast);dailyRandTheme(每天随机 toggle)下块。
- Swift 改动: HelmNotchCore/NotchModel.swift(randomTheme)、HelmNotchApp/SettingsView.swift(随机按钮)、Tests(+1)
- VibeHub: record_decision「随机一套 randomTheme」→ 2aee7ffa-20f0-4f02-88b0-501ddd36ff99 (ai_proposed)
- 验证: swift build ✓ / swift test 57 通过 0 失败(randomTheme 24 次随机全 contrast≥3.0)
- 状态: ✅ 待 review

## 2026-07-01 02:06 · swift-align-22-glass-contrast
- 对齐: 玻璃背景对比度自适应(用户「玻璃背景+字体必须有对比度」)
- HTML 基线: MATS[].rep / _lum / _contrast / randomTheme 的 while 对比循环
- HTML↔实际对比: HTML 有对比度自适应(<3.2 就 亮背景×0.55 / 暗背景×1.2+28,≤8 步)但只在 randomTheme 跑;我 block19 accent 完全没自适应 → 白玻璃上浅 accent 不可读。browse 实测:玻璃 notchbg 14% 白叠深色页读作深色、白字可读(靶图 /tmp/html-lightglass-plain.png)。
- 做了: Core Theme +materialBackground/luminance/contrast/contrastSafeAccent(1:1 复刻);NotchModel.refreshTheme 过 contrastSafeAccent、backgroundMaterial didSet 重算(+4 测)。
- 取舍: 比 HTML 略强——每次材质变化都保证对比(用户明确要求);黑底默认 no-op 零变化;字体仍白(和 HTML 一致)。browse harness 打通可渲染靶图。
- Swift 改动: HelmNotchCore/Theme.swift(+对比度算法)、NotchModel.swift(refreshTheme/didSet)、Tests(+4)
- VibeHub: record_decision「玻璃对比度自适应」→ 2da15102-2fcf-4444-9007-8e6976965f93 (ai_proposed)
- 验证: swift build ✓ / swift test 56 通过 0 失败;视觉:HTML 靶图已截并核对,Swift 算法逐值对齐
- 状态: ✅ 待 review

## 2026-07-01 02:00 · swift-align-21-slide-smoothness
- 对齐: 滑动丝滑度(用户反馈「滑动不够丝滑」)
- HTML 基线: slideTo / slideDev / .notch width·height transition
- HTML↔实际对比: ① 我用 .move(edge:) 滑整帧宽,HTML slideTo/slideDev 只平移 46px(横)/34px(纵)——位移量差一个数量级=大跳跃。② HTML notch transition .46s cubic-bezier(.32,.72,0,1),我漂成 grow 0.5/height 0.42。
- 做了: 新增 SlideOffsetModifier + AnyTransition.notchSlide(dx,dy)(固定 offset+opacity);moduleTransition ±46px 横移、devTransition ±34px 纵移;shell grow+height reflow 统一 0.46s;enter 保持 .3s cubic-bezier。
- 取舍: 动效丝滑靠逐值对齐 HTML 参数验证(静态截图看不出),非数据问题。
- Swift 改动: NotchView.swift(moduleTransition/devTransition/SlideOffsetModifier/notchSlide、grow+reflow 时长)
- VibeHub: record_decision「滑动丝滑度对齐」→ 2556cd8b-b89c-4a57-be44-28b8f053f3fb (ai_proposed)
- 验证: swift build ✓ / swift test 52 通过 0 失败;视觉:动效待实机手感(参数已逐值对齐 HTML)
- 状态: ✅ 待 review

## 2026-07-01 01:40 · swift-align-20-land-decisions-cleanup
- 对齐: 用户拍板 3 个 [needs-human] 后的落地清理(非新 HTML 块)
- HTML 基线: —(架构/高度/材质取舍定案)
- 做了: ① 全面转 dock,删死代码(grid/cell/vline/hline/topControls + mediaCell/calendarCell + artwork/progressBar/transport/monthLabel/weekDays + StatusGlyph/GlowPill/glowingPill);保留 EqualizerBars/cellHeader/agentCell/captureCell。② 全自适应高度,删拖拽高度持久化(Controller heightKey load/save + 常量删;resize 仅宽)。③ 材质保留 4 档默认纯黑(block19 已是,无改)。NotchView 顶 doc 改 dock 描述。
- 取舍: scroll 方向留用户实机校准。死代码删除逐个 grep 确认只被死代码引用再删,零回归。
- 改动: HelmNotchApp/NotchView.swift(删 ~250 行死代码+顶 doc+resize 注释)、NotchController.swift(删 heightKey 持久化)
- VibeHub: record_decision「3 个 needs-human 定案+落地」→ daff6e2f-e296-4b85-a6c4-d8d95043c66e (ai_proposed)(对应关闭 question 3edd9817/7597d8c5/dbba2873)
- 验证: swift build ✓ / swift test 52 通过 0 失败;视觉:删死代码不影响运行路径,待用户实机
- 状态: ✅ 已落地 3 拍板  |  ❓剩:scroll 方向实机校准 + 后端 TODO 群

## 2026-07-01 01:18 · swift-align-19-background-material
- 设计源: helm-notch-pro.html(settingsHTML MATS / .mat-* / applyMat)
- 界面: 背景材质选项(默认纯黑)
- 做了: Core NotchMaterial(black/darkGlass/lightGlass/vibrant)+ backgroundMaterial(默认 black);App shell 背景改 materialBackground(black 不变;玻璃档 .ultraThinMaterial/.regularMaterial+tint 透壁纸);设置 外观 加材质 picker(色板+选中 accent 边)(+1 测)。
- 取舍: 与「黑底+accent-only」美学冲突 → 默认纯黑(视觉零变化),玻璃仅可选,开 [needs-human] question dbba2873;玻璃实机效果无头不可验证(NSPanel 透壁纸),TODO 待实机。
- 改动: HelmNotchCore/Theme.swift(+NotchMaterial)、NotchModel.swift(+backgroundMaterial)、Tests(+1)、HelmNotchApp/NotchView.swift(materialBackground)、SettingsView.swift(materialPicker)
- VibeHub: record_decision「背景材质选项」→ 15036420-0100-4df0-b8b1-0f66ae8e068a;add_question「[needs-human] 是否开放玻璃材质」→ dbba2873-7dbc-4c45-b27c-13767558a415(均 ai_proposed)
- 自检: 硬门 swift build + swift test 全绿,52 测 0 失败(+1 材质默认/可切)。默认黑视觉零变化。玻璃实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: 玻璃材质是否开放(已开 dbba2873)

## 2026-07-01 01:11 · swift-align-18-dev-vertical-slide
- 设计源: helm-notch-pro.html(slideDev / switchDev 纵向分页动画)
- 界面: Dev 子页纵向滑动分页动画
- 做了: Core +devSwitchForward;switchDev 设方向、新增 selectDev(索引差推方向)(+1 测)。App devStage .id(devSection)+.transition(纵向 asymmetric:forward 下入上出)+.animation(.3s,value:devSection),.clipped;rail 点击改 selectDev(s)。
- 取舍: 与 block17 模块横向滑入配套,分页动画故事完整。
- 改动: HelmNotchCore/NotchModel.swift(+devSwitchForward/switchDev/selectDev)、Tests(+1)、HelmNotchApp/NotchView.swift(devStage id+transition+animation、devTransition、rail selectDev)
- VibeHub: record_decision「Dev 纵向滑动分页」→ bf75bca2-aaf8-483f-9ec5-84e3d7d88004 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,51 测 0 失败(+1 方向)。对照 HTML:slideDev 纵向方向性。视觉实机待用户。
- 状态: ✅ 待 review

## 2026-07-01 01:06 · swift-align-17-module-slide-transition
- 设计源: helm-notch-pro.html(slideTo / switchModule 动画)
- 界面: 模块切换方向性滑入动画
- 做了: Core +moduleSwitchForward;selectModule 从 dock 索引差推方向、switchModule 用 dir,统一 setModule(m,forward:)(+1 测)。App moduleBody .id(module)+.transition(asymmetric 方向滑入 forward:trailing 入/leading 出,combined opacity)+.animation(.3s timingCurve, value:module),.clipped 防溢出。
- 取舍: HTML dash↔media 用 zoomTo 缩放钻入,本块统一 slide(media 缩放特化 TODO);Dev 子页纵向 slideDev 未做(devSection 不改 module,需单独纵向 transition,TODO)。
- 改动: HelmNotchCore/NotchModel.swift(+moduleSwitchForward/setModule/select·switchModule 重构)、Tests(+1)、HelmNotchApp/NotchView.swift(moduleBody id+transition+animation、moduleTransition)
- VibeHub: record_decision「模块切换方向性滑入」→ 217bf171-9e92-4ce6-a9f7-a357daa3bc5f (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,50 测 0 失败(+1 方向追踪)。对照 HTML:slideTo 方向性滑入。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: media 缩放钻入、Dev 纵向分页动画(均 TODO)

## 2026-07-01 01:00 · swift-align-16-ask-brain-kind
- 设计源: helm-notch-pro.html(cap kind 'ask' / CHIPS 五项 / capatt 条件)
- 界面: 问大脑(ask)速记 kind
- 做了: Core CaptureKind +.ask;submit ask→createNote(kind:"ask");App placeholder ask、chips 现 5 个、时间/地点附件收紧为仅 note/task(还原 HTML capatt)(+1 测)。
- 取舍: HTML ask 亦为 stub(只 flash);暂存为 ask note,真实大脑查询/回答通道 TODO。
- 改动: HelmNotchCore/Models.swift(+.ask)、NotchModel.swift(submit ask)、Tests(+1)、HelmNotchApp/NotchView.swift(placeholder、attachmentRow 条件)
- VibeHub: record_decision「问大脑 kind」→ 1152eca6-4fe7-4112-adf9-38d8315358ef (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,49 测 0 失败(+1 ask)。对照 HTML:CHIPS 五项、capatt 仅 note/task。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: 大脑查询/回答通道(TODO)

## 2026-07-01 00:55 · swift-align-15-file-drop-attach
- 设计源: helm-notch-pro.html(notch.drag / drop handler / addFiles / .attchip)
- 界面: 拖文件到刘海 → 速记附件
- 做了: Core CaptureFile + NotchModel captureFiles/addFiles(切 capture/focus→note/expanded)/removeFile;submit 清空 files(+2 测)。App shell .onDrop(.fileURL)→addFiles;拖拽时 NotchShape 虚线 accent 轮廓;captureCell captureFilesRow(横滑文件 chip:ext 徽标+名+×)。
- 取舍: 真实上传到 Helm(/api/files 或 RAG)未做(submit 仅清空,TODO);Files 整模块不进 dock(HTML 亦然),只做「拖进刘海→速记附件」可达路径。
- 改动: HelmNotchCore/Models.swift(+CaptureFile)、NotchModel.swift(+captureFiles/addFiles/removeFile/submit 清空)、Tests(+2)、HelmNotchApp/NotchView.swift(import UTType、dragOver、shell onDrop+虚线轮廓、captureFilesRow)
- VibeHub: record_decision「拖文件→速记附件」→ 36b553f3-1a02-461a-8f82-1f6e831eff90 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,48 测 0 失败(修 1 轮:NotchShape strokeBorder→stroke)。对照 HTML:notch.drag 虚线、attchip ext 徽标+×。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: 文件上传到 Helm 通道(TODO)

## 2026-07-01 00:49 · swift-align-14-agent-think-shine
- 设计源: helm-notch-pro.html(V.agents / .think .st / .shine / dash agr)
- 界面: agent 运行态 think/shine 动效
- 做了: 新增 ShineText(亮带扫过文字,linear 1.6s 循环,mask 文字,fixedSize)。Dev agents running 行加 小 SpinningStar + ShineText(activity 或「正在思考…」);Dashboard 本机 CLAUDE CODE running 行 ShineText(activity 或「思考中」)。复用 SpinningStar。
- 取舍: HTML .shine 多色渐变横扫 → 简化为 透明→白→accent→透明 亮带扫过(观感一致)。纯 App UI。
- 改动: HelmNotchApp/NotchView.swift(ShineText struct、agentCell running 行、dashAgentWidget running 行)
- VibeHub: record_decision「agent think/shine 动效」→ 2dc68ed9-6128-4953-81df-4fd132d0a695 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,46 测 0 失败(纯 UI)。对照 HTML:cstar ✻ 自转、shine 亮带横扫。视觉实机待用户。
- 状态: ✅ 待 review

## 2026-07-01 00:44 · swift-align-13-collapsed-bar-fidelity
- 设计源: helm-notch-pro.html(renderBar / .cc .lens / .cnp / .cstar / .cev)
- 界面: 折叠条保真(相机 lens / 曲名 / 运行 ✻ / 等权限橙点 / 下个日程)
- 做了: 中间间隙加相机 lens 点(7×7 深+内环);折叠左播放态加曲名(max-width 90 截断);折叠右 等权限=橙●+count、运行=旋转✻(SpinningStar linear 1.1s)+count、空闲有事件=下个日程「HH:MM summary」(accent 时间)。
- 取舍: 旧 StatusGlyph/GlowPill 不再用于折叠右(留死代码无警告,待 2×2 question 清理);SpinningStar 仅自转(HTML cstar 的 scale/opacity 脉冲简化)。纯 App UI。
- 改动: HelmNotchApp/NotchView.swift(collapsedBar lens、collapsedLeft 曲名、collapsedRight 字形对齐、SpinningStar struct)
- VibeHub: record_decision「折叠条保真」→ 0b0d9663-5bed-4957-8a11-150e163e987e (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,46 测 0 失败(纯 UI)。逐项对照 HTML CSS:lens 7×7、cnp 90 截断、cstar ✻、cev accent 时间。视觉实机待用户。
- 状态: ✅ 待 review

## 2026-07-01 00:39 · swift-align-12-reminder-banner
- 设计源: helm-notch-pro.html(remindHTML / .notch.remind / .rmd* / REMINDER)
- 界面: 日程提醒 banner(560×152)+ 真实临近触发
- 做了: Core EventReminder + NotchModel reminder/checkReminders(now:)(解析事件 when 前缀 HH:mm,与当前分钟差 0..5 弹,跳过已忽略)+startMinutes(nonisolated)+dismiss/snooze/openReminder;poll 末调 checkReminders(+4 测)。App shell reminder 分支(优先级高于等权限 banner);remindBanner(日历字形卡 56+「日程提醒·现在开始」+标题 18heavy+时间段 mono+查看/稍后/忽略);Controller activeSize 560×152。
- 取舍: HTML 显「加入」会议链接+地点,CalEvent 无 join/location → 改「查看」(开日历)+时间段,省地点(TODO 真链接/地点需后端字段)。触发用 when 前缀 HH:mm 启发式(全天/无时间跳过),依赖后端 when 格式。
- 改动: HelmNotchCore/Models.swift(+EventReminder)、NotchModel.swift(+reminder 态/checkReminders/poll)、Tests(+4,FakeBackend +events/listEvents)、HelmNotchApp/NotchView.swift(body/shell reminder 分支/remindBanner)、NotchController.swift(activeSize)
- VibeHub: record_decision「日程提醒 banner+真实触发」→ a0a5a5d0-59e2-402f-8e78-0192cc93b870 (ai_proposed);add_question 无;add_constraint 无
- 自检: 硬门 swift build + swift test 全绿,46 测 0 失败(修 1 轮:startMinutes static 在 @MainActor 类被隔离 → nonisolated)。+4:解析/临近触发/远事件不弹/忽略不再弹。视觉实机待用户。
- 状态: ✅ 待 review  |  ❓需确认: 会议加入链接/地点字段(后端,TODO)

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
