# Notch 对齐 Loop · 循环流程(每轮:把 HTML 设计的一块,做进 Swift App 到一模一样)

> 这条 loop 的本体:**`helm-notch-pro.html` 是锁定的最终设计稿(只读、唯一真相);把它的 UI 一块一块"原样"实现进原生 Swift notch App,直到 Swift App 和 HTML 看起来/用起来一模一样。**
> 启动命令见 [`notch-loop-prompt.md`](./notch-loop-prompt.md)。这是**真实里程碑开发**(notch-panel room),仿 [`docs/loop-procedure.md`](../../docs/loop-procedure.md) 但聚焦"对齐设计"。

> **🎯 范围(唯一目标):把 Swift 前端做到和 `helm-notch-pro.html` 一模一样(布局/色/字号/间距/尺寸/动画/交互)。后端数据接入不在范围内——**
> - 数据一律用**和 HTML 同款的种子 / mock**(HTML 里写死什么值就照搬什么值:PORTS、PRS、CLIP、HEAT、SPARK、LYRICS、RECENT、EVENTS 等)。已有真实数据源(连接状态 / 本机 agent hook / 日历 events / 媒体)照用,但**不为「接某个后端端口」而停留、阻塞、或去猜后端接口**。
> - 真实数据源没有 / 要后端加端口的(api-focus、文件上传、问大脑通道、真实 diff、真实 PR/端口/剪贴板/歌词/per-day 事件…)→ **留 TODO + 用 HTML 同款 mock 顶上**,继续对齐视觉。**绝不为它们停下或去改后端。**
> - 判断一块"对齐完"只看**视觉/交互和 HTML 一不一样**,不看数据真不真。

> **🌙 夜间模式(可选,完全自主):** 启动命令带【夜间模式】时,下面流程里每一处「停下 review / 问你 / add_question 等人」都改成「**做最忠于 HTML 的暂定实现 + `record_decision`/`add_question` 记下来 + 留 TODO + 继续**」;每块自检过(`swift build`+`test` 全绿)就**自己 commit + push 到 `feat/notch-*` 分支**(仍**不合 main、不改 HTML**),整夜不停。硬门(build/test 绿)与"不可逆操作不猜"不松;只有"全部对齐完 / 全卡住"才停。详见 [`notch-loop-prompt.md`](./notch-loop-prompt.md) 的「🌙 夜间模式」段。
> **夜间模式唯一不省的是「report」:** 每轮照常产出「每轮 report」(见下「每一轮」第 8 步)——夜间只是**不等你批准**,但**每一块都要写 report**(消息里给一份 + 记进 `refs/log.md`),让你早上一路回看每轮做了什么。

## 两个文件,别搞反

- **设计基线(只读,唯一真相)**:[`notch/docs/helm-notch-pro.html`](./helm-notch-pro.html) —— 最终设计稿。**loop 绝不改它**,只把它当规范来读、来对照、来截图当视觉靶。
- **目标(要改的)**:原生 Swift notch App ——
  - `notch/Sources/HelmNotchApp/NotchView.swift`(SwiftUI,刘海 UI 本体)、`NotchController.swift`/`NotchPanel.swift`(窗口/尺寸)、`Color+Theme.swift`(主题)、`SettingsView.swift`。
  - `notch/Sources/HelmNotchCore/NotchModel.swift`(状态机,≈ HTML 的 `S`)、`Theme.swift`(每日 accent palette)、`Models.swift`/`Media.swift`/`HelmBackend.swift`/`LocalSession.swift`。

> **目标 = Swift App 和 `helm-notch-pro.html` 一模一样**:布局、模块、配色(每日 accent)、字号层级、间距、手势、动画、尺寸——逐项对齐,**不是"差不多"**。

## 现状(2026-07-01:骨架已对齐,进入保真打磨)

