# Loop Report · journal-notes-tasks · m4

> 档位:🌙 放手模式。`journal-notes-tasks` 第 4 个 milestone（Round 20）。本 Room 技术核心。

## 目标

`journal-notes-tasks` / **m4 — 定时任务**(intent#3,落地 decision 894165f7)。scheduled_tasks + task_runs +
at/every/cron 三模式调度数学 + note→task。非末个。

## 做了什么

新建 **`helm/tasks/`** 包:

- **`models.py`**（新增）:`ScheduledTask`(name/prompt/schedule_kind/schedule_value_json/execution_mode/
  enabled/next_run/last_status/run_count/linked_note_id)+ `TaskRun`(task_id/status/output/时间)。
- **`schedule.py`**（新增）:`compute_next_run(kind, value, after)` 纯函数 tz-aware——at→{at:iso}
  (过去返 None)、every→{seconds}、cron→{expr}(croniter + is_valid 校验)。
- **`service.py`**（新增）:`TaskService` CRUD + `due(now)`(enabled 且 next_run<=now)+
  `record_run`(写 TaskRun + 推进 next_run + 更新 last_status/run_count)+ set_enabled(re-arm)。
- **`routes.py`**（新增）:`/api/tasks` CRUD + `GET /{id}/runs` + enabled 开关。
- **`helm/notes/routes.py`**（改）:`POST /api/notes/{id}/to-task`——note 内容→task prompt + linked_note_id(intent#1)。
- **`helm/app.py`**（改）:挂 tasks router。**deps +croniter**。
- **测试**:`tests/test_tasks.py` 8(cron/every/at 调度数学 + create 算 next_run + due + record_run 推进/
  一次性 disarm + 坏 kind + 路由 + note→task)。

## 决策(record_decision)

- **decision `3a50bc4c`**（ai_proposed）:任务模型 + 三模式调度 + note→task。技术决策。
- **执行器(到点真触发 agent=付费外部)+ 后台轮询循环显式留 m5**(经 agent-orchestration ACP,届时 [needs-human] 联调)。
- **无新 `[needs-human]`**(本轮纯机器,无付费外部);无难撤产品 OQ。

## VibeHub / MCP 交互

**pull**:decision 894165f7(at/every/cron + execution_mode 模型)。**write**:`record_decision`（`3a50bc4c`,ai_proposed）。无新 ticket。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。CI:纯后端,本地全绿。cron/loop:`2dc539c2`,Round 20。

## defer

- **执行器 + 后台调度循环 + 到点真触发 agent**(付费外部)→ m5(届时 [needs-human] 联调)。

## 优化

- **后端**:schedule 纯函数(无 DB)易测;record_run 一次性 disarm 防 'at' 重复触发;due 用 SQL 过滤
  (enabled+next_run<=now)而非 Python 全扫;delete 级联清 runs。
- **前端**:本轮无前端(任务 UI m5)。

## 验证

- `pytest tests/test_tasks.py` → **8 passed**;`pytest`（全量后端）→ **162 passed, 1 skipped**(m3 154 → +8)。
- **未发真实外部调用**(执行器留 m5);schedule/CRUD/record_run/note→task 全 headless 覆盖。

## review

自审:
- **抓到真 bug**:'at' 一次性任务在 record_run 后,若其时刻仍在未来会被错误重新武装(compute_next_run 对未来 at 返回该时刻)。
  **当场修**:record_run 对 schedule_kind=='at' 强制 next_run=None(一次性,触发即 disarm),复跑通过。
- cron is_valid 校验拒坏表达式、due SQL 过滤、note→task linked_note_id —— 有测试。
- 无其它 bug。

## 熔断状态

未命中熔断。一次测试失败(暴露 'at' 重武装 bug)**首次即修复**,未达连败 2 次——正是 review 该抓的。

## 下一步

`journal-notes-tasks` / **m5 — 任务执行器 + 后台调度 + 任务 UI + AI 联动**(Room 末个 milestone):
执行器经 agent-orchestration ACP 到点触发 agent(⚠付费外部→[needs-human])、后台轮询循环、任务前端、
日记「今日小结」AI 生成(复用 chat provider)。做完 Room 收尾。
