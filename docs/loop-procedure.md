# Loop 循环流程(每轮执行的标准定义)

> 这是 loop 每一轮要做什么的**权威定义**。配合 [`METHODOLOGY.md`](./METHODOLOGY.md) 使用——
> 决策原则(六条)、升级边界(业务 vs 技术)、熔断条件都在那里;本文件只定义"流程"。
> 启动命令见 [`loop-prompt.md`](./loop-prompt.md)。
> 开发约定(commit / 分支 / 验证门 / 项目结构 / 每轮 report)见 [`CONVENTIONS.md`](./CONVENTIONS.md)——**每轮开发前应读到**。

> **自动化档位:真·无人值守。** loop 自己 plan → 决策 → 记录 → 开发 → 优化 → 反思 → 合并,全程不停,
> **只有遇到「难撤 / 定方向的产品决策」才停下问人**(见 METHODOLOGY 第一、二节)。技术决策(含数据模型、
> 对外契约、**安全边界**、核心选型)+ **可逆的产品小决定**(文案、默认排序…)loop 都自己定,按可逆性
> **分级详细留痕**到 VibeHub(`record_decision` / `add_constraint`),让人能在 dashboard 上事后审计、必要时否决回滚。
> 安全网是**验证门(测试 + 构建)** 与**熔断**,不是人工卡点。

> **两条轨(loop 既消费也生产)**:
> - **A 轨 · 路线图**:PRD 的 Room→milestone,造新功能的主干。**默认最高优先级。**
> - **B 轨 · 自省 backlog**:每个 milestone 后 loop 反思"哪里能更好",把发现用 `create_ticket` 落进 VibeHub
>   (技术类 + 可逆产品小改自消化 / 难撤产品标 `[needs-human]` 停着等批),在 Room 收尾时**限额 drain**。详见下方「B 轨」一节。
>   这让 VibeHub 不只是审计日志,而是真正的工作队列——也避免开发中冒出的改进点烂在 TODO 里。

---

## Room 开发顺序(自动选 Room 时按此)

> 来源:PRD 路线图(M0→M6)+ 优先级。顺序可调,改这里即可。横切的 `workspace-layout`
> 这里指它的"外壳骨架";后续业务 Room 会在各自分支里往它加自己的面板(方法论里的横切例外)。

1. `platform-shell` — 产品地基(运行时/存储/外壳/设置)
2. `dev-infra` — 验证门/测试/CI(需地基骨架,故紧随其后)
3. `workspace-layout` — UI 外壳骨架(三栏 + Rail + ⌘K)
4. `cockpit` — 驾驶舱
5. `chat-multimodel` — Chat
6. `memory-rag-skills` — 记忆/RAG
7. `agent-orchestration` — MCP 接通终端 agent
8. `deep-research` — 深度研究
9. `journal-notes-tasks` — 日记/速记/任务
10. `email-calendar` — 邮件/日历

## step 0(每次启动自检)

1. **选 Room**:若命令指定了 Room 就用它;否则按上面「Room 开发顺序」自动选——取**第一个"还没全部做完、且前序 Room 已合入 main"**的 Room 作为本次目标 `<room>`。**若所有 Room 都做完 → 进入「B 轨收尾」**(见下方「B 轨」一节末):清剩余技术 backlog,直到只剩 `needs-human` ticket 才报告并停止。
2. **分支**:确保在 `feat/<room>` 分支上。若不在,自己从最新 main 切一个:
   `git checkout main && git pull && git checkout -b feat/<room>`。**绝不在 main 上开发。**
3. **milestone**:若 `<room>` 还没有 milestone,先用 `feature-room:plan-milestones` 拆出来。
   - 拆分遇 OQ 按升级边界处理:**难撤/定方向的产品决策 → `add_question` + 若阻塞则停**;**技术 + 可逆产品小决定 → 自己定 + `record_decision`**。
   - **拆完不再停下等人**:把 milestone 计划用 `record_decision`(或对应 spec)记到 VibeHub,作为本 Room 的开发计划留痕,然后**直接进入开发**。仅当拆分本身命中**业务/产品** OQ 且阻塞时才停。

## 每一轮

