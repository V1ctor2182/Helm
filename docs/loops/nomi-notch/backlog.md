# NOMI notch 重塑 backlog

设计基线(只读):`docs/design/helm-notch-nomi.html`(726 行,dark 为默认态)。
现状基线:`notch/Sources/HelmNotch{Core,App}`(ORAGE 黑底单色,vibeisland 交互已落地)。
硬门:每块 `swift build && swift test` 绿 → commit 到 `feat/notch-nomi-*`;快照对比;不合 main。

## 块清单(顺序即依赖)

- [x] **B1 主题基建** — NomiTheme:dark 默认(`#0f0f11`/card `#1d1d21`/ink `#f2f2f4`/pill `#232327`/hair `#2a2a2e`)+light 全套;橙紫渐变 accent(`#ff8a3d→#a855f7`,取代每日轮换色);wcard/gbtn/kbtn/pbtn 样式原语;设置里深/浅切换。
- [x] **B2 单体壳+折叠态** — 折叠 310×34 黑条:左组(logo+minicover+渐变波形 4 柱)—摄像头空档(.cam 点)—右组(● N live);展开 440px、圆角 26、shadow-xl;banner 态 460px;同一元素生长(width/radius 过渡 .46s cubic-bezier(.32,.72,0,1))。
- [x] **B3 顶行+dock+模块重组** — 展开顶行:左 logo+Helm(点开 Helm 主 app)、中黑条常驻摄像头凹槽(310px)、右天气+齿轮;底部 5 圆钮 dock(总览/速记/日历/智能体/暂存),激活=渐变描边环;NotchModule 重组:media=总览封面 zoom 目标,clipboard 并入 files,dev→agents;横扫切模块保留(阈值 90/锁 450ms 对齐 HTML)。
- [x] **B4 总览 bento** — 1.35fr:1fr 网格:大媒体卡(渐变底+meta 压底+eq 3 柱,点→媒体页)、日历卡(spark+下一项)、智能体卡(okdot+会话名+一行状态)、速记胶囊输入条(⏎ 发送)。
- [x] **B5 媒体页** — ‹总览 返回条;左列 88px 封面+标题+可点 seek 进度渐变条+times+控制钮(play 44px 黑底);右列歌词 roll(mask 上下渐隐、当前句 16.5px/800 高亮、.55s 滚动)。
- [x] **B6 速记页** — kind 胶囊 5 个(on=黑底);任务 kind 显示 who 双轨(给自己/交给 agent,on=渐变);capbox 灰底圆角 16;问大脑 askout 卡;最近 N 条可折叠(▸ 旋转);专注 kind=番茄钟页(conic 渐变圆环+开始/暂停/重置+关联任务)。
- [x] **B7 日历页** — weekbar 7 天(今天=渐变胶囊);事件行(mono 时间+渐变竖条+标题/副行,hair 分隔);底部加事件胶囊输入(AI 解析时间,走现有 capture 通道)。
- [x] **B8 暂存页(files)** — 虚线 dropzone(hot 态橙);shelf 文件卡(色块图标+名字/大小+上传到记录/关联驾驶舱/移除);下方剪贴板段(复制/存速记);拖文件到刘海→dragover 描边+跳暂存页。
- [x] **B9 智能体页** — permcard(左橙边+diff 红绿行+Allow/Deny);会话卡(d-live/d-wait/d-idle 光环点+nm+右 mono 状态+一行 ln);选择题会话卡内嵌 qbtns(pri=渐变);三子页上下滑(会话/端口/PR)snap+右侧 sdots(on=渐变长条);PR 页数据源待定(先 seed,契约不动)——保留 vibeisland 详情页/回答/回复能力,重皮不减功能。
- [x] **B10 banner 单体化** — 权限/选择题横幅=shell 内容切换(bannermode 460px),permcard 风(spark+粗体路径+diff+Allow/Deny/打开会话);打开会话→agents 页;与 B9 共用组件。
- [ ] **B11 浅色+收尾** — light 全套走查(每页快照 dark/light 双份);设置面板 NOMI 化+深浅切换;快照全家福 vs 设计稿逐块对比;补测试;README/报告收尾。

## 决策记录
- 每日轮换 accent 让位给固定橙紫渐变(设计稿唯一 accent 语言)——原 Theme.accent 保留代码但 NOMI 模式不用。(如需保留每日色,记 open question)
- 智能体 PR 子页现网无数据源(后端契约不动)→ 先 seed 数据 + TODO(align-pr),同现有 ports 做法。
- vibeisland 交互(选择题作答/详情/idle 回复)全部保留,只换皮。
- vibehub MCP 本会话未连接(record/add_question 不可用)→ 决策记本文件,产品问题走 Open questions + 报告。

## Open questions(待用户,不阻塞)
- Q5: shelf 的「关联驾驶舱」无后端通道(契约不动)→ 本版未放按钮;要做的话需要后端出接口。
- Q1: 折叠态右组 "1 live" 的口径:live=running 会话数?待批准时显示什么(设计稿只画了 live 态)?——先按 running 数,待批准=橙点+数字。
- Q2: 每日变色是否彻底退役?——先退役,保留代码可回切。
- Q4: 专注计时语义:现行「正计时+停止记录」 vs 设计稿「25min 番茄倒计时(开始/暂停/重置)」?——先保现行语义+NOMI 环外观,待拍板。