Swift `NotchView` 已从旧 2×2 迁到 HTML 的 **dock + 单模块** 设计,主体结构/状态/交互都已落地:折叠条、dock 切 5 模块(dashboard/速记/calendar/dev/clipboard)+ media 全屏、Dev 四子页(agents/ports/reviews/stats,纵向分页)、日历周⇄月+议程、深色设置 modal、等权限/日程提醒两 banner、专注计时、速记 5-kind(含 self-agent/时间地点/最近/拖文件)、滑动手势、per-view 自适应高度、方向性滑入动画。
loop 现在的活 = **逐块核对「一模一样」并补齐差的细节**:对着 HTML 一处处比像素/色/字号/间距/动画/尺寸,哪不一样就修哪;还没端口的小细节(如某个动画曲线、某处 hover 态、某个 SVG 字形的确切形状)也算块。数据一律用 HTML 同款 mock(见上「范围」),别去接后端。

---

## 从 HTML 要"原样"复刻什么(对照清单)

读 HTML 时,这些都要 1:1 搬进 Swift(具体值以 HTML 源码为准,别约,**精确读取**):

- **每日 accent**:`palette[]` 那 10 个色 + `dayIndex%10` 确定性推导;Swift 的 `Theme.swift` 要有同一套色和同样算法。accent 只用于 HTML 里用到的那几处(艺术家行/进度条/今日/选中胶囊/发送钮/折叠态波形)。状态色固定(绿/橙/红)。
- **折叠条**:左媒体(封面+均衡器+曲名)/ 右状态字形(✻运行/琥珀等权限/今日下个日程),中间留摄像头宽。
- **模块系统**:`MODULES`(dash/cap/cal/dev/clip/focus…)+ 底部 dock + 当前态高亮 + badge。
- **各 view**:`V.dash` bento、`V.media` 歌词放大、`V.cap`、`V.cal`(周条⇄整月+议程)、`V.dev`(子页+右轨)、`V.clip`、`V.focus`——逐个对齐。
- **手势/动画**:左右滑切模块(`slideTo`/`switchModule`)、Dev 内上下分页(`switchDev`/`slideDev`)、`cubic-bezier(.32,.72,0,1)` 缓动、展开/收起过渡。
- **尺寸**:每个 view 的自适应高度(`viewHeight()`/`VH`/`DEVSECS[].h`)→ Swift 里对应每态的 panel size(`NotchController` 调窗口尺寸)。
- **图标**:HTML 用单色字形/SVG,**禁 emoji**(全局硬规则)——Swift 里同样单色 SF Symbols / 字形。

---

## VibeHub(主要是 context 的记录)

刘海归 **notch-panel** room:`feature_id = a1ba5dd6-633c-4a30-834d-910d0c902e16`(本文件记为 `NOTCH_ROOM`)。
**在这条 loop 里 VibeHub 主要干一件事:把对齐过程的 context 记下来**——每对齐一块,就把「做了什么、对应 HTML 哪块、为什么这么实现、关键取舍」记进 room,让后面的人 / agent 不用重读代码就懂来龙去脉。它是**共享上下文层,不是审批关卡**。

**记 context(主——每块实现后,绑 `NOTCH_ROOM`)**
- `record_decision` — **主力**:这块怎么从 HTML 映射进 Swift、为什么这么实现(SwiftUI 表达 / 取舍 / 和 HTML 的对应)。title 一句话,rationale 写够让人懂。
- `add_constraint` — 记下发现的硬边界(如「Swift accent 必须复用 Theme 的每日推导」「禁 emoji」),当长期 context 留着。
- `add_question` — 记下开放问题(HTML 某点原生难 1:1 / 有更原生做法),留给人定,别擅自偏离设计。
- 都落成 `ai_proposed` 供人在 dashboard 过目;log 的「VibeHub」行记 title + id。

**拉 context(辅——开工前对齐已有方向)**
- `get_feature_context(NOTCH_ROOM)` — 已拍板方向(每日 accent 调色板、accent 用法、原生 Swift 路线、各 milestone 决策),别和它冲突。
- `get_file_context(<要改的 Swift 文件>)` / `get_team_conventions`(如禁 emoji) / 拿不准来龙去脉 `query_why(spec_id)`。

---

## 验证门(原生:构建测试 = 硬门;一模一样 = 视觉比对)

