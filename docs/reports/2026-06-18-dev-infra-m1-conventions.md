# dev-infra · m1 团队约定入库

- **日期**：2026-06-18
- **Room / milestone**：dev-infra / m1（团队约定入库）

## 目标
把 METHODOLOGY 的决策闸门 + platform-shell 确立的项目结构约定，沉淀成 agent 与人共用、每轮 loop 都能读到的统一开发标准；填补 `get_team_conventions` 为空的缺口。

## 做了什么
- 新增 **`docs/CONVENTIONS.md`**：决策闸门（六原则 + 单/双向门清单）、commit 约定（conventional + 署名 + 单 milestone 单 commit + scope 收敛）、分支策略、验证门、每轮 report、项目结构约定（config 单一来源 / 仅绑回环 / 存储经 Database / 密钥 SecretBox 不明文 / 路由 routes/ / 测试 hermetic / Electron + PyInstaller+electron-builder / 前端 Vite+Svelte）、代码风格。
- 在 **`docs/loop-procedure.md`** 头部加指向 CONVENTIONS.md 的引用（"每轮开发前应读到"），使 loop 实际能发现它。
- 把进程文档纳入版本管理：`docs/METHODOLOGY.md`、`docs/loop-procedure.md`、`docs/loop-prompt.md`、`docs/CONVENTIONS.md`（此前散在工作区未跟踪）。
- VibeHub：`add_constraint` 两条（commit 规范、每轮写 report）。

## 决策（record_decision / 本轮发现）
- 前端构建栈定为 **Vite + Svelte**（关闭 PRD §7.1 / 开放 spec 8598a660；单向门，用户拍板）。
- **发现**：`get_team_conventions` 无法经现有 MCP 工具写入——`add_constraint` 喂的是 room 的 constraint-spec，不会变成项目级 "rules"（dev-infra 已有 confirmed 约束也不在 get_team_conventions 里）。因此约定的**权威来源 = `docs/CONVENTIONS.md`**，loop 经 loop-procedure.md 的引用 Read 它，而非依赖 get_team_conventions。METHODOLOGY 里"写进 add_constraint 让 get_team_conventions 读到"的说法与当前工具不符。

## defer
- 无新增单向门 defer。已记录的 add_question（macOS Keychain、代码签名）属 platform-shell，未受影响。

## 验证
- 本 milestone 仅改文档，未碰代码；`pytest` 仍 **39 通过**（确认无回归）。
- CONVENTIONS.md 内容与现有代码/决策一致（逐条对照 platform-shell 实现）。

## 熔断状态
- 未命中任何熔断条件。

## 下一步
- m2：CI 工作流（`.github/workflows/ci.yml` 跑 pytest + node --test）。
