# F0 · 平台与桌面外壳（Shell / 基建）

> 来源：新建（以 Odysseus 的 Python 后端为底座）｜优先级：**P0 基建**｜里程碑：M0
> 上级：[PRD 主文档](../00-PRD-Master.md)

这是 Helm 的地基：把两个产品融合成**后端单一语言 = Python**的运行环境、进程模型、存储与设置。其它所有 feature 都建在它之上。

---

## 1. 目标
- 一个 **macOS（Apple Silicon）桌面 App**，双击即用、零配置起步。
- **后端单一技术栈 = Python**（复用 Odysseus / FastAPI），前端为 Web（JS）。
- 以 **Odysseus 现有后端为底座**，把 FanBox 的驾驶舱前端搬入、用 Python 重写其终端/文件后端管道。
- 提供统一的本地存储、设置、生命周期与系统集成。

## 2. 非目标
- 不做 Windows/Linux（首版）、不做云/多用户/账号。
- 不重写 Odysseus 大脑（Deep Research/RAG/记忆/MCP）——原样复用。

---

## 3. 技术栈与选型

> 前提：界面层（xterm 终端、Monaco 编辑器、网页 UI）天生是 Web 技术，无法避免 JS。「单一技术栈」= **后端统一 Python**。

| 层 | 选型 | 说明 |
|----|------|------|
| 后端 | **Python 3.11+ / FastAPI**（复用 Odysseus） | 大脑能力 + 新增驾驶舱后端 |
| 桌面外壳 | **pywebview**（纯 Python）或**极薄 Electron 壳** | 仅开窗 + 加载本地服务；二选一（开放问题） |
| 前端 | **Web（HTML/CSS/JS）**，复用 FanBox + Odysseus 前端 | 经 HTTP/WebSocket 与后端通信 |
| 前端构建 | 沿用现风格（无构建）或 Vite + Svelte（新驾驶舱） | 待定（见主文档开放问题） |
| 终端 | **后端 pty（`pexpect` / 内置 `pty`）+ WebSocket → xterm.js** | 替代 FanBox 的 node-pty 路径 |
| 编辑/diff | **Monaco**（前端，复用 FanBox） | diff、轻编辑、语法高亮 |
| 文件监听 | **watchdog**（Python） | 替代 FanBox 的 Node chokidar |
| 结构化存储 | **SQLAlchemy + SQLite**（复用 Odysseus） | 会话/记忆元数据/设置/项目/研究 |
| 向量 / 检索 | **ChromaDB + fastembed(ONNX)**（复用 Odysseus） | 记忆与 RAG，无需替换 |
| 模型调用 | Odysseus 既有 provider 连接（本地 + API） | 见 F2 |
| Agent 协议 | **MCP**（Odysseus 既有 `mcp_servers/`） | 见 F4/F5 |
| 打包 | **py2app / PyInstaller**，产出自带 Python 的 `.app` | 双击即用，用户无需装 Python |

---

## 4. 进程模型

```
桌面外壳（pywebview / 极薄 Electron 壳）
 └─ 开窗 + 加载 http://127.0.0.1:<port> + 系统集成（截图、通知、托盘）

Python 后端（FastAPI，单进程 / 带 worker）
 ├─ 大脑（复用 Odysseus）
 │   ├─ Chat / 模型路由（F2）
 │   ├─ Deep Research 引擎（F3）
 │   ├─ RAG / 记忆（ChromaDB + fastembed）（F4）
 │   └─ MCP host + 既有 mcp_servers（F4/F5）
 └─ 驾驶舱后端（新增）
     ├─ TerminalManager：pty 会话池，WebSocket 流式（F1/F5）
     ├─ FileService：watchdog 监听 + 读写 + 缩略图（F1）
     └─ GitService：diff / 状态（F1）

Web 前端（JS，复用）
 ├─ 三栏：文件 | 中央(Chat/Research/Diff/Preview) | 终端
 └─ 经 HTTP（REST）+ WebSocket（终端流、文件变更事件）与后端通信
```

- **本地绑定**：后端只绑 `127.0.0.1`，不对外暴露（本地优先）。
- **前端通信适配**：FanBox 前端原走 Electron IPC，需改为调用后端 REST/WebSocket —— 这是搬入驾驶舱的主要机械工作（见 F1）。
- **外壳轻量**：外壳不含业务逻辑，崩溃只影响窗口，可重连后端。

---

## 5. 数据与目录

直接**复用 Odysseus 的数据目录与表结构**，按需扩展驾驶舱相关表。
```
<Odysseus data dir>/
├─ *.db (SQLite via SQLAlchemy)   # sessions, memories, settings, research, + 驾驶舱新增表
├─ chroma/                        # ChromaDB 向量库（记忆 + RAG）
├─ uploads / personal_docs/       # 文档与上传
└─ logs/ , cache/
```
- 用户**项目文件**仍在其原始位置（驾驶舱直接读本地 FS），Helm 不搬动用户文件。
- **导入/导出**：复用/扩展 Odysseus 的备份能力（记忆、设置、会话 JSON 导出）。

### 驾驶舱新增表（概览，细节见各 feature）
- `projects(path, type_badges, last_opened, ...)`（F1）
- `terminal_sessions(id, project_path, agent, started_at, ...)`（F1/F5）
- `file_changes(id, session_id, path, change_kind, ts)`（F1）
- 其余（providers / sessions / messages / memories / documents / research_runs）复用 Odysseus 既有。

---

## 6. 设置（Settings）
- 复用 Odysseus 既有设置体系，整合进新驾驶舱 UI：
  - **模型 / Providers**（F2）、**MCP**（F4/F5）、**RAG 目录**（F4）。
  - **密钥管理**：API key 加密存储（复用 Odysseus 的 `secret_storage`；桌面端可叠加系统钥匙串 / Electron safeStorage）。不明文落库。
  - **外观**：单一干净主题（不保留 FanBox 三套皮肤）。
  - **数据**：导入/导出、清空、数据目录位置。
- **首次启动**：本地优先、无强制登录心智；引导填一个模型即可开始（沿用 Odysseus 首启但简化为单人本地）。

---

## 7. 用户故事
- 作为用户，我双击 Helm 就能用，不需要单独装 Python / 配 venv / 起服务。
- 作为用户，我的密钥安全加密存储，不明文落盘。
- 作为用户，后端重启后，前端能自动重连，不丢当前视图。
- 作为用户，我能一键把记忆/设置导出做备份。

## 8. 验收标准
- [ ] 打包出的 `.app` 在未装 Python 的机器上双击可用。
- [ ] 冷启动到可交互 < 5s。
- [ ] 后端仅绑 `127.0.0.1`，外部无法访问。
- [ ] API key 不出现在数据库明文中。
- [ ] 后端重启后前端自动重连且不崩。
- [ ] 删除数据目录即完全重置。

## 9. 依赖与风险
- 依赖 Odysseus 后端可被作为库/服务整合（已确认是 FastAPI Python，可行）。
- **风险**：
  - 桌面外壳（pywebview / Electron 壳）+ 打包（py2app/PyInstaller）对自带 Python、原生依赖（ChromaDB/onnxruntime）的打包需验证。
  - FanBox 前端从 Electron IPC 迁到 REST/WebSocket 的适配工作量（见 F1）。
