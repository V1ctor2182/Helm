# Helm 主工作台 对齐 Loop · 循环流程(每轮:把设计稿的一块,做进 Svelte 前端到一模一样)

> 这条 loop 的本体:**`docs/design/helm-pro.html` 是锁定的最终设计稿(只读、唯一真相),配合 `DESIGN.md`(token/规则);把它的 UI 一块一块"原样"实现进 Svelte 前端,直到跑起来的 Helm 和 helm-pro.html 看起来/用起来一模一样。**
> 启动命令见 [`helm-loop-prompt.md`](./helm-loop-prompt.md)。这是**真实开发**(F8 workspace-layout room),仿 notch 的 [`notch-loop-procedure.md`](../../notch/docs/notch-loop-procedure.md) 但目标从 Swift 换成 **Svelte 前端**。

> **两阶段。本 loop 分两个阶段:**
> - **阶段 1 · 前端外壳保真(已完成,合入 main):** 把 Svelte 前端外壳(Shell + Today + 双主题 + 细丝 Rail + 状态栏 + ORAGE chrome + ⌘K/⌘N)做到和 `helm-pro.html` 一模一样。
> - **阶段 2 · 逐模块完善,让所有功能真能用(当前):** 一个模块一个模块地把各模式(Chat / 驾驶舱 / 研究 / 记忆 / 记录 / 日历 / 邮件 / 设置)从占位做成端到端可用——设计视图(helm-pro 没画,按 `DESIGN.md` 系统新设计)→ 建 Svelte UI → 接真后端 `/api` → 功能真能跑通,并守 notch 契约。详见下方「阶段 2」大节。

> **🎯 阶段 1 范围(唯一目标):把 Svelte 前端做到和 `helm-pro.html` 一模一样。后端数据接入不在阶段 1 范围内——**
> - 数据一律用**和设计稿同款的 mock**(helm-pro.html 里写死什么就照搬:tasks、journal、agents、projects、mail、SESSION/MODEL/TOKENS 遥测值等)。已有真实数据源(后端 `/api`、本机 agent hook)照用,但**不为「接某个后端端口」而停留、阻塞、或去猜后端接口**。
> - 真实数据源没有 / 要后端加端口的(真实任务/日记/agent 流/邮件分诊/项目列表…)→ **留 TODO + 用同款 mock 顶上**,继续对齐视觉。**阶段 1 绝不为它们停下或去改后端**(留给阶段 2)。
> - 判断阶段 1 一块"对齐完"只看**视觉/交互和 helm-pro.html 一不一样**,不看数据真不真。

> **🌙 夜间模式(可选,完全自主):** 启动命令带【夜间模式】时,下面流程里每一处「停下 review / 问你 / add_question 等人」都改成「**做最忠于设计稿的暂定实现 + `record_decision`/`add_question` 记下来 + 留 TODO + 继续**」;每块自检过(`build`+`check`+`test` 全绿)就**自己 commit + push 到 `feat/design-*` 分支**(仍**不合 main、不改设计稿**),整夜不停。硬门(build/check/test 绿)与"不可逆操作不猜"不松;只有"全部对齐完 / 全卡住"才停。详见 [`helm-loop-prompt.md`](./helm-loop-prompt.md) 的「🌙 夜间模式」段。
> **夜间模式唯一不省的是「report」:** 每轮照常产出「每轮 report」(见下「每一轮」第 8 步)——夜间只是**不等你批准**,但**每一块都要写 report**(消息里给一份 + 记进 `helm-loop-log.md`),让你早上一路回看每轮做了什么。

## 给 agent 的判断空间(别把下面当死规定)

这套流程是**脚手架,不是紧身衣**。**硬的就那几条**(见「硬规则/熔断」):设计稿只读、gates 全绿、禁 emoji、不改坏 notch 契约、先分支不自动 commit、不可逆操作先问——这些是底线,别碰。
**其余都留给你判断**:块怎么切、先做哪块(下面写的顺序是**建议不是命令**)、一轮做多大、某处在 Svelte 里怎么表达最顺、要不要把相邻两块并一轮——用你的工程判断和品味定。
设计稿是**视觉真相**;但若某处明显有更 Svelte-native / 更合理的做法(而非死抠像素),**提出来**(`add_question` 或 report 里说一句)比闷头照抄更好。拿不准的记进 `add_question` 继续走,别卡住。

## 两个文件,别搞反

- **设计基线(只读,唯一真相)**:
  - [`docs/design/helm-pro.html`](./helm-pro.html) —— 最终设计稿(source of truth)。**loop 绝不改它**,只当规范来读、来对照、来截图当视觉靶。
  - [`../../DESIGN.md`](../../DESIGN.md) —— 双主题精确 token + 字体/间距/动效/ORAGE chrome 规则 + 决策日志。**也是只读基线**,精确值以它 + helm-pro.html 源码为准。
