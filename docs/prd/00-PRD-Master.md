# Helm — PRD 主文档（总目录）

> **Helm**（船舵）：把 **FanBox 的 Coding Agent 驾驶舱** 与 **Odysseus 的 AI 工作台大脑** 融合成一个**单一技术栈、本地优先**的个人 AI workspace。
>
> 一句话：*左手掌舵本地项目与编程 agent，右手有一个会研究、有记忆、能调任意模型的大脑——同一个窗口，同一套代码。*

---

## 0. 文档说明

本 PRD 采用「**一个主文档 + 每个 feature 一个文档**」的结构：

- 本文件是**总目录**：愿景、定位、用户、范围、架构决策、feature 索引、路线图、风险。
- 每个 feature 的细节（用户故事、交互、数据模型、接口、验收标准）放在 [`features/`](./features/) 下独立文档。
- 改动原则：feature 的细节变更只改对应 feature 文档；只有跨 feature 的结构性变更才改本文档。

### Feature 索引

| ID | Feature | 来源 | 优先级 | 文档 |
|----|---------|------|--------|------|
| F0 | 平台与桌面外壳（Shell / 基建） | 新（Odysseus 底座） | P0 基建 | [F0-platform-shell.md](./features/F0-platform-shell.md) |
| F1 | Coding Agent 驾驶舱 | FanBox | P0 | [F1-cockpit.md](./features/F1-cockpit.md) |
| F2 | Chat 与多模型 | Odysseus | P0 | [F2-chat-multimodel.md](./features/F2-chat-multimodel.md) |
| F3 | Deep Research | Odysseus | P1 | [F3-deep-research.md](./features/F3-deep-research.md) |
| F4 | 记忆 / RAG / Skills（含 MCP 能力层） | Odysseus | P1 | [F4-memory-rag-skills.md](./features/F4-memory-rag-skills.md) |
| F5 | Agent 编排与工具（融合粘合层） | 新（融合） | P0 | [F5-agent-orchestration.md](./features/F5-agent-orchestration.md) |
| F6 | 日记 / 速记 / 任务（个人记录） | Odysseus + 新增日记 | P1 | [F6-journal-notes-tasks.md](./features/F6-journal-notes-tasks.md) |
| F7 | 邮件 / 日历 | Odysseus | P2 | [F7-email-calendar.md](./features/F7-email-calendar.md) |
| F8 | 工作台布局与导航（统一入口 / IA） | 新（融合 UX） | P0 | [F8-workspace-layout-navigation.md](./features/F8-workspace-layout-navigation.md) |

> P0 = MVP 必须；P1 = 紧随其后的第一批增量。

### 参考代码（本地）

两个来源项目的**完整源码**作为只读参考放在本仓库的 `reference/` 下（**不纳入 git**，见 `.gitignore`，仅本地存在）：

| 项目 | 路径 | 角色 |
|------|------|------|
| **Odysseus** | `reference/odysseus-dev/` | 大脑底座（FastAPI / Python） |
| **FanBox** | `reference/fanbox-master/` | 驾驶舱（Electron / Node） |

> 各 feature 文档里提到的源文件——Odysseus 的 `deep_research.py`、`rag_*`、`memory*`、`mcp_servers/`、`note_routes.py`、`task_scheduler.py`、`email_routes.py`、`calendar_routes.py` 等；FanBox 的 `server.js`、`electron/main.js` 等——均位于上述参考目录下：Odysseus 路径相对 `reference/odysseus-dev/`，FanBox 路径相对 `reference/fanbox-master/`。

---

## 1. 愿景与问题

### 1.1 痛点
今天的真实工作流是割裂的：

- **找项目**：AI 一下午起十个项目，散落各处、名字认不出（FanBox 要解决的）。
- **指挥 agent**：在 iTerm 里跑 Claude Code / Codex，看不清它碰过哪些文件、改了哪几行。
- **用大脑**：想做深度研究、查历史记忆、调不同模型，又得切到 ChatGPT / Claude / 另一个网页工作台。

