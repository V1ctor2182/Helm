# Notch 优化 Loop · 处理流水

> 每把 `helm-notch-pro.html` 设计的一块对齐进 Swift App,loop 在这里追加一条。格式见 `notch-loop-procedure.md` 附录 C。
> (下面 2026-06-30 那批是早期"改 HTML"阶段的历史记录,现 loop 已改为「HTML 只读、改 Swift」。)
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

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
