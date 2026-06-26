# Room 收尾复盘 · email-calendar（PRD 收官 Room）

> 档位:🌙 放手模式。`email-calendar` 5 milestone 完成,Room 收尾 → 合 main → **全 10 Room 完成**。

## Room 概览

邮件(IMAP 收 + AI 分诊 + 草稿)+ 日历(本地优先 + .ics + CalDAV 账户)+ 联动(邮件→记忆/任务)+
MCP email_server(供终端 agent)。凭据全程 SecretBox 加密。

## 5 个 milestone(全部完成)

| m | 内容 | 关键产出 | 提交 |
|---|---|---|---|
| m1 | 账户(加密)+ IMAP + 收件箱 | `helm/mail/`(EmailAccount 加密 + ImapFetcher 注入 + sync) | `993e957` |
| m2 | AI 分诊 + 草稿 | triage(urgency/标签/摘要/垃圾/草稿,归一化) | `3210827` |
| m3 | 邮件前端 | mail 模式收件箱 + 详情 + 分诊/草稿 | `9e64bbd` |
| m4 | 日历(本地 + .ics) | `helm/calendar/` + 无依赖 ics + 加密 CalDAV 账户 | `fc9c275` |
| m5 | 日历前端 + 联动 + MCP | 日历分段 + 邮件→记忆/任务 + helm_email_unread/read | `97c9780` |

## 验证门(全绿)

- 后端 `pytest` → **183 passed, 1 skipped**。
- desktop `node --check` → ok。
- 前端 `vitest` → **140 passed**;`svelte-check` → **0/0**;`build` → ok。
- **全程零真实 IMAP/LLM/agent/CalDAV 调用**(外部+凭据,放手模式硬底线):全用 fake/TestClient 注入。

## 决策留痕(本 Room,均 ai_proposed 待确认)

- `b90b822b` MVP 拆分 · `c4ee82bd` m2 分诊 · `6f3d5cea` m3 前端 · `2f91cde6` m4 日历 · `085dcef3` m5 联动+MCP(守契约 ca4b5e64)。

## needs-human 队列(本 Room 2 条)

- **`e07337e5`（medium）**:真实邮箱 IMAP 联调(外部+凭据)。
- **`cec2c3f0`（high）**:CalDAV 双向同步**待实现** + 真实服务器联调(复杂外部协议,建议接 caldav 库)。

## backlog(非阻塞)

email→日历事件转换(需邮件抽取会议时间)→ 后续;其余跨 Room backlog 各自 drain。

## 合并

`feat/email-calendar` → `main`(PR + CI 绿)。**合后全部 10 个 Room 完成,PRD 路线图跑通。**
下一个 cron fire 的 step 0 检测到 A 轨清空 → 进入「B 轨收尾」:清剩余技术 backlog,直到只剩 `[needs-human]` ticket。
