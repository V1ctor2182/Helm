# MacNotch — Dashboard 模块分析(复刻向)

> 素材:`reference/macnotch/dashboard.jpg`(展开面板高清主图,3456×2234,2x retina)+ `frames/dashboard/f_001..f_070.jpg`(140s 视频每 2s 抽帧)+ 局部加密抽帧 `frames/dashboard/dense/`。
> 所有像素值均以 3456px 宽的 2x retina 截图为基准;括号内 pt 值 ≈ device px ÷ 2,供 CSS 使用。色值为目视估计。

---

## 0. 模块定位与全局结构

MacNotch 是一个"刘海(notch)悬浮面板"应用,**展开后是一条横贯刘海两侧的深色长条**。它有多个 **module(模式)**,通过面板右侧竖向 rail / 底部圆形 dock 切换:

- **Dashboard**(本文重点):可配置的"多页 widget 看板"。
- 其余 module 均为**整面板单一视图**(不是 dashboard 的一部分,只是同一 rail 可切到):Bluetooth 设备页、Notes、Now Playing/Media、Calendar/日期、Day Progress 时间轴、Messages、Pipelines(GitLab CI)、Actions、窗口平铺(tiling)等。本文只在"导航"一节简述,不展开。

**Dashboard 本体 = 顶栏(标题 + 页签 pill + chevron)+ 一行并排的 widget 列(卡片)+ 右侧模块 rail。** 它没有"网格多行",而是**单行、横向并排的 widget 列**,列数随页面配置变化(主图为 4 列)。

---

## 1. 整体面板度量

主图(Quick 页)实测:

| 项目 | device px | ≈ pt | 备注 |
|---|---|---|---|
| 面板总宽 | ~1840 (x≈820→2660) | ~920 | 横跨刘海两侧 |
| 面板总高 | ~178 (y≈8→186) | ~89 | 又宽又扁的一条 |
| 顶部圆角 | 0(贴屏幕顶边) | 0 | 顶边与屏幕上沿齐平 |
| 底部圆角 | ~26 | ~13 | 仅左下/右下圆角,外凸 |
| 顶栏高度 | ~80(y≈8→88) | ~40 | 标题行 |
| widget 区高度 | ~95(y≈90→185) | ~48 | 卡片内容 |
| 内边距(左/右) | ~28 | ~14 | 标题缩进 |
| 列间分隔 | ~1px 细竖线 `#2A2A2C` + ~32px 间隔 | | 每列之间一条暗灰竖线 |

- **背景**:近黑 `#0A0A0B`(略带半透明,可见后面壁纸极弱透出);整体不是纯黑,带一点点亮度。
- 面板像"实体药丸条",无明显边框,靠底部圆角与阴影和桌面分离。

> ⚠️ 帧序列(900px 缩放)里面板更窄、下方还浮着一排圆形 dock;主图(高清)无该 dock 只有右侧竖 rail。判断:dock 是录制态/交互态的模块切换器,主图是静态干净态。复刻以主图为准,dock 作为可选导航。

---

## 2. 顶栏(Top bar)

从左到右:

1. **"Dashboard"** — 标题,白色 `#FFFFFF`,粗体,字号约 30px device(~15pt),SF Rounded/SF Pro Bold 风格。
2. **页签 pill** — 紧贴标题右侧的深色圆角胶囊(bg `#1C1C1E`,圆角 ~14px,内边距 ~10×6)。内含:
   - 当前页**图标**(青绿/薄荷色 `#3DDCC0` 的 3 栏 grid 图标,表示"Quick"页的样式),
   - 页名文字(白色粗体,如 `Quick` / `Work` / `Simple` / `Personal` / `New P…`),
   - 右侧 **chevron `›`**(灰 `#8A8A8E`)。
3. 点击 pill / chevron → **切换/管理页面**(见 §4)。
4. 顶栏最右另有一组极小的系统图标(编辑/截图/info/下载等)和右侧模块 rail —— 属于面板 chrome,非 dashboard 内容。

