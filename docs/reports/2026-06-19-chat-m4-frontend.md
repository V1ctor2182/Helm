# chat-multimodel · m4 Chat 前端

- **日期**：2026-06-19
- **Room / milestone**：chat-multimodel / m4（Chat 前端 + provider 设置 UI）

## 目标
Svelte Chat UI：会话列表 + 流式渲染 + 模型选择 + stop；provider 设置（列表/添加/测试）。接入 chat 模式。chat-multimodel 末个 milestone。

## 做了什么
- **`chatStore.svelte.ts`**：providers/templates/sessions/current/messages/streaming/error + WS。loadProviders/Templates/addProvider/testProvider、loadSessions/createSession/openSession（fetch）；send（乐观推 user + assistant 占位，经 WS 发 message）、stop、handle（delta 追加到 assistant 占位 / done·stopped 收尾 / error）；#connect 管理 per-session WS（开新关旧 + onclose 兜底清 streaming）。
- **`Chat.svelte`**：左 会话列表 + 新会话（provider/model 选择）+ ⚙Providers；中 消息线程 + 输入 + 发送/停止（streaming 切换）；onMount 卸载时 disconnect。
- **`ProviderSettings.svelte`**：provider 列表（has_key/测试）+ 从模板添加（needs_key 才显示 key，绝不回显）。
- **`Shell.svelte`**：chat 模式中央渲染 `<Chat/>`。
- **测试**：chatStore（loadProviders / openSession+WS / send 流式 delta→占位 / stop+error / streaming 期间 send no-op，用注入的 fake WebSocket）；Chat 渲染（无会话提示 + provider 选项 + 会话列表）。

## 决策（record_decision）
- 流式经注入式 global WebSocket 测试（jsdom 无 WS server）；live 流式 GUI 人工目视。
- 文件命名：store 改 `chatStore.svelte.ts` 避免与 `Chat.svelte` 在大小写不敏感 FS 上冲突。

## defer
- 多模型对比 / 视觉附件（P1）；assistant markdown 渲染、WS 重连、会话删除/重命名 → 后续。

## 验证
- `svelte-check` 0/0；`vitest` **75 通过**（+7）；build ok。后端不变（pytest 71）。
- review（agent）：send 守卫、open-WS-未就绪分支、handle delta（无占位安全丢弃）、runes、ProviderSettings 不回显 key、Shell 接入均确认。修 2 med（切会话 / WS 静默关闭时 streaming 卡 true → openSession 重置 + onclose 兜底）+ 1 low（卸载 disconnect）。
- 一处大小写冲突（chat.svelte.ts↔Chat.svelte）→ 重命名 chatStore，一次修好。

## 熔断状态
- 未命中。

## 下一步（Room 收尾）
- **chat-multimodel 全部 milestone（m1–m4）完成** → 停下等人开 PR 合 main。合入后下一个 Room：`memory-rag-skills`。
