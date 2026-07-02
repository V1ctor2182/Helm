# FanBox × helm 驾驶舱 · 行为对照矩阵(阶段 3 账本)

> FanBox = 行为参考不是视觉参考;皮肤守 DESIGN.md,冲突 DESIGN.md 赢。
> 每轮从未勾的最高优先级挑一条;搬完 `[x]`+commit;不该搬标 ~~wontfix~~+理由;卡住标 blocked。
> 基线:FanBox 1.11.3(2026-06-15,两份快照一致);helm 驾驶舱 = 阶段 2 收官态(2026-07-02)。
> 参考实现位置见 FanBox 行为清单(loop 轮 1 盘点,app=public/app.js srv=server.js)。

## P1 · 核心体验差距(intent「找回→预览→轻改→指挥 agent→看清改动」的缺口)

- [x] **预览即编辑 + 停笔 0.8s 自动落盘 + 并发覆盖保护** → 轮2 搬入(textarea 编辑器;md 加「源码」tab;Monaco 语法高亮编辑留 P2) | helm 预览完全只读,intent 的「轻改」整个缺失。代码/纯文本进预览即可编辑;防抖自动保存(写盘串行化+⌘S 立即);写盘带 expectedMtime,被 agent 外改弹覆盖确认;后端原子写(tmp+fsync+rename);>2MB 拒编辑;「xx 之前已保存」字样 | app:1179-1382, srv:409-433
- [x] **终端路径点击(四层识别)+ 点开定位** → 轮3 搬入(URL/引号/斜杠 token/裸文件名白名单+全角切断+折行拼回+服务端 stat 验证划线+点击→驾驶舱定位预览;scrollback 回扫与 Spotlight 兜底留 P2;点击手感待人目视) | URL>引号串>含斜杠 token(服务端 stat 批量验证)>裸文件名扩展白名单;目录尾 `/` 兜底;折行按 cell 拼回;点击→cwd 解析→回扫 scrollback→basename 搜索兜底;md/html 点开全屏 | app:2528-2644, srv:937-1018
- [x] **终端状态感知:busy/idle/dead 圆点 + 完成提醒** → 轮4 搬入(回显过滤/esc 护栏/still-running 压制/ask 单音/done 双音 E5→B5/呼吸 6.5s/SND 静音持久化;系统通知仅在已授权+页面隐藏时,涟漪归属文件区联动留 P2) | 输出→busy(脉冲)、静默 2.5s→idle、进程退→dead;回显过滤(<400ms 不算 agent 干活);busy>4s 收工→涟漪+双音+通知;「esc to interrupt」30s 护栏;「等你拍板」检测单音 | app:2692-2801
- [ ] **文件操作三件套:新建/重命名/删除(废纸篓)+ 右键菜单** | 右键按类型组装菜单(打开/预览/在终端打开/Finder 显示/复制路径/重命名/废纸篓);新建文件即编辑;删除走废纸篓(AppleScript,argv 防注入);重命名拒分隔符 | app:1384-1453, 1638-1677, srv:436-480
- [ ] **列表/网格双视图 + 排序 + 隐藏文件开关** | 网格三档尺寸;列表带表头名称/时间/大小;排序 zh locale+numeric、目录在前;隐藏文件 checkbox 落 localStorage | app:340-401, 2132-2146
- [ ] **缩略图管线(图片先行)** | 图片 sips 生成、md5(路径+mtime+尺寸) 缓存、并发去重、LRU 裁剪;失败回退矢量字形不留裂图;heic/tiff 永远走缩略图 | app:414-429, srv:1174-1229
- [ ] **双击语义 + 图片灯箱** | 单击=分栏预览、双击文本→全屏、pdf/压缩包/二进制→系统 App;图片点击进灯箱(滚轮 0.2-8x、Esc/点空白关) | app:520-536, 759-771
- [ ] **终端手感三小件:Option 拖拽选中 + login shell + Nerd Font 栈** | macOptionClickForcesSelection(TUI 鼠标上报吃拖拽);pty 用 zsh -l 读 .zprofile 找回 claude;JetBrainsMono/MesloLGS Nerd 字体栈防 tofu;低对比自动提亮 minimumContrastRatio 4.5 | app:2459-2510, CHANGELOG 1.11.2/1.11.3
- [ ] **⌘K 内容搜索(`内容:` 前缀)** | mdfind Spotlight 优先(覆盖 PDF/OCR)、回退 grep(512KB 内文本);命中补行级预览+高亮;范围切换 全机/当前目录(Tab 键) | app:1817-1914, srv:269-392
- [ ] **主区键盘导航 + Esc 分层退出** | ↑↓←→ 按实测列数移动、Enter 打开、Space 收藏、F2 重命名、⌘⌫ 废纸篓;Esc 菜单→cmdk→灯箱→全屏→blur→关预览逐层退 | app:402-408, 539-559, 2152-2185
- [ ] **变更收件箱(改·N)** | 顶栏变更徽标;面板列本会话 100 条(去重计数、最新置顶),点行直达预览,可清空;卡片「改·N」热度发光+tooltip 子路径+4.5s 消退(helm 现只有闪一下) | app:437-454, 3193-3253
- [ ] **拖文件进终端** | 卡片可拖,落进终端插入 shell 单引号转义路径;dragover 虚线高亮;全局 drop 兜底防导航 | app:465-511, 2060-2090
- [ ] **监听噪声过滤补全** | 隐藏/点目录、node_modules/dist 等构建目录、sqlite sidecar(-journal/-shm/-wal)、中段 .tmp 原子写临时名——高亮/收件箱/跟随共用一套(helm 现有过滤较粗) | app:3183-3192
- [ ] **跟随模式升级:归属双判定 + 节流优先级 + 代码变动行高亮** | 只跟绑定终端 cwd 且该 agent 正忙;多文件快写节流切目标(html/md>代码>其它);代码重读全文夹逼算变动行区间闪高亮平滑滚;md 尾部贴底/中间不跳;html 双缓冲零白闪 | app:3360-3661

