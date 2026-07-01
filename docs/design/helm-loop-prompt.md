# Helm 主工作台 对齐 Loop · 启动命令

> 这条 loop 的本体:**`docs/design/helm-pro.html` 是锁定的最终设计稿(只读)+ `DESIGN.md`(token/规则);把它的 UI 一块块做进 Svelte 前端,直到跑起来的 Helm 和设计稿一模一样。**
> 流程定义见 [`helm-loop-procedure.md`](./helm-loop-procedure.md)。
> **本档位:默认每对齐 1 块就停下让你 review(不自动 commit)。**
>
> **🎯 阶段 1 范围:只做「前端和设计稿一模一样」,后端数据不碰。** 数据用设计稿同款 mock(tasks/journal/agents/projects/mail/遥测值等照搬 helm-pro.html 写死的值);要后端加端口的留 TODO + mock 顶上,阶段 1 不为接后端停留(留给阶段 2)。判断"对齐完"只看视觉/交互像不像设计稿。前端差不多后进阶段 2(接后端 + 暴露给 notch,见下)。
>
> **🧭 留白:** 下面命令里的**顺序/粒度/具体做法是建议,agent 自行判断**;硬的只有——设计稿只读、gates 全绿、禁 emoji、不改坏 notch 契约、先分支不自动 commit、不可逆操作先问。有更 Svelte-native / 更合理的做法(而非死抠像素)就 `add_question` 提出来,别闷头照抄。

## 别搞反的两个文件

- **只读设计基线 / 唯一真相**:`docs/design/helm-pro.html` + `DESIGN.md`(loop 绝不改它们)。
- **要改的目标**:Svelte 前端 —— `frontend/src/app.css`(token)、`lib/Shell.svelte`、`lib/Rail.svelte`、`lib/Today.svelte` + 新增 theme store。

现状(2026-07-02):前端是**零设计浅色线框**(功能骨架在:四栏网格 + statusbar;`Rail`/`Today` 未上妆;`app.css` 近乎空)。loop 现在 = **从零把设计稿逐块做进这套骨架**,先 token/主题 → 外壳 → 细丝 Rail → Today → context/遥测 → 状态栏 → ORAGE chrome。数据用设计稿同款 mock。

## 命令(默认:逐块对齐,1 块一停)

直接粘这一段:

```
先仔细读 docs/design/helm-loop-procedure.md;再把 docs/design/helm-pro.html(锁定的最终设计稿/唯一真相,只读、绝不改)从头到尾读懂(CSS+双主题+各块+theme/accent 的 JS 逻辑)并读 DESIGN.md(精确 token/规则),再读现状 Svelte(frontend/src/app.css、lib/Shell.svelte、lib/Rail.svelte、lib/Today.svelte)搞清还差哪些(现在是零设计浅色线框,要从零把设计逐块做进去)。范围:只做前端和设计稿一模一样,后端不碰——数据用设计稿同款 mock(照搬 helm-pro.html 写死的值),要后端加端口的留 TODO 别停。用 VibeHub:开工前 get_feature_context(93159be4-d502-456f-8735-a06394093759=F8 workspace-layout room)+ get_file_context + get_team_conventions 拉上下文,已拍板方向(A+ORAGE 定稿/双主题默认跟随系统/每日 accent 调色板/禁 emoji/三招牌动作:细丝 Rail·无卡片 Today·遥测状态栏)当硬约束。然后按「每一轮」对齐,按依赖排序(先 ① 设计 token 双主题 → ② 主题/accent 系统 → ③ 外壳 Shell → ④ 细丝 Rail → ⑤ Today 读数 → ⑥ context/遥测 → ⑦ 状态栏 → ⑧ ORAGE chrome):挑一块→精读设计稿该块的确切布局/尺寸/色/交互/双主题→实现进对应 Svelte 文件做到一模一样(token 只取 app.css 的 CSS 变量、别写死 hex、accent 走 theme store、禁 emoji)→ cd frontend && npm run build + npm run check + npm run test 全绿(硬门)→ 用 browse 把设计稿该块截成靶图做视觉比对(npm run dev 起 localhost:5173,dark/light 两主题各截一次比)→ 把这块实现 record_decision、硬边界 add_constraint、原生不宜 1:1 的点 add_question(都绑 F8 room)→ 写 docs/design/helm-loop-log.md。每对齐 1 块就停下,给一份 report(设计稿靶图+实现说明+关键取舍+Svelte 实际截图 dark/light),等我确认或给修正;绝不改 helm-pro.html/DESIGN.md,不自动 commit(分支 feat/design-*,合并留我),设计稿某点不宜 1:1 就 add_question 别擅自偏离。上面的顺序/粒度/在 Svelte 里怎么表达都是建议——你自己判断,有更 Svelte-native 的做法就 add_question 提出来。
```

