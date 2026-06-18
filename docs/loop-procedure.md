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

5. **写 report(每轮必做)**:把这一轮做了什么写成一份复盘,存到
   `docs/reports/<YYYY-MM-DD>-<room>-<milestone>.md`(目录没有就建)。至少包含:
   - **目标**:本轮的 `<room>` / milestone。
   - **做了什么**:实现了哪些能力、改/加了哪些关键文件。
   - **决策**:本轮 `record_decision` 的双向门决策(理由 + 依据)。
   - **defer**:`add_question` / 建的 issue / 代码里留的 TODO(单向门或超范围)。
   - **验证**:测试 / 构建结果(过没过)。
   - **熔断状态**:有没有命中第 4 步的熔断条件。
   - **下一步**:下一个 milestone,或该 Room 是否收尾。
   这份 report 跟着本 milestone 的改动一起 commit(commit-sync 时带上),作为审计留痕。

6. **Room 收尾**:若 `<room>` 全做完了,停下来提示我去开 PR 合 main——**不要自己合 main,也不要立刻跳到下一个 Room**(下一个 Room 要从合入后的 main 切分支)。等我把 PR 合进 main 后,下一轮 loop 的 step 0 会自动检测、接着做顺序里的下一个 Room。

做完一个 milestone 进入下一个 milestone;做完整个 Room 就按上面收尾,直到所有 Room 做完或触发熔断。