1. **硬门**:`swift build` 通过 + `swift test` 全绿(改了 Core/Model 必跑)。**未过不得继续 → 修或熔断。**
2. **视觉对齐**:把 HTML 对应 view 用 browse 截成**靶图**(附录 A),Swift 实现对着靶图写;能跑起来就 `screencapture` 实际刘海和靶图比对,逐项核(布局/色/字号/间距/尺寸)。
   - 自动截真机刘海较难(见附录 A);做不到就在 batch review 把**靶图 + 已实现说明**贴给用户,**由用户跑 .app 目视确认「一模一样」**。
- 不一致就修,最多 3 轮;3 轮仍差很多 → 停下问。

## step 0(每次启动自检)

1. **读本流程**(本文件,仔细读)。
2. **通读设计基线**:把 [`helm-notch-pro.html`](./helm-notch-pro.html) 从头到尾读懂(CSS + `S` + `V.*` + 手势 + `palette`)——这是要对齐的**唯一真相**。
3. **读现状**:读当前 Swift `NotchView.swift`/`NotchModel.swift`/`Theme.swift` 等,搞清现在做到哪、和 HTML 差什么。
4. **拉 VibeHub context**(见「VibeHub」节)。
5. **分支**:在 `feat/notch-*` 上,**不在 main 直接改**。
6. **工具就绪**:`swift build` 能跑;browse 的 `$B`(附录 A)能截 HTML 靶图。

## 每一轮(= 对齐一个模块 / 一个方面)

1. **选一块**:从 HTML 里挑**一个还没对齐**的模块或方面(如「折叠条」「dock + 切模块」「media 歌词放大」「Dev 分页+右轨」「日历周/月」「每日 accent 主题」),按依赖排序(基础设施先:主题/状态机/dock 骨架 → 再各 view)。**别和 log 里已对齐的重复。**
2. **精读 HTML 该块**:布局结构、确切尺寸/间距/字号/色、交互与动画、对应的 `S` 字段——记下要复刻的精确值。
3. **对齐 VibeHub**:别和已拍板冲突;HTML 某点原生难 1:1 → `query_why` / `add_question`,别擅自改设计。
4. **实现进 Swift**:在对应文件里把这块做到**和 HTML 一模一样**(SwiftUI 复刻布局/色/动画;`NotchModel` 补对应 state;`NotchController` 调尺寸)。贴合现有 Swift 写法。
5. **硬门**:`swift build` + `swift test` 全绿。
6. **视觉自检**:browse 截 HTML 该 view 当靶图 → 对比(能跑就 screencapture 真机,否则留给 review)。逐项核到一致,≤3 轮。
7. **记 context(VibeHub)+ log**:把这块的 context 记进 `NOTCH_ROOM`(`record_decision` 为主,必要时 `add_constraint`/`add_question`);往 `refs/log.md` 追加一条(附录 C)。
8. **每轮 report(硬性,夜间也不省)**:每对齐完一块(commit + push 后)**必出一份该轮 report**——见下「每轮 report」节。**没出 report ≠ 这块完成。**
9. **计数 +1**。到 N 块 或 全部对齐完 → **批次停顿**。

## 每轮 report(每一轮都要,夜间照出)

每轮收尾**必须**给一份简明 report,内容固定这几项(照抄 log 那条即可,别另编):

- **第几轮 / 块名**(如「第 12 轮 · 日程提醒 banner」)。
- **对齐了 HTML 哪块** + **Swift 改了哪些文件/组件**。
- **关键取舍**(哪里没 1:1、为什么;有无 TODO / `add_question`)。
- **硬门结果**:`swift build` ✓ / `swift test` 第几测全绿(具体数)。
- **VibeHub**:`record_decision`/`add_question` 的 title + id。
- **视觉门**:靶图对比一致 / **待用户实机目视**(注明真机没截到)。
- **commit**:已 push 到哪个 `feat/notch-*`(**未合 main**)。
- **❓需确认**:本轮任何 [needs-human]。

**呈现两处,缺一不可**:① 作为**本轮结束消息**发给用户(即使夜间无人,也输出,早上可回看);② 已随第 7 步记进 `refs/log.md`(持久化,可整夜回溯)。两者内容一致即可。**日间**:report 就是「批次停顿」里贴给用户的那份;**夜间**:report 照出,只是不等批准、直接进下一块。

## 批次停顿(默认每对齐 1 块就停——原生块大,一个一停最稳)

