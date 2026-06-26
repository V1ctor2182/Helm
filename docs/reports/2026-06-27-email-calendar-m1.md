# Loop Report · email-calendar · m1

> 档位:🌙 放手模式。新 Room `email-calendar`（最后一个 Room）第 1 个 milestone（Round 22）。

## 目标

`email-calendar` / **m1 — 邮件账户(加密凭据)+ IMAP 收取 + 邮件模型 + 列表 API**(intent#1 基础)。
非末个。

## 做了什么

新建 **`helm/mail/`** 包:

- **`models.py`**（新增）:`EmailAccount`(imap/smtp host/port/user + **`password_enc` 仅密文**,constraint 9ada9908)+
  `Email`(account_id/uid/from/subject/snippet/body/date/unread/labels/triage)。本地缓存,(account,uid) 键。
- **`imap.py`**（新增）:`FetchedEmail` + `ImapFetcher` Protocol(注入式)+ `ImaplibFetcher`(stdlib imaplib SSL,
  real,标 pragma no cover——外部,不在 CI/loop 跑)。
- **`service.py`**（新增）:`AccountService`(CRUD,**凭据 SecretBox 加密,绝不回明文**,password() 解密)+
  `EmailService`(list/get/**sync 按 uid upsert 不重复**)。
- **`routes.py`**（新增）:`/api/mail/accounts` CRUD + `/{id}/sync`(IMAP 错→502)+ `/emails` 列表(account/unread 过滤)+ `/emails/{id}`。
  `default_fetcher` 模块级可 patch(测试注入 fake)。
- **`helm/app.py`**（改）:挂 mail router。
- **测试**:`tests/test_mail.py` 4(账户 CRUD 隐藏密码 / 密文落库+解密 round-trip / sync uid 去重+传解密密码 / 收件箱列表+get+sync 路由+过滤)。

## 决策(record_decision)

- **decision `b90b822b`**（ai_proposed）:Room MVP 拆分 + 凭据加密 + 连接层可 mock。
- **`[needs-human]` `e07337e5`**(medium):用真实邮箱连一次 IMAP 核对收取/解析(外部+凭据,loop 未连)。
- 原样复用方向沿用 `123796b8`。无难撤产品 OQ。

## VibeHub / MCP 交互

**pull**:`get_feature_context` → 3 intent + 5 constraint(凭据加密 9ada9908、收+分诊+草稿 55c77d50、原样复用 21969e0a);
读 Odysseus email_routes(IMAP 模型)+ 复用 chat ProviderService 的 SecretBox 加密范式。
**write**:`record_decision`（`b90b822b`)+ `create_ticket`（`e07337e5`,**[needs-human]** 真实 IMAP,medium）。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。CI:纯后端,本地全绿;真实 IMAP(ImaplibFetcher)标 pragma 不在 CI 跑。cron/loop:`2dc539c2`,Round 22。

## defer

- `[needs-human]` `e07337e5`:真实 IMAP 联调(外部+凭据)。AI 分诊/草稿 → m2;HTML 邮件正文 → 后续。

## 优化

- **后端**:凭据 SecretBox 加密 + 仅 has_password 暴露(结构性防泄漏);sync 按 uid upsert 防重复;
  ImapFetcher Protocol 注入使 sync headless 可测(零真实连接);delete 级联清 emails。
- **前端**:本轮无前端(收件箱 UI m3)。

## 验证

- `pytest tests/test_mail.py` → **4 passed**;`pytest`（全量后端）→ **172 passed, 1 skipped**(journal 168 → +4)。
- **未连真实 IMAP**(外部+凭据,放手模式硬底线);FakeFetcher 覆盖 sync/列表/路由全链路。
- 凭据加密:断言密文不含明文 + 解密 round-trip。

## review

自审:
- 密码仅密文落库、API 不回明文(has_password 布尔)、解密 round-trip —— 有测试(constraint 9ada9908)。
- sync uid 去重、传解密密码给 fetcher、502 on IMAP 错 —— 有测试。
- ImaplibFetcher 真实路径标 pragma(外部)+ [needs-human] 联调。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。真实 IMAP(外部+凭据)按放手模式就地化解([needs-human] ticket),未停 loop。

## 下一步

`email-calendar` / **m2 — AI 分诊 + 草稿**(intent#1):复用 chat ChatLLM 对邮件判紧急度/打标/摘要/识垃圾 +
起草回复,写入 Email.triage_json。⚠LLM 付费(用户发起)。Room 继续。