1. **开发**:用 `feature-room:dev` 开发 `<room>` 的下一个还没做的 milestone。
   - dev skill 内部已含 pull context → 开发 → commit-sync。
   - 开发中遇 OQ,按 [`METHODOLOGY.md`](./METHODOLOGY.md) 第一节升级边界(**先看领域,产品再看可逆性**):
     - **技术决策**(含数据模型/schema、对外契约/MCP 签名、**安全边界**、核心选型、跨 Room 抽象,及一切内部实现)→ **自己定**,按可逆性**分级 `record_decision`**(高风险再 `add_constraint` + report 置顶)。
     - **产品·可逆小决定**(纯文案、默认排序/筛选、空状态文案、占位符…,改回来只是一次无迁移小 commit)→ **自己定 + `record_decision`**(一句话理由)。
     - **产品·难撤/定方向**(用户可感知数据语义、不可逆流程、功能取舍/优先级/范围、跨 Room 产品契约)→ `add_question` + 建 issue + 代码留显式 TODO,**不写隐式假设**;阻塞本 milestone → 进熔断停下。
     - **拿不准产品决策可不可逆 → 当难撤上报。** 一律不留半成品 stub。
   - 能在本 milestone 做完的就做完,**别留半成品 stub,别拖到后面 phase**。

2. **review**:对这个 milestone 的改动跑一次审查——用 `/code-review` skill(或 spawn 一个 `general-purpose` Agent 喂审查 prompt)。
   - 发现真问题 → 当场修,再 commit-sync 一个 fixup commit,修干净再继续。
   - 属于业务/产品语义 / 超出本 Room 范围的 → 记 issue,不硬改。

3. **优化(每个 milestone 后,必做一道)**:针对本 milestone 的改动做一次优化,scope 收敛在本 milestone 改动内。
   - **后端改动看**:数据访问/查询、IO/并发、错误处理与边界、复用去重、可读性。
   - **前端改动看**:渲染/重绘开销、包体、状态与数据流、组件复用与一致性、可访问性。
   - 发现就**当场改 + 一个 fixup commit-sync**;改动若触及难撤/定方向的产品决策则停下问人(可逆产品小改自己定+record),超出本 Room 范围则记 issue,不硬改。

4. **验证门**:测试/构建通过才算这个 milestone 完成(dev/commit-sync 内已跑;review + 优化后再复核一次)。**未过不得继续 → 进熔断判断。**

5. **熔断检查**:对照 [`METHODOLOGY.md`](./METHODOLOGY.md) 第三节;命中任一条就停下来给我状态摘要,不要硬继续。

6. **反思 + 建 ticket(每个 milestone 后,必做)**:milestone 收口后,loop 回看刚造的东西,问"哪里值得改、哪里有缺口"——
   性能、重复、可抽象、测试缺口、之前 defer 的尾巴、乃至产品改进点。把**当场没做(超本 milestone scope)但值得做**的,用 `create_ticket` 落进 VibeHub(绑本 Room/相关文件)。规则:
   - **能当场顺手做完的小改 → 不建 ticket,直接在第 3 步优化里改掉**(ticket 只装"要另起一轮才能做"的)。
   - `create_ticket` **没有 type / needs-human 字段**,用**标题前缀**编码:技术类 `[tech-debt]`/`[perf]`/`[refactor]`/`[test-gap]`、**可逆产品小改 `[product-tweak]`** → 都走技术轨自消化;**难撤/定方向的产品点 `[needs-human][product-idea]`** → 等人批。`priority` 用真实枚举 `none`/`low`/`medium`/`high`/`urgent`。
   - **分诊**:`[tech-debt|perf|refactor|test-gap|product-tweak]` → loop 自己消化(进 B 轨 backlog);**`[needs-human]` → 停着等人批,loop 绝不自动做**。拿不准产品点可不可逆 → 当难撤,标 `[needs-human]`。
   - 建之前先 `list_tickets`(`feature_id` = 本 Room,`status: open`)**查重**,别建重复。本轮建的 ticket 写进下一步 report。
   - ⚠️ 别把反思变成无底洞:只为**真有价值**的改进建 ticket,琐碎 nit 走优化当场改或直接放过。

