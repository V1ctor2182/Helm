# Loop Report · email-calendar · m2

> 档位:🌙 放手模式。`email-calendar` 第 2 个 milestone（Round 23）。

## 目标

`email-calendar` / **m2 — AI 分诊 + 草稿**(intent#1)。复用 chat ChatLLM 对邮件判紧急度/标签/摘要/识垃圾 +
起草回复,写入 `Email.triage_json`。非末个。

## 做了什么

- **`helm/mail/triage.py`**（新增）:`triage_email(email, llm)` —— prompt → JSON;复用 research `_extract_json`
  鲁棒解析;**归一化**(urgency 限 high|medium|low、labels 截 3、is_spam 布尔、draft 字符串);
  **LLM 返垃圾也给安全默认**(low/非垃圾/空草稿)不崩。
- **`helm/mail/service.py`**（改）:`EmailService.triage(email_id, llm)` 持久化 triage_json + 提升 labels 到
  labels_json(供收件箱筛选)。
- **`helm/mail/routes.py`**（改）:`POST /api/mail/emails/{id}/triage {provider_id, model}` —— 复用 chat
  ProviderService + ChatLLM(box 解密 key),404 守(邮件/provider)。ChatLLM 模块级可 patch。
- **测试**:`tests/test_mail_triage.py` 4(归一化好 JSON / 垃圾默认 / service 持久化+labels 提升 / 路由+list 带 triage+404)。

## 决策(record_decision)

- **decision `c4ee82bd`**（ai_proposed）:分诊 + 草稿 + 归一化持久化。技术+可逆产品小决定。
- LLM 付费=用户发起,与 research/summary 同模式(ChatLLM 已跨 Room 充分测),**不另开 needs-human**。无难撤产品 OQ。

## VibeHub / MCP 交互

**pull**:复用 research `_extract_json` + chat ProviderService/ChatLLM。**write**:`record_decision`（`c4ee82bd`)。无新 ticket。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。CI:纯后端,本地全绿;triage 测试用 fake LLM,**不发真实 LLM**。cron/loop:`2dc539c2`,Round 23。

## defer

- 邮件前端(收件箱 + 分诊视图 + 草稿)→ m3。真实 LLM 分诊质量随真实邮箱联调(`e07337e5`)一并看。

## 优化

- **后端**:triage 归一化 + 垃圾默认(LLM 不可靠也不崩、不写脏数据);labels 提升到 labels_json(收件箱筛选零额外查询);
  复用 research `_extract_json`(不重造 JSON 解析)。
- **前端**:本轮无前端。

## 验证

- `pytest tests/test_mail_triage.py` → **4 passed**;`pytest`（全量后端）→ **176 passed, 1 skipped**(m1 172 → +4)。
- **未发真实 LLM 调用**(付费,放手模式硬底线);fake LLM 覆盖归一化/默认/持久化/路由。

## review

自审:
- 归一化(urgency 校验/labels 截断)、垃圾 JSON→安全默认、service 持久化+labels 提升、路由 404 —— 有测试。
- LLM 返非法值不崩(防脏数据进 DB)。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。

## 下一步

`email-calendar` / **m3 — 邮件前端**(intent#1 UI):mail 模式收件箱(列表 + 未读/紧急标识)+ 邮件详情(正文 +
分诊结果 urgency/summary/labels + 草稿)+ 触发分诊按钮。Room 继续。
