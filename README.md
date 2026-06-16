# Helm 🛥️

> 把 **FanBox 的 Coding Agent 驾驶舱** 与 **Odysseus 的 AI 工作台大脑** 融合成一个
> **Python 后端、本地优先**的个人 AI workspace（前端为 Web，打包成桌面 App）。

*左手掌舵本地项目与编程 agent，右手有一个会研究、有记忆、能调任意模型的大脑 —— 同一个窗口，同一套代码。*

---

## 现状

📄 **规划阶段** —— 目前仓库里是 PRD 文档，尚无代码。

## 文档导航

PRD 采用「一个主文档 + 每个 feature 一个文档」结构：

- **[PRD 主文档（总目录）](./docs/prd/00-PRD-Master.md)** —— 愿景、定位、架构决策、feature 索引、路线图、风险。
- Features：
  - [F0 · 平台与桌面外壳](./docs/prd/features/F0-platform-shell.md)（基建）
  - [F1 · Coding Agent 驾驶舱](./docs/prd/features/F1-cockpit.md)（来自 FanBox）
  - [F2 · Chat 与多模型](./docs/prd/features/F2-chat-multimodel.md)（来自 Odysseus）
  - [F3 · Deep Research](./docs/prd/features/F3-deep-research.md)（来自 Odysseus）
  - [F4 · 记忆 / RAG / Skills](./docs/prd/features/F4-memory-rag-skills.md)（来自 Odysseus，含 MCP 能力层）
  - [F5 · Agent 编排与工具](./docs/prd/features/F5-agent-orchestration.md)（融合粘合层）
  - [F6 · 日记 / 速记 / 任务](./docs/prd/features/F6-journal-notes-tasks.md)（来自 Odysseus + 新增日记）
  - [F7 · 邮件 / 日历](./docs/prd/features/F7-email-calendar.md)（来自 Odysseus，P2）

## 核心决策速览

| 维度 | 决策 |
|------|------|
| 融合深度 | 单一后端语言重写 |
| 技术栈 | **Python 后端（FastAPI）+ Web 前端 + 桌面外壳** |
| 策略 | 以 **Odysseus（Python）为底座**，把 **FanBox 的驾驶舱前端搬入**，用 Python 重写其终端/文件后端管道 |
| 大脑代码 | Deep Research / RAG / 记忆 / MCP **原样复用，不重写** |
| 定位 | 个人日常用、本地优先、零配置 |
| 平台 | macOS（Apple Silicon）首发 |

## 来源项目（参考代码）

两个来源项目的**完整源码**作为只读参考放在 `reference/` 下（**不纳入 git**，仅本地存在）：

- **Odysseus** —— 自托管 AI 工作台（Python / FastAPI）。大脑底座。路径：`reference/odysseus-dev/`
- **FanBox** —— Coding Agent 驾驶舱（Electron / Node，MIT）。路径：`reference/fanbox-master/`