## P2 · 打磨(P1 清完或顺手时做)

- [ ] 路径定位兜底:scrollback 回扫 + basename 搜索 + Spotlight(FanBox app:2373-2431/srv:973-1018;轮3 只做 cwd 解析层) | srv:973
- [ ] 编辑器升级 Monaco(语法高亮/撤销栈灰显;现为 mono textarea) | app:1258-1273
- [ ] 面包屑逐级可点(根电脑图标/挤压滚到末尾/SVG vertical-align:middle) | app:303-338
- [ ] 底部状态条(N 项·文件夹·文件·合计大小) | app:352-364
- [ ] 收藏(卡片 ☆/Space,列表可点可拖) | app:1154-1164
- [ ] 最近修改视图(walk 按 mtime 取 60 条跨目录平铺) | app:1801-1814
- [ ] CSV/TSV 表格只读视图(前 500 行) | app:613-641
- [ ] 预览操作条+底栏元信息(全屏/编辑器打开/Finder/复制路径;大小·创建·修改) | app:707-746
- [ ] 选中文字→发到终端(带出处围栏+bracketed paste) | app:778-823
- [ ] HTML 交互预览(sandbox 隔离端口+定宽自动缩放+本地图兜底)——工程大,先 P2 | srv:2120-2143
- [ ] 全屏预览(Esc 退出;md 全屏仍可编辑) | app:909-919
- [ ] 终端多标签+dock 底/右切换+尺寸记忆+铺满 | app:2263-2295
- [ ] 标签标题跟真实 cwd(lsof 节流)+项目身份色+定位按钮 | app:2433-2458
- [ ] Claude/Codex 一键启动(空闲裸 shell 就地跑否则新标签) | app:2316-2343
- [ ] 进程退出→回车 respawn | app:2648-2654
- [ ] 会话回放(变更时间线压缩播放) | app:3255-3311
- [ ] 过程旁白(从输出尾提炼 ⏺ 工具行) | app:3515-3561
- [ ] 磁盘占用透视(du 条形榜可下钻) | app:1605-1634
- [ ] zip 中文名 GBK 兜底(直读中央目录 bit11) | srv:813-901
- [ ] 图片编辑器(标注/马赛克/撤销栈)——大件 | app:947-1124
- [ ] 项目记忆(agent 会话考古+续上) | app:1496-1548
- [ ] Agent 项目列表(扫 CC/Codex 日志列 30 天项目) | app:1769-1796
- [ ] 外部文件拖入落盘(同名存 foo 2.png) | app:486-502
- [ ] 即时 tooltip(data-tip 替原生 title) | app:825-833
- [ ] 首开引导 toast/欢迎卡 | app:1917-1935, 2253
- [ ] 状态持久化补全(视图/排序/终端尺寸等 localStorage) | app:3782-3823
- [ ] WebGL 渲染+context loss 自愈 | app:2485-2510
- [ ] 安全加固对齐(Host allowlist/Origin 校验/body 上限——helm 后端核对) | srv:1921-1941

## ~~wontfix~~ / 不搬(理由)

- ~~截图直通车~~ 系统截屏目录监听,electron-only,且 notch 伴侣更适合承担
- ~~窗口位置记忆/红绿灯控制/原生菜单/⌘Q 护栏/更新检测/剪贴板桥/代理旁路/拖窗区~~ electron 壳能力,helm 是 Web 前端+pywebview 规划,壳定型前不搬
- ~~发版向导/AI 整理~~ 与 helm 定位重叠存疑(helm 有自己的 agent 编排),待人拍板再议
- ~~Skills 透视/用量面板~~ helm 大脑模式已有自己的 Skills 透视;用量面板另属 F5 遥测流规划
- ~~三皮肤主题联动~~ helm 双主题已按 DESIGN.md 落地(Monaco/xterm 联动已部分做),不搬 FanBox 皮肤

## 进度

| 轮 | 条目 | commit |
|---|---|---|
| 1 | 建矩阵(本文件) | — |
| 2 | 预览即编辑+自动落盘+并发保护 | 6ebf159 |
| 3 | 终端路径点击+点开定位 | 7d1dab6 |
| 4 | 终端状态感知+完成提醒 | (见 git log 轮4) |
