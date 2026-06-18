# Helm 开发约定（团队 conventions）

> 这是 agent 与人共用的**统一开发标准**。每轮 loop 开发前应读到本文件
> （连同 [`METHODOLOGY.md`](./METHODOLOGY.md) / [`loop-procedure.md`](./loop-procedure.md)）。
> METHODOLOGY 讲"为什么/怎么想",本文件讲"具体怎么做"。

## 1. 决策闸门（来自 METHODOLOGY 第一、二节）

遇到 OQ，按顺序判断：

1. **可逆性**：单向门（改起来贵 / 别的模块会建在其上 / commit 后难撤，三者任一）→ 默认 defer，`add_question` + 代码留显式 TODO，不写隐式假设。双向门 → 自己决。
2. **有据可依**：决策只能来自 PRD / VibeHub spec / 已有代码 / 已记录约束。找不到依据 ≠ 猜 → 按单向门 defer。
3. **取舍排序**：安全 > 正确/完整 > 速度。
4. **留痕**：自决的双向门 → `record_decision`（理由 + 依据）；新硬边界 → `add_constraint`。
5. **验证后才提交**：见 §4。
6. **有限爆炸半径**：见 §3。

### 单向门（defer / 问人）
- 数据模型 / 本地存储 schema（会导致迁移的结构）。
- 对外契约：暴露给 Claude Code 的 MCP 工具签名；跨 Room 契约。
- 安全边界：凭据/密钥存储位置与加密、发往外部 provider 的数据、终端 agent 沙箱权限。
- 核心选型：后端框架、桌面外壳、关键第三方依赖、打包方案的最终确定。
- 跨 Room 共享的基础抽象。

### 双向门（自决 + record_decision）
- Room 内部命名、文件/目录组织、helper 实现、测试组织、日志/文案/注释、内部重构。

## 2. Commit 约定

- **单 milestone 单 commit**，便于整段回滚。
- **Conventional commits**：`feat(<room>): mN <简述>` / `fix(...)` / `docs:` / `chore:`。正文写"做了什么 + 关键文件 + 验证结果"。
- 提交信息**结尾署名**：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。
- 只 `git add` 本 milestone 相关文件，**不要顺手提交无关的未跟踪文件**（scope 收敛）。

## 3. 分支策略（来自 METHODOLOGY 原则 6）

- **一个 Room = 一条分支** `feat/<room>`。**绝不在 main 上自动开发。**
- Room 收尾 → 开 PR，**人确认后合 main**（agent 不自动合）。
- **下一个 Room 从合入后的最新 main 切分支**（拿到前序成果）。Room 间串行。

## 4. 验证门（来自 METHODOLOGY 原则 5）

- 提交前必须通过：**测试 + 构建/能启动**。未过不得 commit → 进熔断判断。
- 后端：`pytest`（venv，Python ≥ 3.11）。桌面/前端：`node --test` + `node --check`。
- 没有验证手段的代码不可全自动。

## 5. 每轮写 report（来自 loop-procedure 第 5 步）

- 每轮 loop 在 `docs/reports/<YYYY-MM-DD>-<room>-<milestone>.md` 写一份复盘，
  跟着该 milestone 的改动一起 commit（**纳入版本管理，不进 .gitignore**）。
- 至少含：目标 / 做了什么 / 决策 / defer / 验证 / 熔断状态 / 下一步。

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
