# chat-multimodel · m3 流式 Chat 后端

- **日期**：2026-06-19
- **Room / milestone**：chat-multimodel / m3（sessions/messages + 流式 Chat WS）

## 目标
多会话流式对话：会话/消息持久化、WS 流式 + 中断(stop)、重启后完整恢复（含模型/系统提示词，约束 e9ddc41a）。

## 做了什么
- **`models.py`**：`ChatSession`（kind/title/project_path/provider_id FK/model/system_prompt/created_at）、`Message`（session_id FK+index/role/content/ts）。presets 待 m4。
- **`sessions.py`**：`ChatService`（create/list/get_session/messages/add_message）+ session_public/message_public。
- **`routes.py`**：
  - REST：POST /api/sessions（校验 provider 存在）、GET /api/sessions、GET /api/sessions/{id}（session + messages，**恢复**）。
  - **WS /api/chat/ws?session_id=**：协议 client {message|stop} ↔ server {delta|done|stopped|error}。持久化 user 即时、assistant 在 done/stop/error(partial) 落库；snapshot 会话/provider 字段后解密 key；stop 用 Event 标志（token 间生效，best-effort）。
- **测试**：session CRUD（含 provider 404 / session 404）、WS 流式→"Hello"+持久化+恢复(user/assistant)、未知 session 关闭、stop（best-effort 接受 done/stopped + assistant 落库）。

## 决策（record_decision）
- 流式协议走 WebSocket（与终端/监听一致，天然带 stop 控制）；stop 为 token 间 best-effort（model 思考时不即时打断，记为可接受）。
- snapshot-then-detach 读会话/provider 字段，避免 DetachedInstanceError；history 按 Message.id 排序保证顺序。

## defer
- presets 表 + UI → m4；前端 → m4；重试/退避、token 计数、附件/视觉、多模型对比 → 后续。

## 验证
- 后端 `pytest` **71 通过**（+4 m3）。
- review（agent，硬查并发/持久化）：snapshot-detach、history 顺序、三出口持久化、DecryptionError、未知会话关闭、恢复顺序均确认。修 1 high（重叠 turn 竞态 + 泄漏前 task → 加"一次一 turn"守卫）+ 2 med（finally await 取消的 task；run_turn 的 send 包 WebSocketDisconnect/RuntimeError 防 send-after-close）。同步 SQLite 在事件循环（本地单用户可接受，记 note）。

## 熔断状态
- 未命中。

## 下一步
- m4：Chat 前端（Svelte 会话列表 + 流式渲染 + 模型选择 + stop）+ provider 设置 UI；接入 chat 模式。chat-multimodel 最后一个 milestone，完成后收尾开 PR。
