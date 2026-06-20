# chat-multimodel · m2 Provider adapters

- **日期**：2026-06-19
- **Room / milestone**：chat-multimodel / m2（Provider adapters + 连通性测试）

## 目标
薄 provider adapters：流式 Chat + 连通性 ping/模型发现，覆盖 Anthropic（默认）+ OpenAI 兼容（OpenAI/OpenRouter/Ollama/通用）。

## 做了什么
- **`helm/chat/adapters.py`**（raw httpx，刻意 provider-neutral 不用 anthropic SDK）：
  - `chat_stream`：Anthropic（POST /v1/messages，x-api-key + anthropic-version，SSE content_block_delta）/ OpenAI 兼容（POST /chat/completions，Bearer，SSE choices[].delta.content）。**只发 model/system/messages/max_tokens/stream，不发 temperature/thinking**——跨模型版本通用（Opus 4.7/4.8 拒绝采样参）。
  - `ping`：GET /v1/models（Anthropic）或 /models（兼容）→ 模型 id 列表。
  - SSE delta 抽取为纯函数（anthropic_text/openai_text，可单测）；client 可注入（测试）或自建自关。
- **`routes.py`**：`POST /api/providers/{id}/test` → 解密 key + ping，返回 {ok, models} 或 {ok:false, error}。
- **`service.py`**：ollama 模板 base_url 改 `…:11434/v1`（OpenAI 兼容端点）；delete 加 flush 对称。
- **依赖**：httpx 提为运行时依赖。
- **claude-api skill**：Anthropic 端点/头/SSE/模型 id（claude-opus-4-8 等）按 skill 写。
- **测试**：SSE 抽取、Anthropic 流→"Hello"、OpenAI 流→"foobar"、ping 列模型（均用 httpx.MockTransport）、/test 404 / 成功（mock ping）/ 错误→{ok:false}。conftest 加 anyio_backend=asyncio。

## 决策（record_decision）
- raw httpx 多 provider abstraction（非单 provider Anthropic app），不用 anthropic SDK 以保持统一流式接口——契合"全新精简 adapters"决策。
- 不发采样参/thinking，保证跨模型版本通用。

## defer
- sessions/messages + 流式 Chat WS 端点 → m3；前端 → m4；重试/退避、工具调用、视觉、多模型对比 → 后续。

## 验证
- 后端 `pytest` **67 通过**（+7 m2）。
- review（agent）：SSE 解析（含 event:+data: 两行帧、[DONE]、坏 JSON）、可选 client 生命周期（生成器/协程 finally 均关自有 client）、raise_for_status（httpx 0.28.1 流内正确）、header/base_url 拼接均确认。修 1 med（/test 未捕获 DecryptionError→改为 try 内解密 + 捕获，加错误路径测试）+ 1 low（delete flush）。SSRF 面（base_url 用户提供、服务端外呼）记为本地单用户已知约束、非阻塞。密钥不入响应（仅 str(exc)，不含 key）。

## 熔断状态
- 未命中。

## 下一步
- m3：sessions/messages 表 + 流式 Chat WS 端点（开始/停止 + 持久化 + 会话恢复，含模型/系统提示词）。