每个 widget 列有自己的**列标题行**(在 widget 区顶部):小图标 + 标题文字(浅灰 `#C7C7CC`,~15px device / ~8pt,半粗)。

---

## 3. Widget 目录(已识别的卡片类型)

每个 widget 是一"列":顶部「图标 + 标题(+ 右侧附属信息)」,下方内容区。卡片本身**无背景框**(直接坐在面板底色上),靠竖分隔线区分列。内部小组件(toggle/icon)才有深色圆角底。

### 3.1 Quick toggles
- 标题图标:两个横向开关叠放的小图标;标题 `Quick toggles`。
- 内容:**一行圆角方块按钮**(tile bg `#262628`,圆角 ~14px,尺寸 ~46×46 device / ~23pt,间距 ~6)。
- 已识别图标(着色):✨ sparkles(薄荷绿)、🌙 月亮(蓝紫,勿扰)、📄+放大镜(琥珀,搜索)、▦ 4×4 网格(蓝,启动台/调度)、🎯 准星(琥珀)、🖥️ 显示器。
- 其中一个 tile 高亮(更亮底色)= 当前激活态。
- 行下方居中一个**小圆点**(分页指示器,说明 toggles 可翻页)。

### 3.2 Screen Time
- 标题:🕐 时钟图标 + `Screen Time`,**右侧** `⇄ 35 switches`(灰)。
- **环形图(donut)**:多色分段,中心叠 `10m`(白粗体)+ `Today`(灰小字)。分段色:主蓝 `#2F6BFF`、浅蓝 `#5AC8FA`、绿 `#34C759`、橙 `#FF9500`、深灰 `#48484A`。
- **右侧列表**:每行 = 彩色圆点 + app 图标(小圆角)+ app 名 + 时长(右对齐)。示例:`● Cursor 3m`(蓝)/`● Dia 2m`(浅蓝)/`● MacNotch 2m`(橙)/`● Scroll Re… 0m`(绿)。圆点色与 donut 分段对应。
- 时长文字白色,app 名白色,均 ~15px device。

### 3.3 Launcher
- 标题:▣ 2×2 网格图标 + `Launcher`;**hover 某图标时**,标题右侧出现该 app 名称标签(帧里见 `Discord`/`Journal`/`Cursor` 等动态变化)→ 图标有 hover 名称提示。
- 内容:**一行 app 图标**,每个图标坐在深色圆角方 tile(`#1A1A1C`,圆角 ~16px)上,**tile 之间轻微重叠/堆叠**(有层叠投影感)。图标本体 ~52px device / ~26pt。
- 主图所见:Finder(粉白)、Discord、Logic/音乐(绿波形)、蓝文件夹×2、音乐 app。
- 下方居中分页小圆点。

### 3.4 Actions
- 标题:⚡ 闪电图标 + `Actions`。
- 内容:**一行更大的 app 图标 tile**(比 Launcher 略大、**不重叠**、间距更宽)。tile bg `#1C1C1E`,圆角 ~18px。
- 主图所见:Unity(深灰,右上角**红色数字徽标 `1`**=待处理动作计数)、VS Code、App Store、Xcode。
- 下方居中分页小圆点。
- 在"Actions"作为独立 module 全屏时(f_005):标题 `ACTIONS`,展示某 app(Cursor)的动作列表,如 `Run Debug`、提示文案"F-key shortcut not working? Hold Fn…",右侧带 `⌘ … FS` 快捷键标注 —— 说明 Actions widget 点击会进入该 app 的动作面板。