- **目标(要改的)**:Svelte 前端(`frontend/`)——
  - `frontend/src/app.css`(全局设计 token:双主题 CSS 变量、字体栈、reset)。
  - `frontend/src/lib/Shell.svelte`(外壳网格:titlebar / rail / context / center / terminal / statusbar)。
  - `frontend/src/lib/Rail.svelte`(细丝 Rail:1px accent 活线 + 锚点滑移 + agent 脉冲 + 单色 SVG 图标)。
  - `frontend/src/lib/Today.svelte`(Today 仪表读数:左槽 mono + 发丝行 + 任务/日记/agent 框选视口/项目/邮件/快速动作)。
  - 主题 / accent:新增 theme store(`dark`/`light`/跟随系统)+ 每日 accent 推导(palette + 对比度压暗),供全局 CSS 变量。
  - 后续按需:各模式组件(Chat/Research/Memory/Journal/Mail/Cockpit)、命令面板(⌘K)、速记(⌘N)。

> **目标 = 跑起来的 Helm 前端和 `helm-pro.html` 一模一样**:布局、模块、双主题、配色(每日 accent)、字号层级、间距、手势、动画、ORAGE chrome(点阵/fiducial/坐标/框选视口/CLI 面包屑)——逐项对齐,**不是"差不多"**。

## 现状(2026-07-02:零设计线框,起步对齐)

Svelte 前端已有**功能骨架**但**设计几乎为零**:`Shell.svelte` 是默认浅色线框(`#fafafa` 底 / `#222` 字 / `#e5e4e7` 边框 / 灰按钮),四栏网格(rail｜context｜center｜terminal)+ statusbar 结构在;`Rail.svelte`/`Today.svelte` 存在但未上妆;`app.css` 近乎空(仅 reset)。
loop 现在的活 = **从零把 helm-pro.html 的设计逐块做进这套骨架**:先落设计 token(双主题)→ 外壳 → 细丝 Rail → Today 读数 → context/遥测 → 状态栏 → ORAGE chrome。数据一律用设计稿同款 mock(见上「范围」),别去接后端。

---

## 从设计稿要"原样"复刻什么(对照清单)

读 `helm-pro.html` + `DESIGN.md` 时,这些都要 1:1 搬进 Svelte(具体值以源码/DESIGN.md 为准,别约,**精确读取**):

- **双主题 token**:`[data-theme="dark"]` / `[data-theme="light"]` 两套 CSS 变量(--bg/--chrome/--panel/--t1..t4/--line/--hair/--tile/--acc/--acc-ink/--grid + 语义色),精确 hex 见 DESIGN.md。默认跟随系统(`prefers-color-scheme`)。
- **每日 accent**:palette 10 色 `["#FB9E66","#FF6F61","#FFC53D","#B6E84F","#34D6C0","#4FD6E8","#5EA0FF","#7C9CFF","#B98CFF","#FF6FA5"]`,当天种子取一色;浅主题按对比度规则压暗(×~0.5 至对比≥3.2)。只用在设计稿用到的那几处(细丝/状态栏 live 点/Today 日期/活跃态/框选 L 角/checkbox 完成/主 CTA 边)。语义色配给制固定。
- **外壳网格**:`58px 250px 1fr 40px` × `32px 1fr 26px`(rail｜context｜center｜terminal-edge｜statusbar)。固定尺寸,不做流体稀汤。
- **细丝 Rail**:内缘 1px accent 活线 + 激活段锚点(滑移 .42s)+ agent 脉冲光点(向上 .7s)+ 单色 SVG 图标(Today/Chat/Research/Memory/Journal/Mail/Cockpit/Settings)+ Mail badge。**禁 emoji**。
- **Today 读数**:左槽 60px mono 时间戳/section tag + 发丝横线;任务(checkbox+due)、日记(caret+AI 小结)、Agent 框选视口(旋转 ✻ + 状态点)、最近项目、邮件(红点+紧急)、快速动作。**零阴影零圆角零填充卡片**。
- **context 面板**:当前项目块 + Today 导航 + 会话遥测块(SESSION/MODEL/TOKENS/AGENTS/RAG/UPTIME)+ 坐标 chip + 「● LOCAL · NO CLOUD」角标。
- **状态栏(CLI 面包屑 HUD)**:分段 `● ~/helm ⎇ feat/notch ↑2 · tok 14.2k · 60ms · RAG idle … NEXT 001/009`,tabular-nums,最左 accent 点。
- **ORAGE chrome**:点阵底纹、散落十字准星 fiducial、坐标 chip、框选视口(frame+琥珀 L 角)、CLI 面包屑;强度可切(强/弱,日常默认偏弱)。
- **动效**:一条缓动 `cubic-bezier(.32,.72,0,1)`;micro 120 / 面板 220 / 细丝滑移 420 / 每日点火 600 / agent 脉冲 700 (ms)。尊重 `prefers-reduced-motion`。
- **图标**:单色 SVG / 等宽字形,**禁 emoji**(全局硬规则)。