7. **写 report(每轮必做)**:把这一轮做了什么写成一份详细复盘,存到
   `docs/reports/<YYYY-MM-DD>-<room>-<milestone>.md`(目录没有就建)。要写得让没看过
   本轮过程的人也能复原"做了什么、为什么、怎么验证、和 VibeHub 怎么交互的"。**至少包含**:

   - **目标**:本轮的 `<room>` / milestone,以及它在 Room 里的位置(第几个 / 是否末个)。
   - **做了什么**:实现了哪些能力;**逐个列出改/加/删的关键文件**(路径 + 一句话职责),
     必要时标依赖/迁移。
   - **决策(record_decision)**:本轮自决的技术决策,逐条写 **理由 + 依据来源(PRD/spec/
     已有代码/约束)+ 影响范围**。**高风险决策**(数据模型/schema、对外契约/MCP 签名、**安全边界**、
     核心选型、跨 Room 抽象)要**单独置顶、写满**(含考虑过的备选 + 为什么不选 + 关联的 `add_constraint`),
     让人能在 dashboard 一眼审计、必要时否决回滚。若某 OQ 属难撤/定方向产品决策被 defer,注明哪个、为何。
   - **VibeHub / MCP 交互(本轮必记)**:把这一轮调用的 **vibehub.* 及其它 MCP 工具逐条列出**,
     作为审计链路。每条写:工具名 · 入参要点 · 结果/返回 id · 状态。分两类:
       - **pull(读 context)**:`get_feature_context` / `query_why` / `get_team_conventions` /
         `get_file_context` —— 读到了哪些关键 intent/constraint/已有 decision,如何影响了本轮决策。
       - **write(留痕)**:`record_decision` / `add_question` / `add_constraint` / `create_ticket`
         / `report_compliance` —— 标题 + 返回的 decision_id/question_id + **status(如
         `ai_proposed` 待人确认 还是 `confirmed`)**。
     若本轮**未调用**任何 VibeHub 工具,也明写"本轮无 VibeHub 交互"及原因(避免漏记看起来像没做)。
   - **优化**:本轮(milestone 级)优化做了什么——**前端 / 后端各列**改了哪些点、为何、有无可量化收益
     (如减少一次重复查询、组件复用、包体变化)。没做就写"无优化项"及原因。
   - **Hooks / 自动化**:本轮触发或受影响的 hooks 与自动化环节 —— 如 `commit-sync`(一致性检查/
     spec 更新)、`.vibehub/vibehub-hook.mjs`、CI 工作流(是否触发、过没过)、cron/loop 本身的状态。
   - **反思建的 ticket(B 轨)**:本轮 `create_ticket` 落的每条——标题 + 类型 + 优先级 + 返回 ticket_id + 是否 `needs-human`。没建就写"本轮无新 ticket"。
   - **defer**:`add_question` / 建的 issue / 代码里留的 TODO(业务/产品 OQ 或超范围),写清推迟理由。
   - **验证**:跑了哪些命令、**具体测试数/结果**(如 `pytest 67 通过`、`vitest 75`、`svelte-check 0/0`、
     `build ok`);哪些是 GUI/人工目视项(无法 headless 断言的)。
   - **review**:本 milestone 审查发现的真问题(severity)+ 当场修了什么 / defer 了什么。
   - **熔断状态**:有没有命中第 5 步的熔断条件;若有反复失败/打转也写明。
   - **下一步**:下一个 milestone,或该 Room 是否收尾。

   这份 report 跟着本 milestone 的改动一起 commit(commit-sync 时带上),作为**审计留痕**——
   尤其是「决策」与「VibeHub / MCP 交互」两节,要能和 dashboard 上的 decision/constraint 对得上账。

8. **Room 收尾(全做完后,全自动合并到 main)**:当 `<room>` 的所有 PRD milestone 都完成,**loop 自己收尾并合 main,不再等人**:

   0. **限额 drain backlog(B 轨,合 main 前)**:`list_tickets`(`feature_id` = 本 Room,`status: open`)拉清单,**滤掉标题带 `[needs-human]` 的**,在剩下的(技术类 + `[product-tweak]` 可逆产品小改)里按 `priority`(urgent > high > medium)取 **最多 3 条(预算上限,可调)**,逐条当作一个 mini-milestone 跑完整每轮流程(开发→review→优化→验证→反思→report)。
      - **只 drain 非 `[needs-human]` 的**;`[needs-human]`(难撤产品)ticket **跳过、留着等人**。
      - 取完 3 条或本 Room 无技术 ticket 即止——**剩下的留到 backlog,别为清债无限拖延合并**。
   1. **Room 级优化扫描(合 main 前必做,前端 + 后端各一道)**:跨整个 Room 的改动(含上面 drain 的)做两道全局优化——
      - **后端一道**:跨 milestone 的重复、API/错误处理一致性、性能热点、数据访问。
      - **前端一道**:组件复用与一致性、状态/数据流、渲染性能、包体、可访问性。
      - 发现的当场修 + commit-sync;**仅当命中难撤/定方向的产品 OQ 才停下问人**,超范围记 issue。
   2. **全量验证门**:对**整个 Room**(不只最后一个 milestone)跑测试 + 构建,必须**全绿**。
   3. **Room 收尾复盘**:用 `feature-room:room-status` 产出 Room 级复盘,连同上面两道优化的结果写进 report。
   4. **全自动合并到 main**(以上全绿才执行):
      - `git push -u origin feat/<room>`
      - `gh pr create`(标题/正文带 Room 复盘 + 高风险决策清单,**留 GitHub 审计记录**)
      - `gh pr merge --squash --auto`(自测全绿即自动合;若仓库配了 CI,等 CI 绿再合)
      - `git checkout main && git pull`
      - **任一门未过 → 不合**,进熔断,停下输出摘要等人。
   5. 回到 **step 0**,自动选并开始下一个 Room(它会从刚合入的最新 main 切分支)。