## 变体

- **一次对齐几块再停**:把命令里的 `每对齐 1 块` 改成 `每对齐 2 块`(建议别超 3)。
- **指定从哪块开始**:命令里加一句"先对齐 <设计 token / 主题系统 / 外壳 Shell / 细丝 Rail / Today 读数 / 状态栏 / ORAGE chrome>"。
- **🔭 守候模式**(持续对齐,/loop):
  ```
  /loop 20m 读 docs/design/helm-loop-procedure.md(通读设计基线 helm-pro.html + DESIGN.md + 读现状 Svelte + 用 VibeHub pull F8 workspace-layout room),按「每一轮」把设计稿逐块做进 Svelte 前端到一模一样:挑一块→精读设计稿→实现进 Svelte(token 走 app.css 变量/禁 emoji)→npm build+check+test 绿→browse 截靶图 dark/light 视觉比对→record 进 F8 room→写 helm-loop-log.md;每对齐 1 块停下让我 review(不自动 commit、不改设计稿);全部对齐完就报告并停。
  ```

## 🌙 夜间模式(完全自己跑,整夜不停)

档位 = 在默认档之上松开「停下 review」:每对齐一块**不再停下等你**,自检过了就自己 commit 到分支,接着下一块,整夜跑。把每个本该「停下 review / 问你 / add_question 等人」的点,都换成「**做最忠于设计稿的暂定实现 + record_decision/add_question 记下来当 context + 代码留 TODO + 继续**」。

取舍(接受才跑整夜):
- **只做前端保真、后端不碰**:数据用设计稿同款 mock;要后端加端口的留 TODO + mock 顶上,**绝不为接后端停留或去猜后端接口**。"对齐完"只看视觉/交互像不像设计稿。
- **每轮出 report**:夜里也每块给一份 report(见 procedure「每轮 report」)——记进 log + 收尾消息,你早上能一路回看。
- **硬底线不松**:`npm run build` + `check` + `test` **非全绿绝不 commit**——某块 3 轮修不绿就 skip 它、add_question、切下一块,坏代码不进分支。
- **只攒分支 commit、不合 main**:夜里只在 `feat/design-*` 上 commit + push,**合并留给你早上**。
- **设计稿某点不宜 1:1**:不停。取最忠于设计的暂定做法 + `add_question`(点明哪块 / 暂定了什么 / 备选)+ TODO + 继续。
- **视觉对齐无人目视**:夜里没法你确认「一模一样」。用 browse 靶图(dark/light)自比对到位即可;拿不准的 `add_question` 标「待你目视」,继续。
- **绝不改 `helm-pro.html`/`DESIGN.md`**(设计基线只读);不可逆 / 破坏性操作绝不猜。
- **唯一会真停**:所有块都对齐完,或全卡住(都修不绿 / 全在等你)→ 报告并停。早上你看分支 commit + `add_question` 队列即可。

