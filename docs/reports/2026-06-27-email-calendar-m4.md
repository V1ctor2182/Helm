# Loop Report · email-calendar · m4

> 档位:🌙 放手模式。`email-calendar` 第 4 个 milestone（Round 25）。

## 目标

`email-calendar` / **m4 — 日历(CalDAV + 事件 + .ics)**(intent#2)。本地优先事件 + .ics 导入/导出 +
（加密）CalDAV 账户;CalDAV 真实同步留 [needs-human]。非末个。

## 做了什么

新建 **`helm/calendar/`** 包(绝对导入,不影响 stdlib calendar):

- **`models.py`**（新增）:`CalendarEvent`(uid/summary/desc/location/start/end/all_day/source)+
  `CalDavAccount`(password_enc 加密)。
- **`ics.py`**（新增）:**无依赖最小 iCalendar** —— `parse_ics`/`events_to_ics`(VEVENT 的
  UID/SUMMARY/DESCRIPTION/LOCATION/DTSTART/DTEND,UTC datetime `…Z` 与全天 VALUE=DATE + 转义)。
- **`service.py`**（新增）:`EventService` CRUD + 日期范围 list + `import_ics`(uid 去重)/`export_ics`;
  `CalDavAccountService`(加密凭据)。
- **`routes.py`**（新增）:`/api/calendar/events` CRUD + `/import` + `/export`(text/calendar)+ `/accounts`。
- **`helm/app.py`**（改）:挂 calendar router。
- **测试**:`tests/test_calendar.py` 6(ics 解析 / round-trip / 事件 CRUD+范围 / import uid 去重 / CalDAV 加密 / 路由)。

## 决策(record_decision)

- **decision `2f91cde6`**（ai_proposed）:本地事件 + 最小 ics + 加密 CalDAV 账户。
- **`[needs-human]` `cec2c3f0`**(high):**CalDAV 双向同步协议未实现**(PROPFIND/REPORT/PUT/etag 复杂 + 验证需真实服务器);
  建议接 `caldav` 库 + Radicale 联调。本地事件 + ics 已可用,不影响 m5 联动。

## VibeHub / MCP 交互

**pull**:intent#2(本地优先 + CalDAV + ics)+ 复用 SecretBox 加密范式。
**write**:`record_decision`（`2f91cde6`)+ `create_ticket`（`cec2c3f0`,**[needs-human]** CalDAV 同步,high）。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。CI:纯后端,本地全绿。cron/loop:`2dc539c2`,Round 25。

## defer

- `[needs-human]` `cec2c3f0`:CalDAV 双向同步(待实现 + 真实服务器联调)。富 RFC5545(recurrence/tz)→ 未来换 icalendar 库。

## 优化

- **后端**:ics 无依赖(不引 icalendar/caldav 重库);import 按 uid 去重防重复;事件按 start 索引 + 范围查询;
  CalDAV 凭据加密(同 mail)。
- **前端**:本轮无前端(日历视图 m5)。

## 验证

- `pytest tests/test_calendar.py` → **6 passed**;`pytest`（全量后端）→ **182 passed, 1 skipped**(m3 176 → +6)。
- ics round-trip(parse→serialize→parse 保持 summary/start/all_day);CalDAV 凭据密文不含明文 + 解密。
- **未连真实 CalDAV**(外部+凭据,放手模式硬底线;且协议未实现 → [needs-human])。

## review

自审:
- ics 转义/反转义、全天 VALUE=DATE、UTC、round-trip —— 有测试。
- 事件范围查询、import uid 去重、CalDAV 加密、路由 422/404/export —— 有测试。
- **诚实记入 ticket**:CalDAV 同步未实现(不假装做了),交付边界写清。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。CalDAV 同步(外部+复杂+需真实服务器)按放手模式就地化解([needs-human] ticket + 交付本地+ics),未停 loop。

## 下一步

`email-calendar` / **m5 — 日历前端 + 联动**(intent#3,Room 末个 milestone):日历视图(月/周/事件 + ics 导入导出按钮)+
邮件/日程一键转 任务(F6)/记忆(F4)/日历事件 + MCP email_server(供终端 agent 列未读/读正文/起草)。做完 Room 收尾 → **全部 10 Room 完成**。