### 3.5 其它页出现的 widget(来自 Work / Simple / Personal 页)
- **Tasks / Reminders**:列表行(彩色圆点 + 任务名 + 时间),如 `Team standup 09:00–09:30`、`Product review 11:00–12:00`。
- **Pomodoro**:大号计时 `25:00`,状态 `Paused`,下方 ◀ ▶ 控制按钮(圆形)。
- **Day Progress**:`Starts in` + 大号 `7h 29m`(白粗)+ 一句鼓励语(`— Stay hydrated —`,灰)。作为独立 module 时是带时间轴的整页(f_035:Today 进度条 `1 of 11 done 9%`、Events/Reminders/Tasks/Bedtime 计数、时间轴卡片 + `Add Task`)。
- **Media / Now Playing**:左方专辑封面缩略 + 曲名(`WALK`)+ 艺人(`Hulvey & Lecrae`)+ ◀◀ ⏸ ▶▶。
- **Calendar / 日期卡**:`WEDNESDAY / 13 May`、时钟 `01:31 Mainz`、天气 `9°C Cloudy H:15° L:8°`、`Today · 4 events`。
- **Quote**:大字引言 + 署名(`Never give in. — Winston Churchill`)。
- **AirPods / 电池**:设备名 `AirPods Pro` + 三段电量条(L 85% / case 100% / R 90%)+ ◀ ▶ 切换其它蓝牙设备。

> 即:widget 是一个**可拼装的组件库**,不同页(profile)挑选不同组合并横向排布。

---

## 4. 页面 / Profiles(标签系统)

Dashboard 是**多页**的,顶栏 pill 即当前页:

- 已见页名:`Quick`、`Work`、`Simple`、`Personal`、`New P…`(新建空页)。
- **chevron `›`** = 顺序切到下一页(帧里页名随之循环变化)。
- **点击 pill** → 弹出 **Profiles 选择条**(f_013 / f_016):一条横向胶囊列表,左侧标签 `Profiles`,后面是各 profile chip(带图标 + 名,如 `Work`🧳 / `Personal`👤 / `Focus`🎯 / `Productivity`📊 / `Siri`),被选中 chip 高亮,chip 上带 `×` 删除,末尾 `+` 新增。
- **每页 = 一套 widget 组合**(列数与内容不同)。Quick=4 列(toggles/ScreenTime/Launcher/Actions);Work=tasks/Launcher/Pomodoro/DayProgress;Simple=Media/DayProgress/Quote;Personal=日期卡/AirPods/Media。
- **空页(`New P…`)状态**(f_017):整面板居中显示:左侧大号 ▦ grid 图标 + `No widgets yet`(白粗)/ `Add widgets from Settings to get started`(灰),右侧白色胶囊按钮 **`Add Widgets`**,下方灰小字 `Open Settings to add widgets`。→ widget 在"设置"里添加。

---

## 5. 模块导航(rail / dock)

切换 Dashboard ↔ 其它 module 的入口,有两种呈现:

- **右侧竖向 rail(主图,面板内右缘)**:从上到下小图标,顶部 ▦ 2×2 网格(=Dashboard,当前高亮)、AirPods、日历/数字键盘、✓ 清单(checklist)等。每个 ~24px device,纵向堆叠。
- **底部浮动圆形 dock(帧序列)**:面板下方居中 5 个深色圆按钮(`#1C1C1E`,~直径 36px):▦ 网格、📅 日历、▤ 列表/任务、📅 日历、⏱ 计时。点击进入对应整页 module。

主图与帧两套 chrome 不一致 —— 复刻时 Dashboard 自身只需还原"顶栏 + widget 列",导航 rail 可按主图右缘竖排实现。

---

## 6. 交互与状态

- **页切换**:chevron 单击循环;pill 单击展开 Profiles 条选择;profile chip 可删/增。
- **Launcher hover**:鼠标移到某图标,列标题旁出现 app 名标签(f_011 Discord / f_013 Journal / open_012 …);点击应启动该 app。
- **Actions**:图标可带计数徽标(红 `1`);点击进入该 app 的动作列表页(f_005)。
- **Quick toggles**:tile 高亮表示开/关态;行下分页点表示可翻页。
- **各内容 widget 可点进对应 module**:Media→Now Playing 全屏;DayProgress→时间轴全屏;AirPods→蓝牙设备页;Screen Time list 可点 app。
- **分页点**:Quick toggles / Launcher / Actions 三列下方各有一个居中小圆点,暗示横向分页(每列可滑动翻页)。

