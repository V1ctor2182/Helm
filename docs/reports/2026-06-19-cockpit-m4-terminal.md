# cockpit · m4 内嵌终端（pty + WebSocket → xterm.js）

- **日期**：2026-06-19
- **Room / milestone**：cockpit / m4（内嵌真实终端）

## 目标
在驾驶舱里嵌真实终端：后端 Python pty 起 shell，经 WebSocket 流式到前端 xterm.js，在选定项目目录运行命令。

## 做了什么
- **后端 `terminal.py`**：`PtyProcess`（os.openpty + Popen，非阻塞 master fd，write/resize(TIOCSWINSZ)/read(None=无数据/b""=EOF)/poll/close）。**close() 现 reap 子进程**（terminate→wait→必要时 kill）防僵尸。
- **`models.py`**：`TerminalSession`（id/project_path/agent/started_at；agent 由 F5 设）。
- **`routes.py`**：`WS /api/cockpit/terminal/ws?path=&cols=&rows=`。协议（JSON 双向）：client `{input|resize}`、server `{output|exit}`。loop.add_reader(master)→队列→pump 发送；receive 循环写 pty；EOF→exit；finally remove_reader+cancel+close。连接即记 TerminalSession。
- **前端 `termClient.ts`**（纯函数）：inputMsg/resizeMsg/parseServer/terminalWsUrl。`Terminal.svelte`：xterm + FitAddon，WS 双向桥接，onDestroy 清理；Shell 终端面板在 cockpit 模式渲染（`{#key cwd}` 换项目重建）。
- 依赖 `@xterm/xterm` + `@xterm/addon-fit`。
- **测试**：后端 PtyProcess echo 往返 + **真实 WS 终端**（连接/echo/收输出/记 session）；前端 termClient 3。

## 决策（record_decision）
- 终端 WS 线格式（cockpit 内部，两向门）：JSON `{input|resize}` ↔ `{output|exit}`，已记录。跨 Room 契约是 terminal_sessions schema（m1 已按 F0 §5 定）。
- WS 无鉴权（回环单用户）；spawn argv 列表（非 shell 串，无注入）；cwd 经 is_dir 校验。

## defer
- 多终端 tab/会话池、会话持久化/resume（P1）、agent 启动（claude/codex，F5）、终端↔文件监听联动（m5）。

## 验证
- 后端 `pytest` **51 通过**（+2：pty 往返 + WS 终端）；前端 `svelte-check` 0/0、`vitest` **61 通过**（+3）；build ok（xterm 增重，预期）。
- review（agent）：修 1 high（close() 加 reap 防僵尸）；EOF 语义/双 remove_reader 守护/send 失败路径/前端 dispose/重建/安全（无注入、回环无鉴权）均确认。xterm 实际渲染为人工目视。

## 熔断状态
- 未命中。

## 下一步
- m5：文件监听 + 活仪表盘 + 跟随模式（watchdog → file_changes → WS → 卡片高亮 + 跟随）。
