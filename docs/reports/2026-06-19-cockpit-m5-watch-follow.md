# cockpit · m5 文件监听 + 活仪表盘 + 跟随模式

- **日期**：2026-06-19
- **Room / milestone**：cockpit / m5（文件监听 + 活仪表盘 + 跟随模式）

## 目标
实时观测 agent 对文件系统的改动：卡片高亮 + 跟随模式（自动预览正在改的文件）。

## 做了什么
- **后端 `watcher.py`**：`DirWatcher`（watchdog Observer，递归，on_any_event→{path,kind}）替代 FanBox chokidar。
- **`models.py`**：`FileChange`（id/session_id?/path/change_kind/ts）。
- **`routes.py`**：`WS /api/cockpit/watch/ws?path=` 流式 `{type:change,path,kind}`。watchdog 线程经 `loop.call_soon_threadsafe` 入 asyncio 队列；先发送（低延迟）后记库（best-effort）；finally 置 closed 标志 + stop 观察者。
- **前端 `cockpit.svelte.ts`**：`changedPaths`(高亮)/`followMode`；`markChanged`(闪 1.5s，按 path 重置计时器)/`applyChange`(标记 + 跟随时预览)/`startWatching`(开 watch WS)/`stopWatching`；openProject 启动监听。
- **`FileBrowser.svelte`**：变更卡片 `.changed` 闪绿动画 + 跟随开关按钮；onDestroy stopWatching。
- 依赖 `watchdog`。
- **测试**：后端 DirWatcher 检测创建 + watch WS 流式&记库；前端 applyChange/markChanged(假时钟)/toggleFollow。

## 决策（record_decision）
- 监听走 watchdog 递归 + WS 流；先发后记保证高亮低延迟。
- 跨线程桥：watchdog 线程仅 call_soon_threadsafe，关闭时 closed 标志 + try/except RuntimeError 防竞态（采纳 review high）。

## defer（add_question）
- file_changes 持久化的**写入节流/批处理**（高频写突发时同步 SQLite 写会阻塞事件循环）+ **表无界增长清理**（P1 replay/inbox 才真正消费）。
- session_id 关联终端会话 → F5；会话回放/变更收件箱 → P1；root 路径跟随、watch WS 重连 → 健壮性后续。

## 验证
- 后端 `pytest` **53 通过**（+2 watcher/WS）；前端 `svelte-check` 0/0、`vitest` **64 通过**（+3）；build ok。
- review（agent）：修 1 high（跨线程关闭竞态 closed+RuntimeError 守护）、broaden except、前端 markChanged 计时器按 path 重置防泄漏。DB 写阻塞 + 无界增长记为节流 follow-up（add_question）。<500ms 高亮 / 跟随保真为人工目视。

## 熔断状态
- 未命中。

## 下一步
- m6：Git diff（GitService + Monaco 只读 DiffEditor，HEAD vs 工作区）。cockpit 最后一个 milestone，完成后收尾开 PR。