做完一个 milestone 进入下一个 milestone;做完整个 Room 就按上面**全自动合并、接着下一个 Room**,直到所有 Room 做完或触发熔断。

> ⚠️ **全自动合 main 的安全完全依赖"验证门是真的"**(测试 + 构建 + CI 能拦住坏代码)**与"熔断真的会停"**。
> 某个 Room 若验证手段不足(关键路径无法 headless 断言),它**不具备无人值守前置条件**——该 Room 退回
> "做完停下、等人 review 合 PR",别硬合(见 METHODOLOGY 第四节)。

---

## B 轨:自省 backlog(反思 → ticket → 消化)

> 让 loop 既消费(A 轨路线图)也生产(自己发现改进、建 ticket、再消化)。**核心约束:产出频繁、消费有界。**
> VibeHub 在这里是真正的工作队列,不只是审计日志。

### 1. 生产(反思 + 建 ticket)——每个 milestone 后

见「每一轮」第 6 步。要点:**当场能顺手做完的走优化(第 3 步)直接改;只有"要另起一轮才能做、且真有价值"的才建 ticket。** 每条 ticket:
- **类型**(标题前缀,`create_ticket` 无原生字段):`[tech-debt]` / `[perf]` / `[refactor]` / `[test-gap]`(技术)、`[product-tweak]`(可逆产品小改)、`[needs-human][product-idea]`(难撤产品)。
- **优先级**(`priority` 字段,真实枚举):`none` / `low` / `medium` / `high` / `urgent`。
- **分诊**:技术类 + `[product-tweak]` → 进 backlog,loop 自消化;**难撤/定方向的产品点 → 标题打 `[needs-human]`,停着等人批**。拿不准可逆性 → 当难撤,标 `[needs-human]`。
- 绑定本 Room(`feature_ids` + 相关 `file_paths`),建前 `list_tickets`(`status: open`)查重。

### 2. 消费(限额 drain)——路线图优先

- **A 轨始终优先**:milestone 与 milestone 之间不停下来清 ticket,主干新功能持续流动。
- **Room 收尾时限额 drain**(见「每一轮」第 8 步第 0 项):`list_tickets`(`feature_id` = 本 Room,`status: open`)盘点,滤掉 `[needs-human]`,在剩下的(技术 + `[product-tweak]`)里按 `priority`(urgent>high>medium)取 **最多 3 条**(预算上限,可调),逐条按完整每轮流程做掉,再走优化扫描 + 全量验证 + 合 main。
  - 取满 3 条 / 无技术 ticket 即止,剩余留 backlog。**绝不为清债无限拖延合并**——这是防"优化无底洞"的硬刹车。
  - `[needs-human]` / 产品类**永远跳过**,只在 dashboard 等你批;你批准后它才会进技术 backlog 被消化。
- 被 drain 的 ticket 当 mini-milestone 对待:单独 commit、写 report、`report_compliance`(若有规则适用),并在收口时把 ticket 标记完成(`record_decision` 注明"ticket <id> 已消化")。

### 3. B 轨收尾——所有 Room 都做完后

step 0 检测到 A 轨清空时,不直接停,而是进入**专门的 backlog 清算**:
- 用 `list_tickets`(`status: open`)盘点全项目剩余 ticket,按 Room 把**非 `[needs-human]` 的**(技术 + `[product-tweak]`)在对应分支(`chore/<room>-backlog`,从最新 main 切)上 drain,同样走"验证全绿 → 自动合 main"。
- 每轮仍带预算上限,逐 Room 推进。
- **直到 `list_tickets` 里只剩 `[needs-human]`** → 报告"A 轨 + 可自消化 backlog 均已清空,剩 N 条难撤产品 ticket 待你确认",然后停止。

> backlog 的查重与盘点统一用 `list_tickets`(可按 `status` / `priority` / `feature_id` 过滤);它本身就是为"create_ticket 前查重 + 盘点 Room backlog"设计的。
> 消化完一条 ticket,在收口的 `record_decision` 里注明"ticket <id> 已消化",并在 dashboard 上把它置为 `done`/`closed`,避免下轮重复 drain。
