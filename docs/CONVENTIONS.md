# Helm 开发约定（团队 conventions）

> 这是 agent 与人共用的**统一开发标准**。每轮 loop 开发前应读到本文件
> （连同 [`METHODOLOGY.md`](./METHODOLOGY.md) / [`loop-procedure.md`](./loop-procedure.md)）。
> METHODOLOGY 讲"为什么/怎么想",本文件讲"具体怎么做"。

## 1. 决策闸门（来自 METHODOLOGY 第一、二节）

> 档位 = 真·无人值守。**两道判据叠加：先看领域（技术/产品），产品再看可逆性。只有「难撤的产品决策」停下问人。**

遇到 OQ，按顺序判断：

1. **升级边界**：技术决策 → 自己决。产品决策再分——**可逆小决定**（文案/默认排序/空状态文案…，改回来只要一次无迁移小 commit）→ 自己定 + `record_decision`；**难撤/定方向**（用户可感知数据语义 / 不可逆流程 / 功能取舍·优先级·范围 / 跨 Room 产品契约）→ `add_question` + 留显式 TODO，阻塞则熔断停。**拿不准可逆性 → 当难撤上报。**
2. **有据可依**：决策只能来自 PRD / VibeHub spec / 已有代码 / 已记录约束。技术 + 可逆产品小决定找不到依据 → 取最安全/最易回滚解 + 写进 record；只有难撤产品决策无依据才 defer 问人。
3. **取舍排序**：安全 > 正确/完整 > 速度。
4. **留痕（按可逆性分级）**：每个自决决策 → `record_decision`（理由 + 依据）；**高风险技术决策**（见下）→ 写满（+ 备选 + 为何不选）+ `add_constraint` + report 置顶；低风险技术 / 可逆产品小决定 → 一句话理由。
5. **验证后才提交**：见 §4。
6. **有限爆炸半径**：见 §3。

### 需要问人 —— 难撤 / 定方向的产品决策
- 用户可感知的数据语义 / 不可逆流程 / 用户会依赖的产品方向；功能取舍 / 优先级 / 范围；跨 Room 产品契约。

### loop 自决 + 留痕
- **一切技术决策**（高风险：数据模型·schema、对外契约·MCP 签名、安全边界、核心选型、跨 Room 抽象 → 写满 + `add_constraint` + report 置顶；低风险：命名/组织/helper/测试/文案/重构 → 一句话）。
- **可逆的产品小决定**（纯文案/措辞、默认排序/筛选/标签页、空状态文案、占位符、非结构性 UI 默认值）→ 自己定 + `record_decision`（一句话），写进 report，你可在 dashboard 事后否决。

> ⚠️ 安全边界交给 loop 自决，是以「详细留痕 + 熔断」换无人值守的明确取舍 → 这类决策**必须** `add_constraint` + report 置顶，保证 dashboard 可审、可回滚。

## 2. Commit 约定

- **单 milestone 单 commit**，便于整段回滚。
- **Conventional commits**：`feat(<room>): mN <简述>` / `fix(...)` / `docs:` / `chore:`。正文写"做了什么 + 关键文件 + 验证结果"。
- 提交信息**结尾署名**：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。
- 只 `git add` 本 milestone 相关文件，**不要顺手提交无关的未跟踪文件**（scope 收敛）。

## 3. 分支策略（来自 METHODOLOGY 原则 6）

- **一个 Room = 一条分支** `feat/<room>`。**绝不在 main 上自动开发。**
- Room 收尾 → Room 级优化扫描（前端+后端）+ 全量验证全绿 → **全自动合 main**：`git push` → `gh pr create`（留审计）→ `gh pr merge --squash --auto` → `git checkout main && git pull`。**任一门未过则停下等人，不硬合。**
- 某 Room 验证手段不足（关键路径无法 headless 断言）→ 退回「开 PR、人确认后合」，别全自动合（见 METHODOLOGY 第四节）。
- **下一个 Room 从合入后的最新 main 切分支**（拿到前序成果）。Room 间串行。

## 4. 验证门（来自 METHODOLOGY 原则 5）

- 提交前必须通过：**测试 + 构建/能启动**。未过不得 commit → 进熔断判断。
- 后端：`pytest`（venv，Python ≥ 3.11）。桌面/前端：`node --test` + `node --check`。
- 没有验证手段的代码不可全自动。

## 5. 每轮写 report（来自 loop-procedure 第 5 步）

- 每轮 loop 在 `docs/reports/<YYYY-MM-DD>-<room>-<milestone>.md` 写一份详细复盘，
  跟着该 milestone 的改动一起 commit（**纳入版本管理，不进 .gitignore**）。
