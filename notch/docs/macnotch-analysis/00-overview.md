# MacNotch 复刻 · 总体分析与计划

> 目标:理解 `reference/macnotch/` 里的视频与图片,用 HTML 尽可能全地复刻 MacNotch 这个 macOS 刘海增强 app 的 UI/UX。
> 方法:整体分析 → 分模块顺序执行,每模块结果落盘到本目录,保证上下文被压缩后仍可续。

## 素材清单(reference/macnotch/)
- `dashboard.jpg`(3456×2234 静帧)— dashboard 展开态主图
- `dashboard.mp4`(140s, 3456×2160 @60fps)— dashboard 模块交互/动画
- `file-interactions.mp4`(68s, 3456×2234 @60fps)— 文件拖拽/暂存架(shelf)交互
- `notifications.mp4`(15.75s, 3456×2234 @120fps)— 刘海通知弹出

抽帧已落盘(每 2s 一帧,宽 900):
- `frames/dashboard/`(70 帧)`frames/file/`(34 帧)`frames/notif/`(8 帧)
- 动画细节不够可对原视频用 ffmpeg 加密抽帧(已装 /opt/homebrew/bin/ffmpeg)。

## 从 dashboard.jpg 已确认的设计
展开面板(从刘海下垂的大黑圆角面板,顶部贴菜单栏)结构:
- **顶栏**:左 `Dashboard` 标题 + `▦ Quick ›` 标签切换器;右一排工具图标(compose / 截图 / info / 下载)+ 网格图标;最右屏幕菜单栏(电量 84% / wifi / 时间 00:13 等)。
- **右侧竖向模式栏**:几枚小图标(grid / list / …)切换 dashboard 布局/页。
- **4 个 widget 列**:
  1. **Quick toggles**(⚙):6 枚开关图标(sparkle / 月亮暗色 / 搜索 / 网格 / 台灯 / 屏幕)。
  2. **Screen Time**(🕐)+ `⇄ 35 switches`:环形图 `10m Today` + 应用用时列表(Cursor 3m / Dia 2m / MacNotch 2m / Scroll Re… 0m,带彩色圆点)。
  3. **Launcher**(▦):一排彩色 app 图标(~6 个)。
  4. **Actions**(⚡):一排 app/动作图标(带角标 "1" 的盒子 / VSCode / App Store / 工具)。
- 视觉:纯黑面板、大圆角(底部 ~24-28)、白字、次要灰字、毛玻璃感弱、图标圆角方块。

## 模块拆分(各自落盘一份分析文档 + 一份 HTML 复刻)
| # | 模块 | 素材 | 分析文档 | HTML |
|---|---|---|---|---|
| M1 | Dashboard(展开面板 + 4 widget + 模式切换 + 顶栏) | dashboard.jpg/.mp4 | `10-dashboard.md` | `replica/dashboard.html` |
| M2 | File interactions(文件拖入/暂存架 shelf/拖出) | file-interactions.mp4 | `20-file.md` | `replica/file.html` |
| M3 | Notifications(刘海通知弹出/收起动画) | notifications.mp4 | `30-notifications.md` | `replica/notifications.html` |
| M4 | 折叠态 + 展开动画 + 整体外壳(贯穿三视频) | 全部 | `40-shell-motion.md` | 并入各 HTML |

## 执行顺序与续作约定
1. 本总览(00)落盘 ✓
2. 分模块:先由分析 agent 看帧→写 `1x/2x/3x-*.md`(含布局尺寸、组件、状态机、动画参数、配色、字体、交互)。
3. 我据各 md 写 `replica/*.html`(可交互优先,至少静态高保真)。
4. 每完成一模块,在本文件「进度」追加勾选 + 一句结论。

## 进度
- [x] 00 总览 + 抽帧
- [x] M1 Dashboard 分析 → `10-dashboard.md`
- [x] M2 File 分析 → `20-file.md`
- [x] M3 Notifications 分析 → `30-notifications.md`
- [x] M1 HTML 复刻 → `replica/dashboard.html`(4 widget + 切页 + Profiles + rail,可交互)
- [x] M2 HTML 复刻 → `replica/file.html`(Drop Actions 条 + Shelf 架 + 折叠持有,切状态)
- [x] M3 HTML 复刻 → `replica/notifications.html`(药丸→Reminder→交叉淡化 Media,完整动画)
- [x] 汇总索引页 `replica/index.html`

### 待打磨(下一轮可做)
- 折叠↔展开真实动画(三段素材均未拍到收回过程,现用推断的 spring/ease-out)
- Dashboard 其它 profile 的 widget 还原度(tasks/pomodoro/media 等为近似)
- file:拖入→入架的真实拖拽动画、多文件折叠堆叠、选中蓝态
- notif:多条堆叠、消息/系统类通知样式、hover 是否暂停
- 各模块像素/色值为目测,可在真机取色复测

## 配色/度量(初步,待各模块校正)
- 面板底:纯黑 `#000`,圆角底部 ~26px,顶部贴菜单栏。
- 文字:主 `#fff`,次 `~rgba(255,255,255,.5)`,弱 `~.3`。
- widget 标题:小号(~11px)半透明 + 前置图标。
- 强调/数据色:环形图与列表点用多彩(蓝/青/橙/绿)。
