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

## 阶段 2 · 逐模块完善,让所有功能真能用(当前阶段)

阶段 1 外壳保真已合入 main。阶段 2 = **一个模块一个模块地做成真能用的功能**:每个模式(Chat / 驾驶舱 / 研究 / 记忆 / 记录 / 日历 / 邮件 / 设置)从占位做成端到端可用——**设计它的视图(helm-pro 没画,按 DESIGN.md 系统新设计)→ 建 Svelte UI → 接真后端 /api → 功能真能跑通**,并守 notch 契约。流程 + 模块清单见 `helm-loop-procedure.md` 的「阶段 2」大节。

### 命令(默认:一个可用切片一停,让我 review)

```
读 docs/design/helm-loop-procedure.md 的「阶段 2 · 逐模块完善」+「复查与迭代」全节 + 模块清单;确认阶段 1 外壳已合入 main。现在进阶段 2:一个模块一个模块地把各模式做成端到端真能用(不是画壳)。① 选活:先读 docs/design/helm-review-backlog.md 的 open 项——有 P0/P1(bug/缺口)先修(修完标 [x]+记 commit),没 blocking 才挑一个新模块/切片(建议 Chat→驾驶舱→Agent 编排→研究→记忆/RAG→记录→日历→邮件→设置→Today 真数据,可自行判断);② 拉该 Room context get_feature_context(<该模块 room>)+ get_file_context + 读后端对应 router(helm/<feature> + helm/app.py mount,后端 127.0.0.1:8769)拿真实端点/DTO + 读参考实现(AionUi/FanBox/Odysseus,见该 Room 决策)+ 读现状占位;③ 设计该模块视图——helm-pro 没画,按 DESIGN.md 系统新设计(双主题 token/座舱观感/无卡片优先/禁 emoji/走 theme store),复杂的先手搓一张设计稿放 docs/design/ 当视觉基线;④ 建真 Svelte 组件(不是占位)走 token;⑤ 接真后端 /api(fetch/流,抽 lib/api.ts 或 store),缺端点在对应 router 补,守 notch 契约——改 notch 也用的端点必同次更新 HelmBackend.swift + record_decision 记契约 + add_constraint 钉住,绝不改坏 notch;⑥ 端到端可用(点得动/跑得通/错误兜底/空态好看);⑦ 硬门:前端 cd frontend && npm run build+check+test 全绿、改后端跑 pytest 绿、改 notch 契约跑 cd notch && swift build && swift test 绿(非绿绝不 commit);⑧ 视觉门 npm run dev(5174)截 dark/light,改共用端点验证 notch 仍正常;⑨ 复查(必做,两路):对本轮 diff 跑 /code-review(或派 code-reviewer 子 agent)抓 bug/正确性(高置信当轮修)+ 完整性复查(对照该模块「做成可用=什么」+参考实现+Room specs,列还缺什么:子功能/边界/错误态/空态/加载态/无障碍/notch 契约缺口/和 DESIGN.md 一致否)→ 发现按 P0/P1/P2 记进 docs/design/helm-review-backlog.md;⑩ record_decision 进对应 feature room(F2/F1/F5/F3/F4/F6/F7…)+ 写 docs/design/helm-loop-log.md + 每轮 report(多两行「功能可用性:能用/差什么」+「复查:结论+新增/剩余 backlog 条数」+「契约/notch 影响」)。每做完一个可用切片(或清完一批 backlog)停下让我 review;不自动 commit(分支 feat/modules-*,合并留我),backlog 随轮提交,DESIGN.md/helm-pro.html 只读,不可逆/破坏操作 add_question 等我。收敛原则:P0 优先于拿新活;一个模块 open P0/P1 清空+完整性复查说"真能用没明显缺口"才算完(可复查→修→再复查转几轮);做成真能用不是画壳;一能力一契约两前端共用;小步提交别一轮动一大片。
```

### 🌙 阶段 2 夜间模式(整夜自主推进模块)

把上面命令前面加 `/loop 5m` 且带【夜间模式】:每做完一个可用切片不停下等我,硬门全绿就自己 commit 到 feat/modules-* 并 push、接着下一块。**每轮照做复查(第 9 步):跑 /code-review + 完整性复查 → 记 backlog;下一轮开头先清 backlog 的 P0/P1**。这样整夜 loop 会自己"建→复查→修→再复查"地收敛,不只往前铺。每个本该停下/问我的点改成"做最忠于 DESIGN.md 的暂定 + record/add_question + 代码留 TODO + 继续"。硬底线不松:非全绿绝不 commit、不合 main、不改坏 notch、不可逆操作不猜、DESIGN.md 只读。每轮照出 report。所有模块都可用(各自 open P0/P1 清空、复查说没明显缺口)或 全卡住 才报告并停。

```
/loop 5m 读 docs/design/helm-loop-procedure.md 的「阶段 2 · 逐模块完善」+「复查与迭代」全节 + 模块清单,以【夜间模式】把各模式一个个做成端到端真能用、并每轮复查收敛,整夜不停、完全自主。① 选活:先读 docs/design/helm-review-backlog.md,有 open P0/P1 先修(标 [x]+记 commit),没 blocking 才挑新模块/切片;② 拉该 Room context(get_feature_context + 后端 router + 参考实现 + 现状占位);③ 按 DESIGN.md 系统设计该模块视图(座舱/双主题/禁 emoji,复杂的先手搓设计稿);④ 建真 Svelte 组件(走 token);⑤ 接真 /api(缺端点在对应 router 补,守 notch 契约:改共用端点必同次更新 HelmBackend.swift+record+notch swift 绿);⑥ 端到端可用(点得动/跑得通/空态兜底);⑦ 硬门 前端 npm build+check+test 绿、改后端 pytest 绿、改 notch swift 绿(某切片修 3 轮不绿就 skip+add_question+切下一个);⑧ dev 5174 截 dark/light 视觉门+改共用端点验 notch 仍正常;⑨ 复查两路:对本轮 diff 跑 /code-review 或派 code-reviewer 子 agent(bug 高置信当轮修)+ 完整性复查(对照「做成可用=什么」+参考实现+Room specs 列还缺什么)→ 按 P0/P1/P2 记进 docs/design/helm-review-backlog.md;⑩ record_decision 进对应 feature room + 写 helm-loop-log.md + 每轮 report(收尾消息+log,多两行「功能可用性」+「复查:结论+新增/剩余 backlog」+「契约/notch 影响」)→ 自己 commit(含 backlog)到 feat/modules-* 并 push,接着下一块(下一块优先清 backlog P0/P1)。关键:每个本该停下 review/问我的点都改成"做最忠于 DESIGN.md 的暂定 + record/add_question + 代码留 TODO + 继续",不停下等我。硬底线:做成真能用不是画壳;非全绿绝不 commit;不合 main(合并留我);不改坏 notch;不可逆/破坏操作(删数据/迁 schema/动别 Room 交付物)不猜;DESIGN.md/helm-pro.html 只读。收敛:P0 优先于拿新活;一个模块 open P0/P1 清空+复查说没明显缺口才算完。所有模块可用 或 全卡住 才报告并停。
```

## 调参

- **对齐粒度 N**:命令里 `每对齐 1 块` 的块数。默认 1 最稳(尤其起步 token/主题/外壳这些基础设施块)。
- **保真度**:默认「一模一样」。某些地方你想用更 Svelte 原生的做法(而非死磕设计稿像素),在命令里说,或让 loop 用 add_question 提给你定。
- **只跑一个主题先**:命令里加"先只对齐 dark 主题,light 留后一轮"——但 token 那轮建议双主题一起落(省得回头返工)。
