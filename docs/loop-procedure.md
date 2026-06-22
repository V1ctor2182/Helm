# Loop 循环流程(每轮执行的标准定义)

> 这是 loop 每一轮要做什么的**权威定义**。配合 [`METHODOLOGY.md`](./METHODOLOGY.md) 使用——
> 决策原则(六条)、单/双向门清单、熔断条件都在那里;本文件只定义"流程"。
> 启动命令见 [`loop-prompt.md`](./loop-prompt.md)。
> 开发约定(commit / 分支 / 验证门 / 项目结构 / 每轮 report)见 [`CONVENTIONS.md`](./CONVENTIONS.md)——**每轮开发前应读到**。

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

1. **选 Room**:若命令指定了 Room 就用它;否则按上面「Room 开发顺序」自动选——取**第一个"还没全部做完、且前序 Room 已合入 main"**的 Room 作为本次目标 `<room>`。若全部做完 → 报告并停止。
2. **分支**:确保在 `feat/<room>` 分支上。若不在,自己从最新 main 切一个:
   `git checkout main && git pull && git checkout -b feat/<room>`。**绝不在 main 上开发。**
3. **milestone**:若 `<room>` 还没有 milestone,先用 `feature-room:plan-milestones` 拆出来。
   拆分遇 OQ 按方法论处理(双向门自己定、单向门/拿不准问我);**拆完停下来让我过一眼再继续**。

## 每一轮

1. **开发**:用 `feature-room:dev` 开发 `<room>` 的下一个还没做的 milestone。
   - dev skill 内部已含 pull context → 开发 → commit-sync。
   - 开发中遇 OQ:双向门自决 + `record_decision`;单向门 / 没依据 → `add_question` + 建 issue + 代码留 TODO,**不写死假设**。
   - 能在本 milestone 做完的就做完,**别留半成品 stub,别拖到后面 phase**。

2. **review**:对这个 milestone 的改动跑一次审查——用 `/code-review` skill(或 spawn 一个 `general-purpose` Agent 喂审查 prompt)。
   - 发现真问题 → 当场修,再 commit-sync 一个 fixup commit,修干净再继续。
   - 属于单向门 / 超出本 Room 范围的 → 记 issue,不硬改。

3. **验证门**:测试/构建通过才算这个 milestone 完成(dev/commit-sync 内已跑;review 后再复核一次)。

4. **熔断检查**:对照 [`METHODOLOGY.md`](./METHODOLOGY.md) 第三节;命中任一条就停下来给我状态摘要,不要硬继续。

5. **写 report(每轮必做)**:把这一轮做了什么写成一份详细复盘,存到
   `docs/reports/<YYYY-MM-DD>-<room>-<milestone>.md`(目录没有就建)。要写得让没看过
   本轮过程的人也能复原"做了什么、为什么、怎么验证、和 VibeHub 怎么交互的"。**至少包含**:

   - **目标**:本轮的 `<room>` / milestone,以及它在 Room 里的位置(第几个 / 是否末个)。
   - **做了什么**:实现了哪些能力;**逐个列出改/加/删的关键文件**(路径 + 一句话职责),
     必要时标依赖/迁移。
   - **决策(record_decision)**:本轮自决的双向门决策,逐条写 **理由 + 依据来源(PRD/spec/
     已有代码/约束)+ 影响范围**;若解决了某个开放单向门,注明是哪个、谁拍板。
   - **VibeHub / MCP 交互(本轮必记)**:把这一轮调用的 **vibehub.* 及其它 MCP 工具逐条列出**,
     作为审计链路。每条写:工具名 · 入参要点 · 结果/返回 id · 状态。分两类:
       - **pull(读 context)**:`get_feature_context` / `query_why` / `get_team_conventions` /
         `get_file_context` —— 读到了哪些关键 intent/constraint/已有 decision,如何影响了本轮决策。
       - **write(留痕)**:`record_decision` / `add_question` / `add_constraint` / `create_ticket`
         / `report_compliance` —— 标题 + 返回的 decision_id/question_id + **status(如
         `ai_proposed` 待人确认 还是 `confirmed`)**。
     若本轮**未调用**任何 VibeHub 工具,也明写"本轮无 VibeHub 交互"及原因(避免漏记看起来像没做)。
   - **Hooks / 自动化**:本轮触发或受影响的 hooks 与自动化环节 —— 如 `commit-sync`(一致性检查/
     spec 更新)、`.vibehub/vibehub-hook.mjs`、CI 工作流(是否触发、过没过)、cron/loop 本身的状态。
   - **defer**:`add_question` / 建的 issue / 代码里留的 TODO(单向门或超范围),写清推迟理由。
   - **验证**:跑了哪些命令、**具体测试数/结果**(如 `pytest 67 通过`、`vitest 75`、`svelte-check 0/0`、
     `build ok`);哪些是 GUI/人工目视项(无法 headless 断言的)。
   - **review**:本 milestone 审查发现的真问题(severity)+ 当场修了什么 / defer 了什么。
   - **熔断状态**:有没有命中第 4 步的熔断条件;若有反复失败/打转也写明。
   - **下一步**:下一个 milestone,或该 Room 是否收尾。

   这份 report 跟着本 milestone 的改动一起 commit(commit-sync 时带上),作为**审计留痕**——
   尤其是「VibeHub / MCP 交互」一节,要能和 dashboard 上的 decision/question 对得上账。

6. **Room 收尾**:若 `<room>` 全做完了,停下来提示我去开 PR 合 main——**不要自己合 main,也不要立刻跳到下一个 Room**(下一个 Room 要从合入后的 main 切分支)。等我把 PR 合进 main 后,下一轮 loop 的 step 0 会自动检测、接着做顺序里的下一个 Room。

做完一个 milestone 进入下一个 milestone;做完整个 Room 就按上面收尾,直到所有 Room 做完或触发熔断。