停下给 review:
- **逐块**:HTML 靶图 + (能截就)Swift 实际截图 + 一句话「对齐了哪块 + 关键实现取舍」+ 任何「❓需确认」。
- 工作树**未 commit**。等用户:OK → commit(notch 不用 `--auto`,见硬规则);给修正 → 改到一模一样再 commit。

## 硬规则 / 熔断

- **绝不改 `helm-notch-pro.html`**(它是只读设计基线)。只改 Swift App。
- **不自动 commit**;commit 在用户 review 通过后。
- **notch PR 不用 `--auto`**:等 macOS swift CI job 绿再手动合(已拍板,见 VibeHub / `helm-ci-no-branch-protection`)。
- `swift build`/`swift test` 非全绿 **绝不算这块完成**。
- HTML 某设计原生无法/不宜 1:1 → `add_question` 等人,**别擅自偏离设计**。
- 3 轮仍对不齐 → 停下问。全部对齐完 → 报告并停。

---

## 附录 A:构建 / 测试 / 截靶图

```bash
# 硬门:构建 + 测试(在 notch/ 下)
cd notch && swift build && swift test

# HTML 靶图(设计基线对应 view)
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B="$_ROOT/.claude/skills/gstack/browse/dist/browse"; [ -x "$B" ] || B="$HOME/.claude/skills/gstack/browse/dist/browse"
$B goto "file://$_ROOT/notch/docs/helm-notch-pro.html"
$B js "S.open=true;S.view='media';render();'ok'"      # 切到要对齐的 view/子态
$B screenshot /tmp/target.png --selector '#notch'      # 用 Read 看 /tmp/target.png = 靶
```

**跑 Swift App 截真机刘海(best-effort,需 macOS GUI 会话)**:
```bash
open "notch/Helm Notch.app"
# 刘海在屏幕顶部中央,展开后向下;用 screencapture 截那块区域:
# screencapture -x -R<x>,<y>,<w>,<h> /tmp/actual.png   (区域按实际屏幕调)
```
> 自动驱动 App 切到每个 view 再截,目前没有 hook——做不到就把靶图 + 实现说明交给用户,由用户跑 .app 目视确认「一模一样」。

## 附录 B:HTML(设计) → Swift(目标)映射

| HTML(`helm-notch-pro.html`) | Swift(要做成一样的地方) |
|---|---|
| 状态机 `S` + `render()` | `HelmNotchCore/NotchModel.swift` + `NotchView.body` |
| `palette[]` 每日 accent 推导 | `HelmNotchCore/Theme.swift` + `App/Color+Theme.swift` |
| 折叠条 `renderBar()`/`#bar` | `NotchView` 折叠态(`shell` collapsed / `collapsedArt`) |
| 展开 + 底部 dock 切模块 | `NotchView` 展开态 + **新增 dock 组件 + 切 view 逻辑** |
| `V.dash` bento | `NotchView` dashboard(替换旧 2×2 `cell{}`) |
| `V.media` 歌词放大 | `NotchView` media + `HelmNotchCore/Media.swift` |
| `V.cap` 速记 | `captureCell` → 新 capture view |
| `V.cal` 周/月+议程 | calendar view + `HelmBackend` 日历 |
| `V.dev` 子页+右轨 | agents/dev view + `LocalSession` |
| 手势 `slideTo`/`switchDev` | `NotchView` 手势(**新增** drag/scroll 切换) |
| `viewHeight()`/`VH` 各态高度 | `NotchController.swift` 调 panel 尺寸 |

## 附录 C:log 条目格式

```markdown
## YYYY-MM-DD HH:MM · <slug>
- 对齐: <这轮把 HTML 哪一块做进了 Swift>
- HTML 基线: <V.xxx / 折叠条 / 主题 …>(只读对照,未改)
- Swift 改动: <文件 + 关键组件/函数>
- 取舍: <SwiftUI 怎么复刻 / 哪里原生表达不同但视觉一致 / 有无 add_question>
- VibeHub: record_decision「…」→ <id> (ai_proposed);add_constraint/add_question「…」→ <id>(没调用写"无")
- 验证: swift build ✓ / swift test <N 通过>;视觉:靶图对比 <一致 / 待用户目视>
- 状态: ✅ 待 review  |  ❓需确认: <…>
```
