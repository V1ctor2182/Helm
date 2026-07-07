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

## 2026-07-07 迭代 8 — B7 日历页 ✅
- NOMI 周条(周一起头 7 天,今天=渐变胶囊)+事件行(mono 时间 40px+渐变竖条 3px+标题,hair 分隔,诚实空态)+addev 胶囊。
- 加事件通道:后端无建事件 API(契约不动)→ `addEventViaAgent` 走 createTask("加日历事件:…"),真 agent 任务解析时间,非假灯。
- 月视图/月偏移/双栏 agenda 随稿退役(设计稿功能清单明确"周条+今日事件+加事件");calMonthView 属性保留但不再影响高度;日历预算 312/240→260。
- 全测试绿(高度断言已更新);快照 b7-cal.png(事件区空态在 ScrollView 内,快照工具不渲染,真机正常)。

## 2026-07-07 迭代 9 — B8 暂存页 ✅
- filesModule:虚线 dropzone(dragOver 橙热态)+shelf 文件卡(渐变块 ext+上传到记录/移除)+剪贴板段。
- 剪贴板换真数据:ClipboardWatcher(2s 轮询 NSPasteboard.changeCount)喂 model.clipboardHistory(去重/上限 5);行内 复制(回写剪贴板)/存速记(createNote)。旧 clipSeed 假数据删除。
- 「上传到记录」=文件名折进 note(同速记页附件做法,真文件上传等附件 schema);「关联驾驶舱」无后端通道,本版不放按钮(不做假动作),记 backlog。
- 拖文件路由改 NOMI 语义:落 shelf(files 页),不再跳速记页;addFiles 不再动 captureKind。
- files 预算 232→280;测试 3 处断言更新+新增剪贴板去重/上限测试;全绿。快照 b8-files.png。

## 2026-07-07 迭代 10 — B9 智能体页 ✅
- sdots:右缘子页圆点(激活=渐变 14px 长条,可点跳页);上下滑翻页机制沿用(model 驱动+snap 式离散页,行为等价 HTML scroll-snap)。
- 会话页:subh(会话·上下滑看端口/PR+待处理计数)+NOMI 会话卡(光环状态点/claude·目录/右 mono 状态/一行动态,思考态 ✻+shine 保留);空态诚实提示;点卡进详情(vibeisland 详情/回答/idle 回复全保留,SessionDetailView 整体换 palette)。
- permcard NOMI:左橙边 wcard+spark+pill 命令块+Allow(kbtn)/Deny(pbtn);真 diff 仍待 hook 带 patch(TODO align-diff)。
- 端口页换真数据:PortsProbe(lsof -nP -iTCP -sTCP:LISTEN -F cn)→model.localPorts(进页 .task 刷新,后台线程);「打开」=NSWorkspace 开 localhost:port;portSeed 假数据删除。
- PR 页:NOMI prrow 卡+chip;数据源仍 seed → 页头明示「示例数据·接入待定」(TODO align-pr:gh CLI 或后端接口)。
- 预算:sessions 260/ports 260/prs 300(详情 316);测试同步,全绿。快照 b9-sessions/ports/prs。
- 决策:会话卡内嵌选择题 qbtns 不做——needsAttention 时 banner 态整体接管 notch,卡上按钮永远不可见;选择题作答留在 B10 banner。

## 2026-07-07 迭代 11 — B10 banner 单体化 ✅
- 横幅从 620 ORAGE 橙黑改 NOMI bannermode:460 宽、面板底色(shell 生长复用,banner 态=open 底色+圆角 26)、spark+claude·目录头、pill 命令块、Allow(kbtn)/Deny/打开会话(pbtn)。
- 「打开会话」逃生口:bannerSuppressed 压横幅→智能体页列表内 permcard 处理;新 PermissionRequest 或解决后自动复位重弹(有测试)。
- 选择题横幅同套 NOMI:spark 头/选项 pill+渐变描边选中/提交=渐变胶囊/终端作答+打开会话;答案注回 updatedInput 链路不变。
- ⌘Y/⌘N 文案保留(快捷键接线仍在账上,非本稿新增);reminder 横幅未 NOMI 化(设计稿无此稿面,B11 顺手)。
- 全测试绿;快照 b10-banner-perm/ask。

## 2026-07-07 迭代 12 — B11 浅色+收尾 ✅(loop 完成)
- 面板残留硬编码白色清扫(cellHeader/附件 chips/ask 卡/recents/statusLabel→palette;折叠条/媒体大卡 meta 等黑底场景白色保留是正确的)。
- 设置「外观」区:旧材质/每日主题控件退役 → 「深色面板」开关(UserDefaults notch.nomiDark 持久化,Controller 启动读回)。
- 快照套件加 light-dash/cap/agents/banner 四浅色位;修浅色暴露的两个瑕疵:顶行 Helm 字被凹槽压边(左翼收紧 17/5/12/8)、PR chip 写死深色值(改双模式)。
- 全测试绿;终报 reports/final-b1-b11.md。**B1-B11 全部对齐,loop 收工——CI 过后留用户合并。**

## 2026-07-07 迭代 13 — 用户实测反馈两连修
- 布局重叠:旧版可拖宽的持久化 notch.expandedWidth(600)在 NOMI 下生效,把 440 定稿布局撑爆——改为启动清 key+固定 440,拖宽手柄下线(设计无此交互)。
- 总览媒体卡加 前/播暂/后 迷你控制钮(半透明白,吃自身点击不触发 zoom);波形挪右上角。[用户反馈]
- 全测试绿;已重打包重启预览版。

## 2026-07-07 迭代 14 — 深色可读性修复 [用户反馈]
- 根因:notch 窗口外观跟系统(浅色),TextField 占位符等系统自配色按浅色方案渲染,深面板上沉底看不见。
- 修:NotchView 根 .preferredColorScheme(nomiDark ? .dark : .light)(系统自配色/光标/选中色全跟面板走);六处输入框(quickcap/addev/速记/专注/回复/选择题自由填)补显式 ink3 占位色;设置窗锁 .dark。
- 全测试绿;已重打包重启。

## 2026-07-07 迭代 15 — 用户实测四连修
- clip 根治:capture 全 kind 预算上调(note/journal 232·task 256·ask 340)、dashboard 280、media 345+歌词列限高 190(顶开 dock 的元凶);dock 圆钮 40→34(用户:小一点)。
- **专注改番茄倒计时(Q4 用户拍板)**:初始即环(25:00 已暂停)+关联任务+开始/暂停·重置·换任务(行内编辑);跑完自动落库 focus note;暂停进账(banked)可续;折叠态显示剩余。旧「输入→正计时」流退役。
- 测试:高度断言全套跟进+新增番茄暂停/续/归零测试;全绿。已重打包重启。

## 2026-07-07 迭代 16 — 拖文件 dropmode(HTML 定稿 → Swift)[用户拍板]
- 设计稿新增 dropmode(壳生长复用):拖文件悬入 → 440 承接面(渐变圆+下落箭头+「松手—暂存到 Shelf」,虚线亮橙);拖走收回(不动 expanded,原开合自然恢复);松手→shelf+暂存页。深度计数防抖(HTML)/isTargeted(Swift)。
- Swift:dragOver 驱动尺寸+内容分支(压过横幅),生长动画 .46s 同 hover;旧的描边高亮退役。
- 主检出设计稿已同步注记「用户拍板新增」;全测试绿,已重打包重启。
