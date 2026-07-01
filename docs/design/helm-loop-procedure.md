# Helm 主工作台 对齐 Loop · 循环流程(每轮:把设计稿的一块,做进 Svelte 前端到一模一样)

> 这条 loop 的本体:**`docs/design/helm-pro.html` 是锁定的最终设计稿(只读、唯一真相),配合 `DESIGN.md`(token/规则);把它的 UI 一块一块"原样"实现进 Svelte 前端,直到跑起来的 Helm 和 helm-pro.html 看起来/用起来一模一样。**
> 启动命令见 [`helm-loop-prompt.md`](./helm-loop-prompt.md)。这是**真实开发**(F8 workspace-layout room),仿 notch 的 [`notch-loop-procedure.md`](../../notch/docs/notch-loop-procedure.md) 但目标从 Swift 换成 **Svelte 前端**。

> **两阶段。本 loop 分两个阶段,先视觉后数据:**
> - **阶段 1 · 前端保真(先做,默认档位):** 把 Svelte 前端做到和 `helm-pro.html` 一模一样(布局/色/字号/间距/尺寸/动画/交互/双主题)。**后端数据不碰。**
> - **阶段 2 · 后端接入 + 暴露给 notch(前端差不多之后再做):** 把设计稿的 mock 逐块换成真后端数据(`/api` + 流),并把该暴露的能力做成 notch 也消费的稳定契约。详见下方「阶段 2」大节。

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

# 阶段 2 · 后端接入 + 暴露给 notch

> **触发时机:** 阶段 1 差不多之后(外壳 / 细丝 Rail / Today 读数 / 双主题 / 状态栏 / ORAGE chrome 都对齐、跑起来和 `helm-pro.html` 一模一样),再进阶段 2。不必 100% 像素完美才进——主体对齐、剩零星细节可并行。
>
> **目标:** 把设计稿里的 mock 逐块换成**真后端数据**,并把 Helm 后端该暴露的能力做成 **notch 也消费的稳定契约**——同一个 FastAPI 后端,主前端(Web)和 notch(原生 Swift 客户端)吃同一套 `/api`,逻辑不分叉。

## 阶段 2 的两个文件(和阶段 1 不同)

- **只读设计基线仍是 `helm-pro.html` + `DESIGN.md`**:接了真数据后,**视觉/布局/空态必须仍和设计稿一模一样**(真数据渲染进同一套版式;没数据走优雅空态,别破版)。设计稿依旧不改。
- **要改的目标**(阶段 2 扩大):
  - 前端 `frontend/src/`:把 mock 换成 `fetch('/api/...')` + WS/SSE 流(vite 已 proxy `/api`→后端);抽数据层(如 `lib/api.ts` / 各 store)。
  - 后端 `helm/`:缺的端点就加/补(FastAPI 路由:`cockpit/chat/memory/rag/skills/orchestration/research/notes/tasks/calendar/settings`;后端 `127.0.0.1:8769`,前端 static 挂 `/`、`/api/*` 优先)。
  - notch 客户端 `notch/Sources/HelmNotchCore/HelmBackend.swift`:只在**改动了 notch 消费的契约**时才碰(见下「notch 契约」)。

## notch 契约(暴露给 notch 的稳定 `/api`)

notch 已经是 Helm 后端的原生客户端(`HelmClient` → `http://127.0.0.1:8769`),**现在就消费这些**——阶段 2 把主前端也接到同一套,并保持契约稳定:

| 能力 | 端点(现有/规划) | notch 侧消费者 | 主前端消费者 | 归属 room |
|---|---|---|---|---|
| 健康/连接 | `GET /healthz` | 连接状态点 | 状态栏 live 点 | F0 platform-shell |
| 速记/日记 | `POST /api/notes`(kind/journalDate) | 速记 5-kind | Today 日记 + ⌘N | F6 journal-notes-tasks |
| 任务 | `POST /api/tasks` · `GET /api/tasks` | 派发任务 | Today 任务 | F6 |
| agent 活动 | `GET /api/orchestration/runs`(+ 期望 **WS/SSE 流**) | agent 监控 | Today Agent 收件箱 + 状态栏 | F5 agent-orchestration |
| 日历 | `GET /api/calendar/events` | 下个日程/提醒 | Today(日历模式) | F7 email-calendar |
| 媒体 | now-playing(规划) | 折叠条媒体 | (Today/媒体) | — |
| 会话遥测 | model/tokens/latency/rag(规划,可并进 orchestration 流) | (可选) | context 遥测块 + 状态栏 | F5 |