---

## VibeHub(主要是 context 的记录)

主工作台归 **F8 workspace-layout** room:`feature_id = 93159be4-d502-456f-8735-a06394093759`(本文件记为 `HELM_ROOM`)。
**在这条 loop 里 VibeHub 主要干一件事:把对齐过程的 context 记下来**——每对齐一块,就把「做了什么、对应设计稿哪块、为什么这么实现、关键取舍」记进 room,让后面的人 / agent 不用重读代码就懂来龙去脉。它是**共享上下文层,不是审批关卡**。

**记 context(主——每块实现后,绑 `HELM_ROOM`)**
- `record_decision` — **主力**:这块怎么从设计稿映射进 Svelte、为什么这么实现(组件划分 / 取舍 / 和设计稿的对应)。title 一句话,rationale 写够让人懂。
- `add_constraint` — 记下硬边界(如「accent 必须走 theme store 的每日推导」「禁 emoji」「设计 token 只从 app.css 变量取,组件里不写死 hex」),当长期 context 留着。
- `add_question` — 记下开放问题(设计稿某点在 Svelte 更该用别的做法 / 需后端端口),留给人定,别擅自偏离设计。
- 都落成 `ai_proposed` 供人在 dashboard 过目;log 的「VibeHub」行记 title + id。

**拉 context(辅——开工前对齐已有方向)**
- `get_feature_context(HELM_ROOM)` — 已拍板方向(A+ORAGE 定稿、双主题、每日 accent、禁 emoji、三招牌动作),别和它冲突。
- `get_file_context(<要改的 Svelte 文件>)` / `get_team_conventions`(如禁 emoji) / 拿不准来龙去脉 `query_why(spec_id)`。

---

## 验证门(前端:构建/类型/测试 = 硬门;一模一样 = 视觉比对)

1. **硬门**:在 `frontend/` 下 `npm run build` 通过 + `npm run check`(svelte-check + tsc)零错 + `npm run test`(vitest)全绿。**未过不得继续 → 修或熔断。**
2. **视觉对齐**:把 `helm-pro.html` 对应块用 browse 截成**靶图**(附录 A),Svelte 实现对着靶图写;`npm run dev` 起 dev server,browse 截跑起来的 Helm(`localhost:5173`)和靶图比对,逐项核(布局/色/字号/间距/尺寸/双主题)。
   - **两个主题都要核**:靶图和实现都切 dark / light 各截一次比对。
   - 不一致就修,最多 3 轮;3 轮仍差很多 → 停下问。

## step 0(每次启动自检)

1. **读本流程**(本文件,仔细读)。
2. **通读设计基线**:把 [`helm-pro.html`](./helm-pro.html) 从头到尾读懂(CSS + 双主题 + 各块 + JS 的 theme/accent 逻辑)+ 读 [`DESIGN.md`](../../DESIGN.md)(精确 token/规则)——这是要对齐的**唯一真相**。
3. **读现状**:读当前 `frontend/src/app.css` / `lib/Shell.svelte` / `lib/Rail.svelte` / `lib/Today.svelte`,搞清现在做到哪、和设计稿差什么。
4. **拉 VibeHub context**(见「VibeHub」节)。
5. **分支**:在 `feat/design-*` 上,**不在 main 直接改**。
6. **工具就绪**:`cd frontend && npm install`(首次)能跑;`npm run build/check/test` 能跑;`npm run dev` 起得来;browse 的 `$B`(附录 A)能截靶图。

## 每一轮(= 对齐一个模块 / 一个方面)

1. **选一块**:从设计稿里挑**一个还没对齐**的模块或方面。**建议顺序(基础设施先,可自行判断调整)**:① 设计 token(双主题 CSS 变量 + 字体栈)→ ② 主题/accent 系统(theme store + 每日推导 + 对比压暗 + 跟随系统)→ ③ 外壳网格(Shell)→ ④ 细丝 Rail → ⑤ Today 读数(任务/日记/agent 框选视口/项目/邮件/快速动作)→ ⑥ context/遥测块 → ⑦ 状态栏 CLI 面包屑 → ⑧ ORAGE chrome → ⑨ 之后各模式。前几块(token/主题/外壳)是地基,建议先落;之后的顺序和粒度看你判断。**别和 log 里已对齐的重复。**
2. **精读设计稿该块**:布局结构、确切尺寸/间距/字号/色、交互与动画、双主题差异——记下要复刻的精确值(以 helm-pro.html 源码 + DESIGN.md 为准)。
3. **对齐 VibeHub**:别和已拍板冲突;设计稿某点在 Svelte 更该用别的做法 / 需后端 → `query_why` / `add_question`,别擅自改设计。
4. **实现进 Svelte**:在对应文件把这块做到**和设计稿一模一样**(组件复刻布局/色/动画;token 只从 `app.css` 的 CSS 变量取,**组件里不写死 hex**;accent 走 theme store)。贴合现有 Svelte 5 写法(runes/`$props`/`$state`)。
5. **硬门**:`npm run build` + `npm run check` + `npm run test` 全绿。
6. **视觉自检**:browse 截 `helm-pro.html` 该块当靶图 → `npm run dev` 起 server → browse 截实现,dark/light 两主题各比一次。逐项核到一致,≤3 轮。
7. **记 context(VibeHub)+ log**:把这块 context 记进 `HELM_ROOM`(`record_decision` 为主,必要时 `add_constraint`/`add_question`);往 `docs/design/helm-loop-log.md` 追加一条(附录 C)。
8. **每轮 report(硬性,夜间也不省)**:每对齐完一块**必出一份该轮 report**——见下「每轮 report」节。**没出 report ≠ 这块完成。**
9. **计数 +1**。到 N 块 或 全部对齐完 → **批次停顿**。

