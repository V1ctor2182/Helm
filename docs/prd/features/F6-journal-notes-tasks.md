# F6 · 日记 / 速记 / 任务（个人记录）

> 来源：Odysseus（`note_routes` / `task_routes` / `task_scheduler`）+ 新增日记｜优先级：**P1**｜里程碑：M3–M5
> 上级：[PRD 主文档](../00-PRD-Master.md)

让 Helm 不只是"指挥 agent + 研究"的工具，也是你**随手记录、写日记、管任务**的地方——而且因为大脑在同一个 App 里，这些记录是 **AI-native** 的：能被总结、被检索、被 agent 执行。

> **复用为主**：Odysseus 已有 Keep 风格笔记/清单 + cron 式定时任务（agent 可执行），大部分能力**原样复用**；日记是建在笔记之上的新增视图。

---

## 1. 目标
- **速记（Quick Capture）**：任何时候一键记一条想法/链接/片段，零摩擦。
- **日记（Journal）**：按日期的反思性条目，可回看、可被 AI 总结。
- **任务（Tasks）**：todo 清单 + 提醒 + cron 式定时任务，**agent 能在到点时执行**。
- **AI-native**：记录能转成记忆/任务、能被检索、能被 agent 处理。

## 2. 非目标
- 不做重型项目管理（看板/甘特/多人协作）。
- 不做完整日历（日历是 Odysseus 另有的能力，本 feature 仅与提醒联动）。

---

## 3. 功能拆解

### 3.1 速记（复用 Odysseus 笔记）
- Keep 风格：纯文本笔记 / 勾选清单（`note_type: note | checklist`，复用 `Note` 模型）。
- 零摩擦入口：全局快捷键 / 命令面板「记一条」即弹输入框；可附当前项目/文件上下文。
- 标签、置顶、搜索（含全文）。
- **一键转化**：把一条速记 → 任务 / 记忆（F4）/ 日记条目。

### 3.2 日记（新增，建在笔记之上）
- 按日期组织的条目流（今天/本周/历史），日历式或时间线浏览。
- 支持 Markdown、附图（与 F1 截图直通联动：截图可直接落入今天的日记）。
- **AI 辅助（可选）**：
  - 一键「今日小结」：基于今天的速记/任务完成/agent 活动，生成日记草稿。
  - 周/月回顾：AI 汇总这段时间做了什么、改了哪些项目（数据来自 F1 的会话/变更记录）。
- 数据可建在 `Note` 上加 `kind='journal'` 与 `entry_date`，或独立 `journal_entries` 表（实现细节待定）。

### 3.3 任务（复用 Odysseus 定时任务）
- **todo**：清单、优先级、截止、完成状态（可用 checklist 笔记或独立任务表）。
- **提醒**：到点通知，多通道（ntfy / 浏览器 / 邮件，复用 Odysseus 通道）。
- **定时任务（cron）**：复用 `ScheduledTask` / `TaskRun` / `task_scheduler`（`compute_next_run`），**agent 可在触发时执行**（如「每天早上汇总未读邮件」「每周生成项目回顾」）。
- 任务可关联项目（F1）/ 研究（F3）/ 记忆（F4）。

### 3.4 与大脑/驾驶舱的联动（AI-native 关键）
- 速记/日记内容可写入 **记忆（F4）**，长期沉淀。
- 任务可触发 **agent**（F5）执行；研究（F3）结论可一键存为日记或任务。
- 驾驶舱（F1）的「我今天/这周改了哪些项目」可自动喂给日记回顾。

---

## 4. 交互与入口
- **全局速记快捷键**：任何界面一键弹出输入框，记完即走。
- **命令面板**：`记一条` / `新任务` / `今日日记`。
- 中央区新增 **记录** 标签：速记 / 日记 / 任务 三个子视图。
- 截图直通卡（F1）增加「存入今日日记」动作。

## 5. 数据模型（关联 F0，复用为主）
- `notes`（复用 Odysseus `Note`）：`id, note_type(note|checklist|journal), text, items_json, tags, pinned, entry_date?, project_path?, created_at, updated_at`
- `scheduled_tasks`（复用 `ScheduledTask`）：`id, name, prompt, cron, channel, next_run, enabled, linked_ref?`
- `task_runs`（复用 `TaskRun`）：`id, task_id, status, started_at, output`
- 日记若独立：`journal_entries(id, entry_date, body_md, attachments_json, ai_generated)`（二选一，待定）

## 6. 用户故事
- 作为用户，我随时按快捷键记一句话，不打断手头的事。
- 作为用户，我每天写两行日记，月底让 AI 帮我汇总这个月做了什么。
- 作为用户，我建一个「每天 9 点汇总未读邮件」的定时任务，agent 到点自动跑。
- 作为用户，我把一条速记一键变成任务，或存进长期记忆。
- 作为用户，agent 跑研究得出的结论，我能一键存成今天的日记。

## 7. 验收标准
- [ ] 全局快捷键能在任意界面 < 1s 弹出速记输入并保存。
- [ ] 笔记/清单的增删改查、标签、搜索可用（复用 Odysseus 验证）。
- [ ] 日记按日期浏览，能附图与截图直通落入。
- [ ] 定时任务到点触发并（可选）调起 agent 执行，结果写入 `task_runs`。
- [ ] 速记一键转任务/记忆/日记成功。

## 8. 依赖与风险
- 依赖 F0（存储）、F4（记忆联动）、F5（任务触发 agent）、F1（截图直通 / 活动数据喂日记）。
- **低风险**：笔记与定时任务为 Odysseus 既有 Python 实现，原样复用；新增工作量集中在「日记视图 + 速记全局入口 + 转化/联动」。
- 决策点：日记落在 `Note(kind='journal')` 还是独立表（影响查询与回顾实现）。