三个能力散在三类工具里，来回切窗口。

### 1.2 愿景
**Helm = 一个本地桌面 App，既是编程 agent 的驾驶舱，又是有研究/记忆/多模型能力的 AI 大脑。**

- **驾驶舱**（来自 FanBox）：浏览/预览/轻改本地文件、内嵌真实终端跑任意 coding agent、实时看 agent 改了什么。
- **大脑**（来自 Odysseus）：多模型 Chat、自主迭代的 Deep Research、持久记忆 + RAG + Skills。
- **粘合**：驾驶舱里的 agent 能通过 MCP 调用大脑的能力；大脑产出的研究/记忆能直接落到你正在做的项目里。

### 1.3 不做什么（明确排除）
- ❌ 云端 / 远程 / 多租户 / 账号体系（个人本地优先）。
- ❌ 团队协作、权限矩阵、SSO。
- ❌ 不跟 Finder 拼文件管理、不跟 VS Code 拼重度编辑（驾驶舱只做「找回 + 预览 + 轻改 + 指挥 agent」）。
- ❌ 移动端 / PWA（首版只做 macOS 桌面）。

---

## 2. 定位与目标

- **定位**：个人日常用的本地 AI 驾驶舱（single-user，local-first，零配置可用）。
- **平台**：首版 **macOS（Apple Silicon）**，Electron 桌面 App。
- **设计原则**：
  1. **本地优先**：数据、模型连接、索引都在本机；不强制联网、不强制登录。
  2. **零配置起步**：双击即用；模型、搜索、密钥都在设置里渐进配置。
  3. **一个窗口**：驾驶舱 + 大脑同窗，不再来回切。
  4. **可观测**：agent 干的每件事（改文件、调工具、跑研究）都看得见、可回放、可接管。
  5. **一两步够到一切**：所有功能经「命令面板 ⌘K + 精简模式栏 + Today 主页」最多两步可达，详见 [F8 工作台布局与导航](./features/F8-workspace-layout-navigation.md)。

### 成功标准（个人版，务实口径）
- 能在 Helm 一个窗口里：找到任意本地项目 → 内嵌终端跑 Claude Code → 实时看它改了哪些文件并 diff。
- 能在同窗口对任意已配置模型发起 Chat / 模型对比。
- 能发起一次 Deep Research 并得到带引用的可视化报告。
- agent 在终端里能通过 MCP 读到我的记忆 / RAG 文档。
- 冷启动到可用 < 5 秒；大文件夹浏览点击响应 < 0.1s（沿用 FanBox 体验基线）。

---

## 3. 目标用户与场景

**主用户：你自己**（重度使用 AI coding agent、需要研究/记忆能力的开发者）。

核心场景：
1. **找回 + 接管**：⌘K 搜到上周 AI 起的某个项目 → 看历史会话 → 「续上」一键 `claude --resume`。
2. **盯着 agent 干活**：跟随模式看 agent 写到哪、HTML 实时渲染、写完看 git diff。
3. **边写边研究**：在大脑侧发起 Deep Research，结论/片段直接喂给驾驶舱里的 agent。
4. **长期记忆**：跨会话、跨项目的偏好与决策沉淀为记忆，agent 随时能调。

---

## 4. 架构决策（核心）

> 把两个产品融合成「**一个后端语言 = Python**」的关键决策，详见 [F0-platform-shell.md](./features/F0-platform-shell.md)。
>
> **重要前提**：界面（终端 xterm、编辑器 Monaco、网页 UI）天生是 Web 技术（HTML/CSS/JS），两边都躲不掉。因此「单一技术栈」指的是**后端统一为 Python**，前端为 Web/JS。

### 4.1 技术栈：Python 后端 + Web 前端 + 桌面外壳
**决策：后端统一用 Python（复用 Odysseus），前端为 Web（JS），打包成桌面 App。**