---

## 7. 动画

- **展开/折叠**:本 140s 视频**起始即已展开**(f_001/open_001 在 t=0 已是完整面板),片段内**未捕捉到 collapse→expand 过程**。仅能从机制推断:刘海条由折叠态向左右 + 向下"长出"成长条(典型 notch 应用为弹性 spring + 高度/宽度同时扩张)。具体时长/缓动**未知**(见 §9)。
- **页切换**:切页时 widget 列做横向滑入/淡入替换(帧里相邻状态卡片整组更换,推测短促 ~0.2–0.3s 横移 + 透明度)。
- **module 切换**:整面板内容交叉淡入淡出 + 高度自适应(不同 module 面板高度不同,有平滑高度过渡)。
- **hover/翻页**:微交互(tile 高亮、标签出现),应为 ~0.1–0.15s 快速过渡。

> 精确时长/缓动需对原视频做更细抽帧或查实现;当前以"短促弹性"为安全默认。

---

## 8. 配色与字体小结(复刻速查)

| 用途 | 估值 |
|---|---|
| 面板背景 | `#0A0A0B`(略透明) |
| widget 内部 tile | `#1A1A1C` ~ `#262628` |
| 列分隔竖线 | `#2A2A2C`,1px |
| 文字一级(标题/数值) | `#FFFFFF` |
| 文字二级(列标题/app 名) | `#C7C7CC` |
| 文字三级(副标/单位/提示) | `#8A8A8E` / `#6A6A70` |
| 强调/激活(当前页图标) | 薄荷青 `#3DDCC0` |
| Screen Time 配色 | 蓝 `#2F6BFF` · 浅蓝 `#5AC8FA` · 绿 `#34C759` · 橙 `#FF9500` · 灰 `#48484A` |
| Actions 徽标 | 红 `#FF3B30` |
| 图标 tile 圆角 | toggles ~14px / launcher ~16px / actions ~18px(device) |

字号层级(device px,≈ pt = ÷2):
- 面板大标题 "Dashboard":~30 / ~15,Bold。
- 大数值(`10m`/`25:00`/`7h 29m`):~26–34 / ~13–17,Bold。
- 列标题:~15–16 / ~8,Semibold,浅灰。
- 列表正文(app 名/时长):~15 / ~8。
- 副标/提示:~12–13 / ~6,灰。

字体均为 **SF Pro / SF Pro Rounded** 系(macOS 系统字),数字偏圆润粗体。

---

## 9. 不确定 / 没看清的点

1. **折叠↔展开动画**:本片段起始即展开,未捕捉到收起/弹出过程,时长与缓动曲线纯属推断。
2. **主图 vs 帧两套导航 chrome 不一致**:主图只有右侧竖 rail,帧序列额外有底部 5 圆 dock —— 哪个是最终态、dock 是否 hover 触发,未确认。
3. **底部 dock 5 个圆按钮的确切含义**:图标小,第 3/5 个(列表/计时)推测,未逐一验证对应 module。
4. **右侧竖 rail 图标全集**:仅看清前 4 个(grid/AirPods/日历/清单),下方是否还有更多未确认。
5. **Quick toggles 完整图标集与各自功能**:第 5/6 个(准星/显示器)语义未确认;tile 高亮到底是"开"还是"选中焦点"未定。
6. **widget 是否可在面板内拖拽排序 / resize**:只看到"设置里添加",面板内编辑能力未见。
7. **每列分页(小圆点)滑动方向与每页项数**:仅见单点,未见多点或翻页动作。
8. **页面数量上限 / Profiles 全集**:见到 Quick/Work/Simple/Personal/Focus/Productivity/Siri/New 等,是否还有更多、是否用户全自定义,未确认。
9. **精确像素**:所有尺寸来自 2x 截图目测换算,误差 ±2–4px;色值为目视取色,非吸管精确值。
10. **面板宽度是否随内容(列数)动态变化**:不同页列数不同,推测宽度自适应,但未直接对比测量。
