# NOMI notch 重塑 loop · log

## 2026-07-07 迭代 1 — 启动
- 通读设计稿 `docs/design/helm-notch-nomi.html`(726 行)+ 现状(昨日 vibeisland 交互刚落地,全部保留只换皮)。
- 建 backlog:B1 主题基建 → B2 单体壳/折叠态 → B3 顶行+dock+模块重组 → B4-B8 五模块页 → B9 智能体 → B10 banner → B11 浅色收尾。
- 设计稿要点:dark 默认(#0f0f11 面板/#1d1d21 卡);折叠 310px(左 logo+minicover+波形—cam—右 ● live);开 440px 圆角 26;banner 460px;dock 5 圆钮(渐变描边环);媒体从总览封面进,剪贴板并入暂存,专注并入速记;智能体三子页上下滑(会话/端口/PR)+sdots。
- git 基线:昨日 vibeisland 改动(用户已实测验收)先独立 commit 在 feat/cockpit-fanbox,再切 feat/notch-nomi-m1 —— nomi 块提交不混入前作。
- vibehub MCP 未连接:record/add_question 落 backlog 的决策/Open questions 段代替。
- 环境:共享检出上有另一个活跃 loop(主 app NOMI,feat/nomi-reskin)——本 loop 迁入独立 worktree `../helm-notch-nomi`(feat/notch-nomi-m1),互不踩分支;vibeisland 基线 commit(341db7d)落在 feat/nomi-reskin 上(分支点),无害。
- 本 loop 不重启用户的 Helm Notch.app(不合 main 前现网保持 vibeisland 版),视觉门用 --snapshot。

## 2026-07-07 迭代 2 — B1 主题基建 ✅
- Core `NomiTheme.swift`:NomiPalette dark/light 成套(逐 token 对齐 CSS 变量)+渐变/状态色/壳几何常量;NotchModel.nomiDark(默认深)+nomi 计算色板。
- App `NomiStyle.swift`:gradient(135°/90°/180°)、wcard(dark=发丝边,light=柔影)、GradientButton/InkButton/PillButton、SparkDot。
- Tests `NomiThemeTests` 5 条全绿;全套 suite 无失败无崩溃。
- 视图尚未接线(B2 起换装)——本块纯地基,无视觉变化。

## 2026-07-07 迭代 3 — B2 单体壳+折叠态 ✅
- 折叠条 NOMI 化:左组 HelmLogoView(SVG Path 移植:外框+双眼+圆头眉)+MiniCover 18px+WaveBars 渐变 4 柱呼吸;右组 ●"N live"mono(待批=橙"N 待批",Q1 口径);高 34;宽下限 310(实测回填机制保留)。
- 壳:展开底色走 nomi.shellBG(深 #0f0f11 默认),折叠纯黑;圆角 14/26;expandedWidth 默认 600→440。玻璃材质暂时退役(B11 定去留);焦点态折叠显示保留旧行为(设计稿未覆盖)。
- build+test 绿(无失败无崩溃);快照 shots/b2-collapsed.png(logo/摄像头点/状态点就位)。
- 遗留:壳生长动画仍 .36s(设计 .46s,B3 顶行改造时一起调);窗口级 shadow-xl 待查 NSPanel 阴影可行性。

## 2026-07-07 迭代 4 — B3 顶行+dock+模块重组 ✅
- NotchModule 重组:dashboard/capture/calendar/agents/files(+media zoom 目标);clipboard 模块退役(列表暂挂 files 页,B8 重做);DevSection→AgentPage(sessions/ports/prs),reviews/stats 内容删除(设计稿无此页)。
- NOMI toprow:左娃娃脸 logo+Helm、中黑条常驻摄像头凹槽(≥310/物理宽+20,底角 14)、右齿轮;topBarHeight 30→34。天气位留空不放假灯(Q3)。
- dock:5 圆钮 40px SF 符号,激活=渐变描边环(mtab.on);agents 待批橙点徽章保留。
- 横扫切模块/上下滑子页机制沿用(改指 agents);智能体徽章/详情页防误翻逻辑随迁。
- 全测试绿(0 失败 0 崩溃);快照 b3-dash/b3-agents(dock+toprow 就位;各页内容仍旧版式,B4-B9 逐页重做)。

## 2026-07-07 迭代 5 — B4 总览 bento ✅
- dashboardModule 重写为 NOMI bento:大媒体卡(渐变底/封面填充+meta 压底渐晕+eq 3 柱,点→媒体)、日历卡(spark+下一项,无日程诚实空态)、智能体卡(okdot/warn 点+首会话+状态行)、quickcap 胶囊(⏎/发送→model.quickNote 直发后端 note,不动速记页状态)。
- 旧三栏 widget(donut/任务行/迷你控制条)退役;dashboard 预算 172→252(含 dock)。
- 全测试绿;快照 b4-dash-bento.png 与设计稿 dash 段对齐(输入框黄条=ImageRenderer 已知 artifact)。

## 2026-07-07 迭代 6 — B5 媒体页 ✅
- mediaModule 重写:‹总览 pill 返回条+源切换 pill;左列 196(封面 88 r16/标题 14.5/渐变 6px 进度+mono 时间/圆钮控制 36+play 44 ink 底);右列歌词 roll(当前句 16.5/800 ink,邻句 14.5 递减透明,mask 渐隐保留)。
- 背景糊封面+波形层退役(NOMI 面板干净底);dock 在媒体页常驻(对齐 mtabs,预算 330 内)。
- seek:MediaController 无 seek API → 进度条只展示不做假点击,TODO(align-seek) 待协议扩展。
- 歌词三态(同步/纯文本/无词)与换曲重建逻辑保留,颜色切 palette。
- 全测试绿;快照 b5-media.png。

## 2026-07-07 迭代 7 — B6 速记页 ✅
- kind 胶囊(on=ink 底/onInk 字)、任务 who 双轨(on=渐变胶囊,off=cardbg+hair 边)、capbox(pill 底 r16)、发送 gbtn 渐变(空文案=pill 灰)、askout 卡(wcard+spark+「Helm 大脑」头)、最近条 ▸ 旋转折叠。
- 专注:NOMI 渐变环 104(中心 mono 计时+「专注中」)+右列关联任务/停止并记录(kbtn)。语义保持现行正计时记录;设计稿是 25min 番茄倒计时 → 行为差异记 Q4 待拍板,不猜。
- 全测试绿;快照 b6-capture.png。