## 每轮 report(每一轮都要,夜间照出)

每轮收尾**必须**给一份简明 report,内容固定这几项(照抄 log 那条即可,别另编):

- **第几轮 / 块名**(如「第 3 轮 · 细丝 Rail」)。
- **对齐了设计稿哪块** + **Svelte 改了哪些文件/组件**。
- **关键取舍**(哪里没 1:1、为什么;有无 TODO / `add_question`)。
- **硬门结果**:`npm run build` ✓ / `check` 零错 / `test` 第几测全绿(具体数)。
- **VibeHub**:`record_decision`/`add_question` 的 title + id。
- **视觉门**:靶图对比一致(dark+light 都核) / **待用户目视**。
- **commit**:已 push 到哪个 `feat/design-*`(**未合 main**)/ 日间未 commit 等 review。
- **❓需确认**:本轮任何 [needs-human]。

**呈现两处,缺一不可**:① 作为**本轮结束消息**发给用户;② 已随第 7 步记进 `helm-loop-log.md`。两者内容一致即可。

## 批次停顿(默认每对齐 1 块就停)

停下给 review:
- **逐块**:设计稿靶图 + Svelte 实际截图(dark+light)+ 一句话「对齐了哪块 + 关键实现取舍」+ 任何「❓需确认」。
- 工作树**未 commit**。等用户:OK → commit;给修正 → 改到一模一样再 commit。

## 硬规则 / 熔断

- **绝不改 `helm-pro.html` 和 `DESIGN.md`**(只读设计基线)。只改 Svelte 前端。
- **不自动 commit**;commit 在用户 review 通过后。**分支 `feat/design-*`,不在 main 直接改。**
- **合并留人**:PR 按仓库 CI 走——有前端 CI job 就等它绿再合,没有就用户手动合(不盲用 `--auto`,见 `helm-ci-no-branch-protection`)。
- `npm run build`/`check`/`test` 非全绿 **绝不算这块完成**。
- **禁 emoji**(全局硬规则):图标一律单色 SVG / 等宽字形。
- **token 尽量走变量**:组件里颜色/间距优先取 `app.css` 的 CSS 变量,别散落 hex(为双主题 + 每日 accent 好切);个别一次性值可自行斟酌。
- 设计稿某点在 Svelte 不宜 1:1 → `add_question` 等人,**别擅自偏离设计**。
- 3 轮仍对不齐 → 停下问。全部对齐完 → 报告并停。

---

# 阶段 2 · 逐模块完善(让所有功能真能用)

> **触发时机:** 阶段 1 外壳保真已完成并合入 main(Shell + Today + 双主题 + 细丝 Rail + 状态栏 + ORAGE chrome + ⌘K/⌘N 全对齐 helm-pro)。现在进阶段 2。
>
> **目标:** **一个模块一个模块地做成真能用的功能**——把每个模式(Chat / 驾驶舱 / 研究 / 记忆 / 记录 / 日历 / 邮件 / 设置)从占位做成端到端可用:设计它的视图 → 建 Svelte UI → 接真后端 `/api` → 功能真能跑通。顺带把该暴露的能力做成 **notch 也消费的稳定契约**(同一 FastAPI 后端,Web 前端 + notch 原生客户端吃同一套 `/api`,逻辑不分叉)。
>
> **和阶段 1 最大的不同:** 阶段 1 有 `helm-pro.html` 当像素靶;**阶段 2 的各模式 helm-pro 没画**——所以每个模块要**先按 `DESIGN.md` 的设计系统新设计它的视图**(座舱美学:黑/白双主题 token、细丝/仪表观感、无卡片优先、禁 emoji、mono/sans 硬切、招牌缓动),和已落地的外壳一致。复杂模块(如驾驶舱、Chat)可先跑 `/design-consultation` 或手搓一张该模块的设计稿再实现;简单的直接照系统建。参考既有决策:UI 参考 AionUi renderer、驾驶舱逻辑参考 FanBox、大脑能力参考 Odysseus(见各 Room 的 record_decision)。