直接粘这一段跑整夜:
```
/loop 1m 读 docs/design/helm-loop-procedure.md(通读只读设计基线 helm-pro.html + DESIGN.md + 读现状 Svelte + 用 VibeHub pull F8 workspace-layout room context),以【夜间模式】把设计稿逐块做进 Svelte 前端到一模一样,整夜不停、完全自主。范围:只做前端和设计稿一模一样,后端不碰——数据一律用设计稿同款 mock,要后端加端口的留 TODO 别停别猜后端。按依赖排序(token→主题→外壳→细丝 Rail→Today→context/遥测→状态栏→ORAGE chrome)。每块 挑→精读设计稿→实现进 Svelte(token 走 app.css 变量/别写死 hex/accent 走 theme store/禁 emoji)→cd frontend && npm run build + npm run check + npm run test 全绿(硬门,非绿绝不 commit;某块修 3 轮还不绿就 skip+add_question+切下一块)→browse 截设计稿靶图 dark/light 视觉比对→把这块 context record_decision 进 F8 room(暂定/存疑的 add_question 标 [needs-human])→写 helm-loop-log.md→每轮出一份 report(收尾消息+log)→自己 commit 到 feat/design-* 分支并 push,接着下一块。关键:每个本该停下 review 或问我的点,都改成"做最忠于设计稿的暂定实现 + record/add_question 记下来 + 代码留 TODO + 继续",不停下等我。硬底线:绝不改 helm-pro.html/DESIGN.md;npm build/check/test 非全绿绝不 commit;不合 main(合并留我早上);不可逆/破坏操作不猜。全部块对齐完或全卡住才报告并停。
```

## 阶段 2 · 后端接入 + 暴露给 notch(前端差不多之后)

前端主体对齐后,进阶段 2:把设计稿的 mock 逐块换成真后端数据,并把该暴露的能力做成 notch 也消费的稳定契约(同一 FastAPI 后端,主前端 Web + notch 原生客户端吃同一套 `/api`,逻辑不分叉)。流程细节见 `helm-loop-procedure.md` 的「阶段 2」大节。

直接粘这一段:

```
读 docs/design/helm-loop-procedure.md 的「阶段 2 · 后端接入 + 暴露给 notch」全节;确认阶段 1(前端和 helm-pro.html 一模一样)已差不多。现在进阶段 2:把设计稿里的 mock 逐块换成真后端数据,并把该暴露的能力做成 notch 也消费的稳定契约。设计稿 helm-pro.html + DESIGN.md 仍只读、仍是视觉真相——接了真数据不许破版,空态也要好看。按依赖排序选一个数据源(① 健康/连接 → ② 速记/日记(已有 POST /api/notes)→ ③ 任务 → ④ agent 活动(orchestration/runs,补实时流)→ ⑤ 最近项目 → ⑥ 会话遥测 → ⑦ 日历 → ⑧ 邮件 → ⑨ 各模式):摸清后端对应 router 的真实端点/DTO(helm/<feature> + helm/app.py mount,后端 127.0.0.1:8769)+ 读 notch HelmBackend.swift 看它怎么消费同一能力→前端把该块 mock 换成真 /api 调用/流(保持设计稿版式、无数据走优雅空态、抽到 lib/api.ts 或 store)→后端缺端点就在对应 router 补(保持对 notch 契约向后兼容;若必须改 notch 也用的端点,同一次改动一起更新 HelmBackend.swift + record_decision 记契约 + add_constraint 钉住,绝不改坏 notch)→硬门:前端 npm run build+check+test 全绿、改了后端跑 pytest 全绿、改了 notch 契约跑 cd notch && swift build && swift test 全绿→视觉门:真数据+空态和设计稿一致(dark/light),改了共用端点验证 notch 仍正常→record_decision 进对应 feature room(F6 notes/tasks、F5 orchestration、F7 calendar/mail…)+ 写 helm-loop-log.md + 每轮 report(多一行「契约/notch 影响」)。每接 1 个数据源停下让我 review;绝不改 helm-pro.html/DESIGN.md,不自动 commit,不可逆/破坏操作(删数据/迁 schema)add_question 等我。原则:一能力一契约、两前端共用,不为任一端分叉后端逻辑。
```

## 调参

- **对齐粒度 N**:命令里 `每对齐 1 块` 的块数。默认 1 最稳(尤其起步 token/主题/外壳这些基础设施块)。
- **保真度**:默认「一模一样」。某些地方你想用更 Svelte 原生的做法(而非死磕设计稿像素),在命令里说,或让 loop 用 add_question 提给你定。
- **只跑一个主题先**:命令里加"先只对齐 dark 主题,light 留后一轮"——但 token 那轮建议双主题一起落(省得回头返工)。
