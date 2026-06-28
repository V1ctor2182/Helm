# helm 自动化开发流程 · VibeHub 落地版

> 把通用最佳实践映射到 VibeHub 的真实原语（Feature Room / spec.md / progress.yaml / vibehub.* MCP / Skills），
> 并**明确补上 VibeHub 不负责的两个洞：测试执行门禁 + 隔离（worktree/沙箱）**。
> 配套通用研究报告见 `自动化开发流程研究报告.md`。

---

## 一、VibeHub 覆盖矩阵（先对齐边界）

| 翻车点 | VibeHub 是否覆盖 | 用什么覆盖 | 缺口由谁补 |
|---|---|---|---|
| ① spec 不精确 → 意图漂移/架构腐化 | ✅ **强覆盖** | spec.md 单一真相源；写前 `get_file_context`/`query_why` 拉、写后 `record_decision`/`add_constraint` 固化；commit-sync 的 **anchor tracking** 检测代码↔spec 漂移 | — |
| ② 没有 agent 能跑的验证回路 → 看起来完成就停 / 删测试骗过关 | ⚠️ **只到 spec 层** | commit-sync 只做"改动是否符合 spec/约束"的 quality gate | **我们补**：测试门禁（dev 内自检 + PR 上 CI 干净 checkout）|
| ③ 没隔离 + 没人工 checkpoint | ✅ checkpoint 部分覆盖 / ⚠️ 隔离不覆盖 | room-status Dashboard = 批 plan/审进度；一 Room 一 PR + commit-sync 只 push 不开 PR → 合并天然人工门禁 | **我们补**：git worktree + 沙箱/容器 + 运行时隔离 |

**结论：VibeHub 管"规格一致性 + 流程把关点"，我们管"测试真绿 + 物理隔离"。两边拼起来才是完整护栏。**

---

## 二、完整 Pipeline（贴着 VibeHub Skills）

### 阶段 0 · 地基先行（一次性，人主导，不 loop）
技术栈、目录结构、DB schema、auth、app 骨架、**CI 流水线**、根 `CLAUDE.md`。
- 把这些作为**全局 convention / contract** 写进一个基础 Room 的 spec.md，让后续所有 Room 都能 `get_team_conventions` 拉到。
- CI 必须此时就建好——它是阶段 4 那道"agent 改不到"的测试门禁。

### 阶段 1 · 建 Room + 审规格（人工 Checkpoint A）
- 用 `room` 把 helm 按模块拆成 Feature Room，每个 Room 写 spec.md（intent / constraint / decision / convention / contract）。
- 打开 `room-status` Dashboard，**人工审**：未确认 spec、检测出的 question、Room 之间的边界是否清晰。
- 👉 **这是杠杆最高的关卡**——spec 在这里批准，省下最多返工。VibeHub 在这步帮你把"批 plan"做成了 Dashboard 上的显式动作。

### 阶段 2 · 拆 milestone（开发前）
- 对每个 Room 触发 `plan-milestones`，把 Room 拆成可执行 milestone，写进 progress.yaml。
- 审一眼 milestone：**粒度 ~200 行 / 1–2h、单一垂直切片、依赖清晰**。太大的 milestone 让它再拆。
- 不要跳过这步直接 dev——"一口气写整个 Room"正是翻车源头。

### 阶段 3 · 单 Room 隔离开发循环（← 这里补"隔离"洞）

**进 loop 前，先建隔离环境（VibeHub 不管，我们用脚本）：**
```bash
# 一 Room = 一 worktree = 一分支 = 一沙箱
git worktree add ../helm-<room> -b feat/<room>
# 在容器/沙箱里、用独立端口+独立 DB 启动 agent，避免并行 Room 通过共享服务互相投毒
```

**然后在该 worktree 里按 milestone 推进：**
```
for milestone in Room.progress.yaml:
  1. prompt-gen           # 把你的指令包上完整 Room 上下文(spec/decision/constraint/contract)
  2. dev <milestone>      # 自动 pull context → 开发
       - 开发中做决策 → 当场 record_decision / add_constraint（别只写注释）
  3. ★测试门禁(我们补)★   # 见第三节：测试不绿，不许进 commit-sync
  4. commit-sync          # 唯一提交方式：anchor tracking 查漂移 + 更新 spec + 记 change + 更新进度
```
- 全程**禁止手动 git commit**，禁止绕过 commit-sync。
- 每个 milestone 留干净可合并状态。