## 阶段 2 要改的目标(比阶段 1 大)

- **前端 `frontend/src/`**:把各模式的占位换成**真组件 + 真数据**(`fetch('/api/...')` + WS/SSE 流;vite 已 proxy `/api`→后端);抽数据层(`lib/api.ts` / 各 store)。设计上和外壳同一套 token、禁 emoji。
- **后端 `helm/`**:缺的端点就加/补(FastAPI 路由:`cockpit/chat/memory/rag/skills/orchestration/research/notes/tasks/calendar/settings`;后端 `127.0.0.1:8769`,前端 static 挂 `/`、`/api/*` 优先)。**只补该模块要的,别一次动一大片。**
- **notch 客户端 `notch/Sources/HelmNotchCore/HelmBackend.swift`**:只在**改动了 notch 消费的契约**时才碰(见「notch 契约」)。

## 模块清单(逐个做成可用;顺序按价值/依赖,可自行判断)

| 模块(模式) | 归属 room | 后端 router | 做成可用 = | 参考 |
|---|---|---|---|---|
| **Chat 与多模型** | F2 chat-multimodel | `chat` | provider 配置 + 流式对话 + 会话持久化/切换 | Odysseus chat / AionUi |
| **驾驶舱 Cockpit** | F1 cockpit | `cockpit` | 文件浏览/预览 + 内嵌终端(xterm 已在) + 实时看 agent 改动 | FanBox |
| **Agent 编排** | F5 agent-orchestration | `orchestration` | 起/接 Claude Code 会话 + ACP 事件流 → Today/状态栏/驾驶舱实时 | AionUi team/ACP |
| **Deep Research** | F3 deep-research | `research` | 发起研究 + 迭代进度 + 带引用的报告 | Odysseus deep_research |
| **记忆/RAG/Skills** | F4 memory-rag-skills | `memory`/`rag`/`skills` | 记忆浏览/搜 + 文档 RAG + skills 透视 | Odysseus |
| **记录(日记/速记/任务)** | F6 journal-notes-tasks | `notes`/`tasks` | 笔记/日记列表 + 任务 + ⌘N 落库(已有 `POST /api/notes`) | Odysseus Keep |
| **日历** | F7 email-calendar | `calendar` | 事件列表/周月视图 + CalDAV(已有 `GET /api/calendar/events`) | Odysseus |
| **邮件** | F7 email-calendar | `mail`(现禁用) | 邮件列表 + AI 分诊(后端 mail 先启用再接) | Odysseus |
| **设置** | F8/F0 | `settings`/`setup` | 主题(黑/白/accent)+ 后端连接 + 本机 hook + 媒体源 | helm-pro settings modal |
| **Today 真数据** | F8 workspace-layout | 聚合上列 | Today 各节 mock→真(任务/agent/项目/邮件/遥测) | — |

## notch 契约(暴露给 notch 的稳定 `/api`)

notch 已是 Helm 后端的原生客户端(`HelmClient` → `http://127.0.0.1:8769`),**现在就消费这些**——做到对应模块时把主前端也接到同一套,并保持契约稳定:

| 能力 | 端点(现有/规划) | notch 侧消费者 | 主前端消费者 | 归属 room |
|---|---|---|---|---|
| 健康/连接 | `GET /healthz` | 连接状态点 | 状态栏 live 点 | F0 platform-shell |
| 速记/日记 | `POST /api/notes`(kind/journalDate) | 速记 5-kind | 记录模式 + Today 日记 + ⌘N | F6 |
| 任务 | `POST /api/tasks` · `GET /api/tasks` | 派发任务 | 记录模式 + Today 任务 | F6 |
| agent 活动 | `GET /api/orchestration/runs`(+ 期望 **WS/SSE 流**) | agent 监控 | 驾驶舱 + Today Agent 收件箱 + 状态栏 | F5 |
| 日历 | `GET /api/calendar/events` | 下个日程/提醒 | 日历模式 + Today | F7 |
| 媒体 | now-playing(规划) | 折叠条媒体 | (Today/媒体) | — |
| 会话遥测 | model/tokens/latency/rag(规划,可并进 orchestration 流) | (可选) | context 遥测块 + 状态栏 | F5 |

> **原则:** 一个能力**一套 `/api` 契约,两个前端共用**。notch 要的和主前端要的,做成同一个端点/同一份 DTO——不为 notch 单开一套,也不为主前端把 notch 的接口改坏。

## 阶段 2 每一轮(= 把一个模块做成可用;默认一个模块可拆几轮)

模块大,一个模块通常拆成几轮(先视图骨架、再接数据、再补交互),每轮仍是一个能提交的完整小块。节奏:

1. **选活(先清 backlog,再拿新的)**:开工前先看 `docs/design/helm-review-backlog.md` 的 **open 项**——**有 blocking(bug / 缺口)的先修**(修一条在 backlog 标 `[x]` + 记 commit);没 blocking 才**选一个新模块 / 新切片**(按上表顺序或你的判断)。别和 log 重复。
2. **拉这个 Room 的 context**:`get_feature_context(<该模块 room>)` + `get_file_context` + 读后端对应 router(`helm/<feature>/*` + `helm/app.py` mount)拿真实端点/DTO + 读参考实现(AionUi/FanBox/Odysseus,见该 Room 决策)+ 读现状 Svelte 占位。
3. **设计该模块视图**(helm-pro 没画→按 `DESIGN.md` 系统新设计,和外壳一致:双主题 token、座舱观感、无卡片优先、禁 emoji)。复杂的先手搓/`/design-consultation` 出一张该模块设计稿放 `docs/design/`,当该模块的视觉基线;简单的直接照系统建。
4. **建 Svelte UI**(真组件,不是占位)——布局/交互做出来,数据先可空态。走 app.css token、走 theme store、禁 emoji。
5. **接真后端 `/api`**:把数据接上(`fetch`/流,抽 `lib/api.ts`/store);缺端点就在对应 `helm/<feature>` router 补,**保持对 notch 契约向后兼容**——若必须改 notch 也用的端点,**同一次改动一起更新 `HelmBackend.swift`** + `record_decision` 记契约 + `add_constraint` 钉住。**绝不悄悄改坏 notch。**
6. **端到端可用**:这个切片**真能用**(点得动、跑得通、错误有兜底、无数据有空态)。不是画个壳。
7. **硬门**:前端 `npm run build`+`check`+`test` 全绿;改了后端跑 `pytest` 全绿;改了 notch 契约跑 `cd notch && swift build && swift test` 全绿。**非全绿绝不 commit。**
8. **视觉门**:`npm run dev`(5174)截图 dark/light,视图和该模块设计稿/系统一致、空态好看;改了共用端点验证 **notch 仍正常**。
9. **复查(每轮必做,两路)** — 见下「复查与迭代」大节:
   - **代码 review**:对本轮 diff 跑 `/code-review`(或派 `code-reviewer` 子 agent),抓 bug / 正确性 / 简化。
   - **完整性复查**:对照该模块「做成可用 = 什么」+ 参考实现,列出**还缺什么**(没接的子功能 / 边界 / 错误态 / 空态 / 无障碍 / 该模块和 notch 契约的缺口)。
   - **记 backlog**:把 review + 完整性的发现写进 `docs/design/helm-review-backlog.md`(格式见下);当轮能顺手修的 blocking 就修掉并标 `[x]`,其余留 open 排队。
10. **记 context(记进该模块 Room,不只 F8)+ 写 log + 每轮 report**(report 多两行:「功能可用性:能用/差什么」+「复查:review 结论 + 新增/剩余 backlog 条数」+「契约/notch 影响」)。
11. **commit**(夜间自 commit 到 `feat/<模块>-*` 或统一 `feat/modules-*` 分支;不合 main)。backlog 文件随本轮一起提交,让下一轮/早上能看见。

## 阶段 2 硬规则(在阶段 1 硬规则之上加)

- **做成"真能用",不是画壳**:每个切片要点得动、接真数据、有空态/错误兜底;判断"这块完"= 功能真能跑通,不只是好看。
- **每个模块先有设计再建**:helm-pro 没画的模块,先按 `DESIGN.md` 系统定该模块视图(可手搓设计稿),别边写边瞎设计;和已落地外壳一致、禁 emoji。
- **一能力一契约、两前端共用**:不为 notch 或主前端单独分叉后端逻辑。
- **不改坏 notch**:动到 notch 消费的 `/api`/DTO,必须同次更新 `HelmBackend.swift` + `record_decision` 契约 + notch `swift build/test` 绿。
- **后端硬门**:改后端必过 `pytest`;改 notch 契约必过 `swift build/test`。
- **小步提交**:一次一个可用切片,别一轮动一大片(前端+后端+notch 全翻);大改先拆。
- **实时优先**:agent 活动 / 会话遥测 / 媒体这类"活"的,做成 WS/SSE 流,主前端与 notch **吃同一条流**。
- **不可逆/破坏操作不猜**(删数据、迁 schema、动别的 Room 已交付的东西)→ `add_question` 等人。

## 阶段 2 · 复查与迭代(每轮必做,让 loop 持续收敛)

> 每做完一个切片**不是就走**——先复查"这块写对没 / 这个模块还缺什么",把发现记成一份**活的 backlog**,喂回下一轮先修。这样 loop 从"往前铺"变成"边铺边收敛",最后每个模块都真的完整、能用、没明显缺口。