- 至少含：目标 / 做了什么（逐个关键文件）/ 决策（理由+依据+影响）/
  **VibeHub·MCP 交互（pull 读 context + write 留痕，逐条工具名/入参/返回 id/status）** /
  **Hooks·自动化（commit-sync / vibehub-hook / CI / cron）** / defer / 验证（具体测试数）/
  review 发现 / 熔断状态 / 下一步。详见 [`loop-procedure.md`](./loop-procedure.md) 第 5 步。

## 6. 项目结构约定（platform-shell 已确立，后续 Room 复用）

- **配置单一来源** `helm.config.HelmConfig`（env：`HELM_HOST` / `HELM_PORT` / `HELM_DATA_DIR`）。
  其他模块**不得**自行从 `__file__` 推导路径或硬编码 host。
- **仅绑回环**：只接受字面回环 IP（127.0.0.1 / ::1），拒绝 "localhost" 主机名。本地优先、无鉴权层。
- **存储**经 `helm.db.Database`（engine + `session_scope`）访问；路由用 `helm.app.db_session` 依赖拿 `Session`，不直接碰 engine。ORM 模型继承 `helm.db.Base`。
- **密钥**：API key 必须经 `helm.crypto.SecretBox`（Fernet）加密，**绝不明文落库**；存独立 `secrets` 表（仅密文）。
- **路由**放 `helm/routes/`，由 `helm.app.create_app` include；feature room 往这里加自己的 router。
- **测试**用临时 data dir（`config` fixture / `HELM_DATA_DIR`）保持 hermetic，绝不写真实 `~/Library/Application Support`。
- **桌面外壳** = 极薄 Electron（`desktop/`，纯函数逻辑放 `backend.js` 可单测）；**打包** = PyInstaller sidecar + electron-builder。
- **前端构建栈** = Vite + Svelte（新驾驶舱 UI）。

## 7. 代码风格

- 写得像周围的代码：匹配既有命名、注释密度、惯用法。
- 注释解释"为什么"，不复述"是什么"。
- 复用 Odysseus 成熟能力时**直接搬代码、不重写**（platform-shell 只负责地基；大脑能力按 room 引入）。

## 8. 优化（前端 + 后端，两个层级）

> 优化是 loop 的固定动作，不是可选项。改完的当场修 + commit-sync；触及难撤/定方向的产品决策才停下问人（可逆产品小改自己定+record），超本 Room 范围记 issue。

- **每个 milestone 后（轻量，scope 限本 milestone 改动）**：
  - 后端：数据访问/查询、IO/并发、错误处理与边界、复用去重、可读性。
  - 前端：渲染/重绘开销、包体、状态与数据流、组件复用与一致性、可访问性。
- **Room 收尾前（全局，跨整个 Room，合 main 前必做，前端 + 后端各一道）**：
  - 后端：跨 milestone 重复、API/错误处理一致性、性能热点、数据访问。
  - 前端：组件复用与一致性、状态/数据流、渲染性能、包体、可访问性。
- 优化结果写进每轮 report 的「优化」节（前端/后端各列改了什么、为何、有无可量化收益）。

## 9. Ticket / 自省 backlog（B 轨，来自 loop-procedure「B 轨」一节）

> A 轨（PRD 路线图）是主干、默认最高优先级；B 轨是 loop 自己反思产生的工作队列。**产出频繁、消费有界。**

- **每个 milestone 后反思**：当场顺手能改的走 §8 优化直接改；**只有"要另起一轮且真有价值"的才 `create_ticket`**（绑本 Room `feature_ids` + `file_paths`，建前 `list_tickets`(`status: open`)查重，别重复）。
- `create_ticket` **无 type / needs-human 字段** → 用**标题前缀**编码类型：技术 `[tech-debt]`/`[perf]`/`[refactor]`/`[test-gap]`、可逆产品小改 `[product-tweak]`、难撤产品 `[needs-human][product-idea]`；`priority` 用真实枚举 `none`/`low`/`medium`/`high`/`urgent`。
- **分诊**：技术类 + `[product-tweak]` → 进 backlog，loop 自消化；**难撤/定方向的产品点 → 标题打 `[needs-human]`，停着等人在 dashboard 批，loop 绝不自动做**（拿不准可逆性 → 当难撤标 `[needs-human]`）。
- **消费**：A 轨优先；**Room 收尾时限额 drain**（`list_tickets` 滤掉 `[needs-human]`，剩下的按 priority 取**最多 3 条**，预算上限可调）→ 取满即止，剩余留 backlog，**不为清债拖延合并**。
- 被 drain 的 ticket 当 mini-milestone：单独 commit + report；收口 `record_decision` 注明"ticket &lt;id&gt; 已消化"，并在 dashboard 把 ticket 置 `done`/`closed`。
- 所有 Room 做完后进入 B 轨收尾：在 `chore/<room>-backlog` 分支清各 Room 剩余技术 ticket，直到 `list_tickets` 只剩 `[needs-human]`。