### 阶段 4 · 一 Room 一 PR（人工 Checkpoint B + 测试门禁底座）
- Room 的所有 milestone 完成后才开 PR（commit-sync 只 push，不自动 `gh pr create`，所以开 PR 由你决定）。
- **PR 上挂 CI**：lint → 类型 → spec/schema 校验 → 单元/集成 → 端到端 → 覆盖率。
  - 🔒 **CI 在 agent 改不到的干净 checkout 上跑测试**——这是防 reward hacking（删测试/`sys.exit(0)` 骗过关）的关键底座。
- 你 review diff + 看绿 → 合并。`main` 永远绿；出问题 `git revert` + 重新 prompt。

---

## 三、补洞 ①：测试执行门禁（VibeHub 只到 spec 层）

VibeHub 的 quality gate 只验"改动符不符合 spec"，**不验"测试真的绿"**。两层补：

**A. dev 循环内的自检（早暴露，每 milestone）**
- 在每个 Room 的 spec.md 里写一条硬 **constraint**：「milestone 完成定义 = 对应测试存在且全绿；必须贴出测试命令与返回作为证据」。这样 `dev`/`prompt-gen` 拉 context 时 agent 一定看到。
- 加一个 **本地 hook**（Claude Code PreToolUse 风格 / 或包在 dev 流程里）：调用 commit-sync **之前**先跑 `npm test`（或项目测试命令），**非 0 退出码就拦下，不让 commit-sync 执行**。VibeHub 用「MCP + Hooks 强制执行」，这个 hook 正是补在 Hooks 这层。

**B. PR 上的 CI（防作弊底座，Room 级）**
- 干净 checkout 重新跑全套测试 —— agent 在 worktree 里改不到这份。
- 覆盖率门禁（AI 生成代码建议 ~80%）。

**一条铁律（贴进根 CLAUDE.md）：**
> **绝不允许 agent 在无人 review 的情况下，修改它自己这个 milestone 要过的测试。** 警惕「全过但测试文件零 diff / 或测试被删」。

---

## 四、补洞 ②：隔离（VibeHub 不管 worktree/沙箱）

| 隔离层 | 做法 |
|---|---|
| 代码隔离 | 一 Room 一 `git worktree` + 一分支 `feat/<room>`（脚本见阶段 3） |
| 运行时隔离 | 每个 worktree 在独立容器/沙箱里跑，**独立端口 + 独立 DB + 独立 .env** —— worktree 只隔离代码，端口/DB/密钥仍共享，不隔离会让并行 Room 互相投毒 |
| 权限隔离 | 沙箱默认：文件系统只写工作目录 + 网络出站走 allowlist；**不要** `--dangerously-skip-permissions`，除非在断网容器里 |

---

## 五、并行 vs 串行
- 地基 Room、互相依赖的 Room：**串行**。
- 边界清晰、互不依赖的 Room：可**并行**（各自 worktree + 容器 + 端口/DB）。
- 但并行度别贪：**review 是瓶颈**（METR 实证：资深开发者用 AI 反而慢 19% 且不自知，慢在 review/纠正/整合）。同时在飞 3–5 个 Room 已经够你 review。

---

## 六、给 agent 的工作纪律（最终版，贴 CLAUDE.md）

1. 写任何非平凡代码前：先调 `get_file_context` / `get_team_conventions` / `query_why` 拉上下文。
2. 做决策时：`record_decision` / `add_constraint` 当场固化，别只写代码注释。
3. 开发入口：`plan-milestones` → `dev`，**按 milestone 推进，不要一口气写整个 Room**。
4. **提交只能走 `commit-sync`，禁止手动 git commit。**
5. **【补】commit-sync 之前测试必须全绿并贴证据；绝不修改自己这个 milestone 要过的测试（无人 review 时）。**
6. **【补】每个 Room 在自己的 worktree + 沙箱里开发，独立端口/DB。**
7. context 之间 `/clear`；调研丢给 subagent；CLAUDE.md 保持短。

---

## 一句话总览
> **room 建 Room + Dashboard 审 spec（批 plan）→ plan-milestones 拆切片 → 每 Room 独立 worktree+沙箱 →
> prompt-gen + dev 按 milestone 写 →【测试绿才】commit-sync（anchor tracking 防漂移）→
> 一 Room 一 PR + CI 干净 checkout 跑测试（防作弊）→ 你 review 合并。**

VibeHub 负责"规格一致性 + 把关点"，你补"测试真绿 + 物理隔离"——两边拼齐就是安全(隔离+沙箱+双 checkpoint+防作弊测试)、干净(垂直切片+小 PR+spec 同步+干净 git 历史)、高效(spec 精确减返工+可并行+progress.yaml 断点续传)的完整闭环。