**两路复查(每轮第 9 步都做):**
1. **代码 review(写对没)**:对本轮 diff 跑 `/code-review`(默认 medium;想更狠用 high),或派一个 `code-reviewer` 子 agent。抓 bug、正确性、错误处理、简化/复用。**高置信的 bug 当轮修**(修完再过硬门)。
2. **完整性复查(还缺什么)**:拿该模块的「做成可用 = 什么」(模块清单那列)+ 参考实现(AionUi/FanBox/Odysseus)+ 该模块 Room 的 specs 对照,逐项问:**没接的子功能?边界/错误态/空态?加载态?键盘/无障碍?和 notch 契约的缺口?设计和 DESIGN.md 一致吗?** 列出差距。

**backlog(单一真相,持续迭代的账本):** `docs/design/helm-review-backlog.md`
- 每条一行:`- [ ] [模块][严重度 P0/P1/P2][类型 bug|gap|polish] 描述  (发现 <轮次/日期>)`
- 修掉就改 `[x]` 并在行尾补 `→ 修于 <commit>`;判定不做的标 `~~wontfix~~ + 理由`。
- **P0=blocking**(功能不能用/有 bug)、P1=该有没有(重要缺口)、P2=打磨。
- 每轮**第 1 步先读它、清 P0/P1**;第 9 步把新发现**追加**进去。文件随每轮 commit。

**收敛规则(别让 backlog 无限涨):**
- **P0 优先于一切**:有 open P0 就先修,别拿新模块。
- **一个模块"算完"的定义**:该模块的 open P0/P1 清空 + 完整性复查说"这个模块真能用、没明显缺口" + 硬门/视觉门过。达标才在 log 记「<模块> 完成」并转下一个模块。
- **loop-until-clean**:一个模块可能"建切片 → 复查 → 修 → 再复查"转几轮才算完,这是对的;别没复查干净就跳走。
- **P2 攒着**:打磨项排队,等某模块 P0/P1 清完、或全部模块都可用后再统一扫。
- **发现越界的**(别的 Room 已交付的东西有问题)→ 记 backlog 标该 Room + `add_question`,别擅自动。

---

# 阶段 3 · 驾驶舱 × FanBox 行为对齐(持续优化)

> **触发时机:** 阶段 2 各模块已端到端可用。本阶段专攻 **F1 驾驶舱**:把 FanBox(参考实现,~3800 行打磨过的文件浏览/预览/终端体验)的**行为精华**逐条搬进 helm 驾驶舱,直到"行为不输 FanBox"。
>
> **关键立场:FanBox 是行为参考,不是视觉参考。** 交互/手感/细节照搬精华;皮肤永远守 DESIGN.md 座舱(双主题 token/禁 emoji/零圆角),两者冲突时 DESIGN.md 赢。承既有决策 6601af17(复用精华逻辑、UI 重画,不 vendor)。

## 参考仓

- `reference/fanbox-master` — vendored 快照(仓内只读;唯一允许的写=从源同步更新)。
- `~/work/victor-context/fanbox-master` — 源,随 victor-context 仓 `git pull` 更新。
- 2026-07-02 核对:两份一致,最新 1.11.3;CHANGELOG 满是值得搬的打磨(终端路径可点击/Option 拖拽选中/面包屑对齐…)。

## 对照矩阵(本阶段的账本,替代"模块清单")

`docs/design/fanbox-cockpit-parity.md` — **首轮建立**:通读 FanBox `CHANGELOG.md` + `public/app.js` + `server.js` + 样式,逐条列「FanBox 有 / helm 驾驶舱缺或更差」的行为(文件卡手感/预览细节/终端体验/跟随模式/diff/路径点击/搜索/键盘流…),标 **P1(核心体验差距)/ P2(打磨)**。每轮从矩阵挑未勾的最高优先级一条;搬完打勾+记 commit;判"不该搬"(Electron 特有/与座舱定位冲突)标 ~~wontfix~~+理由。缺陷复查仍记 `helm-review-backlog.md`([驾驶舱] 标签),P0/P1 缺陷优先于拿新条。

## 阶段 3 每一轮

1. **刷参考**:`git -C ~/work/victor-context pull --ff-only`;diff 两份 fanbox-master,有更新先同步 vendored 快照 + 读新 CHANGELOG 条目(可能新增矩阵条目)。
2. **选条**:backlog 有 open 驾驶舱 P0/P1 先修;否则从矩阵挑未勾的最高优先级一条。
3. **拉 context**:`get_feature_context(35da1ada-8d45-48c8-961d-e99b8941179b)`(F1 room)+ 读 helm 现状(`frontend/src/lib/cockpit/*` + `helm/cockpit/*`)+ 精读 FanBox 里该行为的实现。
4. **移植成原生**:Svelte/Python(Electron IPC→REST/WS,vanilla DOM→runes 组件,精华逻辑抽框架无关 ts),**不 vendor FanBox 代码**;皮肤走 token。
5. **端到端真能用**:dev 5174 开真项目实操验证该行为;空态/错误兜底。
6. **硬门**(同阶段 2):前端 build+check+test 绿;改后端 pytest 绿;动 notch 消费的 `/api` 必同次更 `HelmBackend.swift`+notch swift 绿(cockpit 端点 notch 现不消费,新开共用端点前先 record)。
7. **视觉门**:dark/light 截图;确认没把 FanBox 的皮带进来。
8. **复查**:本轮 diff 自查 + 完整性(FanBox 该行为的边界 case 搬全了吗)→ 记 backlog。
9. **记账**:矩阵勾条 + `helm-loop-log.md` + `record_decision`(F1 room:搬了哪个行为/怎么映射/哪里故意不同)+ 每轮 report。
10. **commit**(夜间自 commit+push 到 `feat/cockpit-fanbox-*`,不合 main;日间停下等 review)。