> **原则:** 一个能力**一套 `/api` 契约,两个前端共用**。notch 要的和主前端要的,做成同一个端点/同一份 DTO——不为 notch 单开一套,也不为主前端把 notch 的接口改坏。

## 阶段 2 每一轮(= 接一个数据源)

和阶段 1 同节奏,只是"块"从"视觉块"变成"数据源":

1. **选一个数据源**,按依赖/价值排序(建议):**① 健康/连接(状态栏 live 点 + context) → ② 速记/日记(⌘N + Today 日记,已有 `POST /api/notes`) → ③ 任务(Today 任务) → ④ agent 活动(Today Agent 收件箱 + 状态栏,`orchestration/runs`,补实时流) → ⑤ 最近项目(cockpit) → ⑥ 会话遥测(context 块) → ⑦ 日历 → ⑧ 邮件(F7,后端 mail 现禁用,后加) → ⑨ chat/research/memory 各模式**。别和 log 重复。
2. **摸清契约**:读后端对应 router(`helm/<feature>/*` + `helm/app.py` 的 mount)拿到真实端点/DTO;读 notch `HelmBackend.swift` 看它怎么消费同一能力。**对不上就以"两个前端共用一套"为准去统一**。
3. **对齐 VibeHub**(记进**对应 feature room**,不只 F8):这条数据怎么接、契约长什么样。
4. **接进前端**:把该块的 mock 换成真 `/api` 调用 / 流;**保持设计稿版式不变**——真数据填进同一布局,无数据走优雅空态(别破版、别塞占位丑态)。抽到数据层(`lib/api.ts`/store),组件只消费。
5. **后端补端点(若缺)**:在对应 `helm/<feature>` router 加/补;**保持对 notch 的契约向后兼容**——若必须改 notch 也用的端点,**同一次改动里一起更新 `HelmBackend.swift`** 并 `record_decision` 记契约变更 + `add_constraint` 钉住契约。**绝不悄悄改坏 notch 消费的接口。**
6. **硬门(阶段 2 更严)**:
   - 前端:`npm run build` + `check` + `test` 全绿。
   - 后端(改了才跑):`pytest`(仓库根 `pytest` 或对应模块)全绿。
   - 若改了 notch 契约:`cd notch && swift build && swift test` 全绿(别把 notch 编坏)。
7. **视觉门**:真数据 + 空态都要和设计稿版式一致(browse dark/light 对比);**并验证 notch 仍正常**(改了共用端点时)。
8. **记 context + log + 每轮 report**:同阶段 1(report 里多一行「契约/notch 影响」)。

## 阶段 2 硬规则(在阶段 1 硬规则之上加)

- **设计稿仍只读、仍是视觉真相**:接了真数据不许破版,空态也要好看。
- **一能力一契约、两前端共用**:不为 notch 或主前端单独分叉后端逻辑。
- **不改坏 notch**:动到 notch 消费的 `/api`/DTO,必须同次更新 `HelmBackend.swift` + `record_decision` 契约 + notch `swift build/test` 绿。
- **后端硬门**:改后端必过 `pytest`;改 notch 契约必过 `swift build/test`。
- **实时优先**:agent 活动 / 会话遥测 / 媒体这类"活"的,做成 WS/SSE 流,让主前端的 Agent 收件箱/状态栏和 notch 的 agent 监控**吃同一条流**。
- **不可逆/破坏操作不猜**(删数据、迁移 schema 等)→ `add_question` 等人。

---

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
