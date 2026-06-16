# F7 · 邮件 / 日历

> 来源：Odysseus（`email_routes` / `email_pollers` / `calendar_routes` / `contacts_routes` / `email_server` MCP / CalDAV）｜优先级：**P2**｜里程碑：M5+
> 上级：[PRD 主文档](../00-PRD-Master.md)

把 Odysseus 现成的**带 AI 分诊的邮件**与**本地优先日历**纳入 Helm，让"收信、看日程"也在同一个 AI workspace 里完成。

> **几乎纯复用**：这两块是 Odysseus 已实现的成熟 Python 能力，Helm 主要是把 UI 整合进新外壳 + 打通与任务/研究/记忆的联动。

---

## 1. 目标
- **邮件**：IMAP/SMTP 收件箱，内置 AI 分诊（紧急提醒、自动打标、自动摘要、自动回复草稿、自动反垃圾）。
- **日历**：本地优先日历，CalDAV 双向同步，.ics 导入导出，agent 可感知。
- **AI-native 联动**：邮件可转任务（F6）/ 记忆（F4）；日程与提醒（F6）打通；agent 可读邮件/日程并行动（F5）。

## 2. 非目标
- 不做完整邮件客户端的全部高级特性（规则引擎 GUI、复杂过滤器编辑器）——首版聚焦"收 + AI 分诊 + 草稿"。
- 不做日历的多人协作/会议室预订。

---

## 3. 功能拆解

### 3.1 邮件（复用 Odysseus）
- **账户**：IMAP/SMTP，多账户、per-account 路由（复用 `email_routes` / `email_pollers` / `email_helpers`）。
- **AI 分诊**（Odysseus 已有）：
  - 紧急度判断与提醒、自动打标签、自动摘要、自动起草回复、自动识别垃圾。
- **MCP**：复用 `email_server`（列未读/未回邮件、读正文、起草回复草稿）→ 终端/大脑 agent 可用（F5）。
- **联系人**：复用 `contacts_routes`。
- **一键转化**：邮件 → 任务（F6）/ 记忆（F4）/ 日历事件。

### 3.2 日历（复用 Odysseus）
- 本地优先，**CalDAV 同步**（Radicale / Nextcloud / Apple / Fastmail，复用 `calendar_routes` + caldav）。
- .ics 导入/导出、per-calendar 颜色、agent-aware。
- 视图：月/周/日；与 F6 的任务/提醒在时间维度上整合展示。

### 3.3 与大脑/记录的联动（AI-native）
- 邮件 AI 摘要/紧急提醒可推送到 F6 的提醒通道（ntfy/浏览器/邮件）。
- 「从邮件提取日程/事件」→ 自动建日历事件或任务（Odysseus 已有 `extract_email_events` 类 housekeeping）。
- 定时任务（F6）可调起 agent 处理邮件（如「每天汇总未读 + 草拟回复」——对应 Odysseus 既有的 `summarize_emails` / `draft_email_replies`）。

---

## 4. 交互与入口
- 中央区新增 **邮件**、**日历** 两个标签（或并入"记录/工作"区）。
- 邮件列表带 AI 标签/摘要；单封视图可一键「草拟回复 / 转任务 / 加日程」。
- 日历与 F6 任务/提醒共用一个时间视图。

## 5. 数据与存储（复用 Odysseus）
- 邮件：账户配置（密钥加密，见 F0）、AI 摘要缓存（复用 Odysseus 的 summary cache）。
- 日历：CalDAV 连接配置 + 本地事件缓存。
- 联系人表（复用）。

## 6. 用户故事
- 作为用户，我打开 Helm 就能看到 AI 已经帮我标好紧急/摘要的未读邮件。
- 作为用户，我一键把一封邮件变成任务或日历事件。
- 作为用户，我设一个定时任务，让 agent 每天早上汇总未读邮件并草拟回复。
- 作为用户，我的日历和外部 CalDAV（如 Apple 日历）保持同步。

## 7. 验收标准
- [ ] 配好一个 IMAP/SMTP 账户后能收信、看 AI 摘要/标签、草拟回复。
- [ ] `email_server` MCP 能被终端 agent 调用（列未读/读正文/起草）。
- [ ] 日历与一个 CalDAV 源双向同步、.ics 导入导出可用。
- [ ] 邮件一键转任务/日程/记忆成功。

## 8. 依赖与风险
- 依赖 F0（密钥/存储）、F4（记忆）、F5（agent 处理邮件）、F6（任务/提醒/日程整合）。
- **低风险**：邮件分诊与 CalDAV 日历均为 Odysseus 既有 Python 实现，原样复用；主要工作是 UI 整合与联动。
- 注意：这是 **P2**，排在核心 4 大能力与 F6 之后；可按需启用，不影响 MVP。