## 阶段 3 硬规则(在阶段 1/2 硬规则之上)

- **性能红线守 F1 约束**:>1000 项目录滚动/点击 <0.1s、agent 写文件高亮 <500ms(FanBox 体验基线正是出处,搬行为不许搬慢)。
- `reference/` 只读(同步快照除外);卡住某条修 3 轮不绿 → 矩阵标 blocked + `add_question` + 换下一条。
- **收敛/收官**:矩阵 P1 全勾(或 wontfix 注明理由)+ backlog 无 open 驾驶舱 P0/P1 → 报告并停。

## 附录 A:构建 / 测试 / 截靶图

```bash
# 硬门(阶段 1):构建 + 类型 + 测试(在 frontend/ 下)
cd frontend && npm run build && npm run check && npm run test

# 硬门(阶段 2 追加):改了后端跑 pytest;改了 notch 契约跑 swift
pytest                                   # 后端(仓库根;改了 helm/ 才跑)
cd notch && swift build && swift test    # 只在动了 notch 消费的 /api 契约时

# 设计稿靶图(设计基线对应块;dark 与 light 各一张)
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B="$_ROOT/.claude/skills/gstack/browse/dist/browse"; [ -x "$B" ] || B="$HOME/.claude/skills/gstack/browse/dist/browse"
$B goto "file://$_ROOT/docs/design/helm-pro.html"
$B screenshot /tmp/target-dark.png                          # 默认 dark = 靶(Read 看)
$B js "document.getElementById('app').dataset.theme='light';'ok'"   # 切 light
$B screenshot /tmp/target-light.png

# 跑起来的 Helm(dev server)截图对比
cd frontend && npm run dev &                                # 后台起 vite(默认 5173)
$B goto "http://localhost:5173"
$B screenshot /tmp/actual-dark.png                          # 和 /tmp/target-*.png 逐项比
```

> dark/light 两主题都要比。切主题的方式看实现(theme store / `data-theme` / `prefers-color-scheme`)——实现里怎么切,靶图和实际就怎么切来对齐。

## 附录 B:设计稿(helm-pro.html) → Svelte(目标)映射

| 设计稿(`helm-pro.html` / `DESIGN.md`) | Svelte(要做成一样的地方) |
|---|---|
| `:root` + `[data-theme]` 双主题 CSS 变量 | `frontend/src/app.css`(全局 token) |
| JS 的 theme 切换 + `darken()` + palette | 新增 theme store(`lib/theme.svelte.ts`):dark/light/跟随系统 + 每日 accent + 对比压暗 |
| `.app` 网格 + titlebar/statusbar | `lib/Shell.svelte`(网格 + titlebar + statusbar) |
| `.rail`(fil/anchor/pulse/ric) | `lib/Rail.svelte`(细丝 + 锚点 + 脉冲 + SVG 图标) |
| `.ctx`(cproj/nav/telem/coord/cornertag) | context 面板(Shell 内或抽 `lib/ContextPanel.svelte`) |
| `.rd`(rdrow/gut/task/jr/framed/proj/mail/qa) | `lib/Today.svelte`(仪表读数各节) |
| `.sbar` CLI 面包屑 | `lib/Shell.svelte` statusbar |
| ORAGE chrome(点阵/fidmark/coord/framed/weak) | Shell/Today 内的 chrome + 强度状态 |
| `cubic-bezier(.32,.72,0,1)` + 时长 | 全局 CSS 过渡变量(app.css)+ 各组件动效 |

## 附录 C:log 条目格式

```markdown
## YYYY-MM-DD HH:MM · <slug>
- 对齐: <这轮把设计稿哪一块做进了 Svelte>
- 设计基线: <helm-pro.html 哪块 / DESIGN.md 哪节>(只读对照,未改)
- Svelte 改动: <文件 + 关键组件/函数>
- 取舍: <怎么复刻 / 哪里表达不同但视觉一致 / 有无 add_question / TODO>
- VibeHub: record_decision「…」→ <id> (ai_proposed);add_constraint/add_question「…」→ <id>(没调用写"无")
- 验证: npm build ✓ / check 零错 / test <N 通过>;视觉:靶图对比 <dark+light 一致 / 待用户目视>
- 状态: ✅ 待 review  |  ❓需确认: <…>
```