理由（让"最有价值、最复杂"的代码免于重写）：
- 大脑（Deep Research、RAG、记忆、MCP server、模型连接）是 Odysseus 已有的**成熟 Python 代码**，也是最复杂、最值钱的部分 → **原样复用，不重写**。
- 驾驶舱的精华（实时高亮、跟随渲染零白闪、会话回放）都在**前端 JS** 里 → 不管后端什么语言都保得住。
- 驾驶舱需要的"机械管道"（真实终端、文件监听）Python 同样能做：`pexpect` / 内置 `pty` + `watchdog`；终端用「后端 pty + WebSocket → xterm.js」。
- 结论：**后端选 Python**，既原样保住大脑，又能承载驾驶舱；只需重写驾驶舱的后端管道（机械活）。

### 4.2 融合策略：Odysseus 当底座，把 FanBox 驾驶舱搬进来
**「重写」集中在机械管道，不碰最值钱的代码**：
- **底座**：Odysseus（FastAPI Python 后端 + Web UI）直接作为 Helm 的基础，大脑能力（`deep_research.py`、`rag_*`、`memory*`、`mcp_servers/`、模型连接）原样复用。
- **搬入**：FanBox 的**前端**（文件卡片/预览、xterm 终端、Monaco diff、跟随/回放逻辑）移植进来，作为新的驾驶舱模块。
- **重写**：FanBox 原本依赖 Node/Electron 的部分 → 用 Python 重做：终端 pty 管理、文件监听、把前端通信从 Electron IPC 改为 HTTP/WebSocket。
- **结果**：一个 Python 代码库 + Web 前端；Odysseus 能力原样保留，FanBox 驾驶舱被吸收。

### 4.3 进程与模块（高层）
```
┌─ 桌面外壳（pywebview 或极薄 Electron 壳）──────────────────┐
│  仅负责开窗口 + 加载本地 Python 服务的 Web UI + 系统集成     │
├─ Python 后端（Odysseus / FastAPI，复用 + 扩展）───────────┤
│  大脑（复用）：Chat/模型路由 · Deep Research · RAG/记忆      │
│              (ChromaDB+fastembed) · MCP host/既有 servers    │
│  驾驶舱后端（新增）：pty 终端管理(pexpect) · 文件监听(watchdog)│
├─ Web 前端（JS，复用 FanBox + Odysseus 前端）──────────────┤
│  左：文件浏览/预览  ·  中：Chat/Research/Diff  ·  右：终端   │
│  ↔ 经 HTTP/WebSocket 与 Python 后端通信                     │
└──────────────────────────────────────────────────────────┘
```

### 4.4 数据与存储
- 直接**复用 Odysseus 现有存储，无需替换**：
  - **结构化**：SQLAlchemy + SQLite（会话、记忆元数据、设置、研究记录）。
  - **向量 / 检索**：ChromaDB + fastembed(ONNX)（记忆与 RAG）。
- **文件**：直接读用户本地文件系统（驾驶舱）；项目内 `素材/` 存截图等附件。
- 应用数据默认落 Odysseus 的数据目录，本地、可备份、可导出。

### 4.5 关键风险点
- **驾驶舱前端适配**：FanBox 前端原走 Electron IPC，需改为 HTTP/WebSocket 与 Python 后端通信 —— 机械但有工作量（见 F1）。
- **桌面外壳与打包**：Python 桌面外壳（pywebview / 极薄 Electron 壳加载本地 Python 服务）的"原生感"与打包略逊于纯 Electron；用 py2app / PyInstaller 打出**自带 Python 的 `.app`**，仍可双击即用（见 F0）。
- **终端体验保真**：node-pty → Python pty + WebSocket 时需保住低延迟与交互保真（见 F1/F5）。

完整架构、技术选型、目录结构见 **[F0-platform-shell.md](./features/F0-platform-shell.md)**。

---

## 5. 范围（MVP vs 后续）

