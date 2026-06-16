# F2 · Chat 与多模型

> 来源：Odysseus｜优先级：**P0**（Chat + 1 provider）/ P1（多模型对比）｜里程碑：M2
> 上级：[PRD 主文档](../00-PRD-Master.md)

复用 Odysseus 的「接任意本地/API 模型 + 对话 + 模型对比」能力（Python 原样保留），整合为 Helm 大脑的对话入口。

---

## 1. 目标
- 在驾驶舱同窗口里与任意已配置模型对话。
- **provider 接入超简单**：本地（Ollama / llama.cpp / vLLM）与 API（OpenAI / OpenRouter / Copilot 等 OpenAI 兼容端点）。
- 支持模型**对比**（同一问题多模型并排，盲测可选）。

## 2. 非目标
- 不内置训练/微调；不做 Odysseus 里暂未列入核心的图像编辑等扩展（backlog）。

---

## 3. 功能拆解

### 3.1 Provider 管理（P0）
- 统一的 provider 模型：`{ type, base_url, api_key?, models[] }`。
- 内置预设：Ollama（`http://localhost:11434`）、OpenAI、OpenRouter、通用 OpenAI 兼容。
- **密钥安全**：API key 经系统钥匙串/`safeStorage` 加密存储（见 F0），不明文落库。
- 连通性测试：保存时一键 ping，列出可用模型。

### 3.2 Chat（P0）
- 多会话、流式输出、Markdown/代码渲染（复用 F1 的渲染能力）。
- 上下文：可附带当前项目文件/选区、可调用 RAG（F4）作为上下文。
- 会话持久化到 SQLite（`sessions`/`messages`，见 F0）。
- 支持系统提示词 / 预设（presets）。

### 3.3 多模型对比（P1）
- 同一 prompt 并行发给多个模型，结果并排展示。
- **盲测模式**：隐藏模型名，选出更优后再揭晓（沿用 Odysseus 的 Compare 思路）。
- 可选「综合」：让一个模型基于多家答案合成。

### 3.4 视觉/附件（P1）
- 支持给多模态模型发图片/PDF（与 F1 文件、F4 文档处理协同）。

---

## 4. 架构（复用 Odysseus）
- **复用 Odysseus 既有模型连接与 Chat 后端**（已支持 vLLM / llama.cpp / Ollama / OpenRouter / OpenAI / Copilot）。
- 主要工作：把 Chat UI 整合进新驾驶舱外壳，并打通与项目文件/选区、RAG（F4）的上下文。
- 模型能力（工具调用/视觉/流式）沿用 Odysseus 的 provider 元数据。
- 与 **F5** 协同：Chat 里也能触发工具/agent（function calling / MCP）。

## 5. 数据模型（关联 F0）
- `providers(id, type, base_url, api_key_enc, models_json, caps_json, created_at)`
- `sessions(id, kind='chat', title, project_path?, provider_id, model, system_prompt, ...)`
- `messages(id, session_id, role, content, attachments_json, tokens, ts)`
- `presets(id, name, system_prompt, params_json)`

## 6. 用户故事
- 作为用户，我能 30 秒内加一个 Ollama 本地模型并开始对话。
- 作为用户，我能在对话里引用当前项目的某个文件作为上下文。
- 作为用户，我能把同一个问题丢给 3 个模型盲测，选出最好的。
- 作为用户，我的 API key 不会明文存在数据库里。

## 7. 验收标准
- [ ] 新增一个 OpenAI 兼容 provider 并成功流式对话 < 1 分钟。
- [ ] 流式输出可中断（stop）。
- [ ] 会话重启后完整恢复（含模型/系统提示词）。
- [ ] 对比模式下 N 个模型并行返回且正确归位。
- [ ] key 加密存储校验通过。

## 8. 依赖与风险
- 依赖 F0（存储/密钥）、F4（RAG 作上下文）、F5（工具调用）。
- 风险：各 provider 的「OpenAI 兼容」程度不一（流式、工具调用差异）；Odysseus 已有适配基础，新增 provider 仍需兜底。
