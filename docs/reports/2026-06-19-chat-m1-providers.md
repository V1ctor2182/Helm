# chat-multimodel · m1 数据模型 + Provider 管理

- **日期**：2026-06-19
- **Room / milestone**：chat-multimodel / m1（数据模型 + Provider 管理）

## 目标
为多模型 Chat 打底：provider 数据模型 + 管理 REST（加密密钥、内置预设），后续 adapters/会话/前端建其上。

## 做了什么
- **`helm/chat/models.py`**：`Provider`（id/type/name/base_url/api_key_enc[SecretBox 密文]/models_json/created_at）。sessions/messages/presets 待 m3。
- **`helm/chat/service.py`**：`PROVIDER_TEMPLATES`（Claude 默认 + Ollama/OpenAI/OpenRouter/兼容；Claude model id 按 claude-api：claude-opus-4-8 等）；`ProviderService`（list/create[密钥 SecretBox 加密]/delete/api_key[服务端解密]）；`provider_public`（只回 has_key，绝不回密钥/密文）。
- **`helm/chat/routes.py`**：GET /api/providers/templates、GET /api/providers、POST /api/providers、DELETE /api/providers/{id}。
- **`app.py`**：include chat_router（注册 Provider 模型 → create_all）。

## 决策（record_decision）
- Chat 后端用全新精简 adapters（复用 Odysseus 逻辑作参考，不整体移植 5000 行）——用户拍板。
- 密钥经 SecretBox 加密存 providers.api_key_enc（inline，按 F2 §5），满足约束 6a745b5c（不明文落库）；REST 绝不回明文/密文，仅 has_key。

## defer
- sessions/messages/presets 表 + 流式 Chat → m3；provider adapters（Anthropic+OpenAI 兼容）+ test/ping → m2；前端 → m4；多模型对比/视觉 → P1。

## 验证
- 后端 `pytest` **60 通过**（+4 chat：templates / CRUD 隐藏密钥 / 密钥加密落库 / keyless+delete）。
- 自审（与已评审的 platform-shell m3 SecretBox 模式同构 + 测试覆盖密钥不外泄不变量）：provider_public 不回密钥、create 经 box 加密、list/delete 注入惰性 box（去掉 __new__ 哨兵）。

## 熔断状态
- 未命中。

## 下一步
- m2：Provider adapters（Anthropic 默认 + OpenAI 兼容流式；test/ping 列模型）。Anthropic adapter 按 claude-api skill 写 model id/流式/header。