### MVP（第一个能日常用的版本）
- F0 平台外壳（窗口、终端、文件监听、本地存储、设置）
- F8 工作台布局与导航（三栏外壳 + ⌘K 命令面板 + 模式栏 + 全局速记）
- F1 驾驶舱（文件浏览/预览、内嵌终端、跟随模式、git diff —— 核心子集）
- F2 Chat + 至少 1 个模型 provider（OpenAI 兼容 / Ollama）
- F5 Agent 编排基础（终端跑外部 CLI + MCP client 接通 F4 的能力）

### 紧随其后（P1）
- F3 Deep Research（含可视化报告）
- F4 记忆 / RAG / Skills 完整版 + 把它们做成 MCP server 供终端 agent 调用
- F6 日记 / 速记 / 任务（复用 Odysseus 笔记+定时任务 + 新增日记视图）
- F1 驾驶舱进阶（会话回放、变更收件箱、项目记忆、AI 整理、截图直通）
- F2 多模型对比

### 更后续（P2）
- F7 邮件 / 日历（复用 Odysseus 的 AI 邮件分诊 + CalDAV 日历；排在核心与 F6 之后）

### 暂不做
- 发版向导、磁盘占用透视、Skills 用量（FanBox 有；P2 backlog）
- 图像编辑、TTS/STT 等 Odysseus 扩展（backlog，按需再纳入）

---

## 6. 路线图（里程碑）

| 里程碑 | 内容 | 产出 |
|--------|------|------|
| **M0 地基** | 以 Odysseus 为底座跑起来；加桌面外壳（webview）；F8 外壳骨架（三栏 + 模式栏 + ⌘K 命令面板雏形） | 能启动的桌面壳 + 现有大脑 |
| **M1 驾驶舱** | F1 核心：文件浏览/预览 + Python pty 终端 + 跟随 + git diff（前端搬入 + 后端管道）；F8 全局速记 + Today 主页雏形 | 可指挥 agent 并看改动 |
| **M2 大脑·Chat** | F2：整合 Odysseus 既有模型连接 + Chat UI 进新壳 | 同窗口能 Chat |
| **M3 大脑·记忆/RAG** | F4：复用 Odysseus 记忆/RAG（ChromaDB）+ 既有 MCP server 接通终端 agent | 终端 agent 能调记忆/RAG |
| **M4 大脑·研究** | F3：整合 Odysseus Deep Research 引擎 + 报告视图 | 一键深度研究 |
| **M4.5 记录** | F6：复用 Odysseus 笔记/定时任务 + 新增日记视图与全局速记入口 | 能写日记/速记/管任务 |
| **M5 打磨** | 驾驶舱进阶（回放/收件箱/项目记忆）、单一主题、设置完善、打包 .app | 日常主力可用 |
| **M6 邮件/日历** | F7：整合 Odysseus 邮件 AI 分诊 + CalDAV 日历（P2，可后置） | 收信看日程同窗 |

---

## 7. 开放问题（待确认）
1. 前端：沿用 **vanilla JS（FanBox / Odysseus 现风格，无构建）** 还是为新驾驶舱 UI 引入轻框架（Vite + Svelte）？（建议：大脑侧复用现有 vanilla 页面，新驾驶舱可酌情上轻框架；待定）
2. 桌面外壳选型：**pywebview（纯 Python）** vs **极薄 Electron 壳加载本地 Python 服务**？（影响打包与"原生感"，见 F0）
3. 打包工具：py2app vs PyInstaller（产出自带 Python 的 `.app`，双击即用）。

> **已定**：①后端单一技术栈 = **Python**（以 Odysseus 为底座，原样复用大脑）；②不保留 FanBox 三套皮肤，单一干净主题。

---

## 8. 术语
- **驾驶舱 / Cockpit**：FanBox 提供的「文件 + 终端 + 实时观测 agent」界面。
- **大脑 / Brain**：Odysseus 提供的 Chat / Research / 记忆 / RAG 能力集合。
- **MCP**：Model Context Protocol，让终端里的 agent（Claude Code/Codex）调用 Helm 大脑能力的标准接口。
- **跟随模式 / Follow mode**：文件视图与预览自动跟踪 agent 正在编辑的文件。
