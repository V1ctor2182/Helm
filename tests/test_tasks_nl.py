"""T2 人话排期:整句 → schedule;/api/tasks 只发 {prompt};/parse 实时徽章。

设计基线 helm-journal-kinds.html(2026-07-08):派发条一句话连时间一起说,
AI 解析出排期 chip;cron 表达式从 UI 全面退场。存储仍 at|every|cron,
人话标签存 schedule_value.nl,原句在 task.prompt。
"""

from __future__ import annotations

from datetime import datetime

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.tasks.nl import parse_schedule

NOW = datetime(2026, 7, 8, 15, 0)  # 周三


# ── 解析器 ──────────────────────────────────────────────────────────────

def test_daily_morning() -> None:
    p = parse_schedule("每天早上9点汇总未读邮件", NOW)
    assert p and p.kind == "cron" and p.value["expr"] == "0 9 * * *"
    assert p.label == "每天 09:00" and p.value["nl"] == p.label


def test_weekly_friday_pm() -> None:
    p = parse_schedule("每周五下午3点回顾本周", NOW)
    assert p and p.kind == "cron" and p.value["expr"] == "0 15 * * 5"
    assert p.label == "每周五 15:00"


def test_weekly_without_day_defaults_monday() -> None:
    p = parse_schedule("每周回顾一次 OKR", NOW)
    assert p and p.value["expr"] == "0 9 * * 1" and p.label == "每周一 09:00"


def test_every_n_hours() -> None:
    p = parse_schedule("每 6 小时跑一遍 swift test 夜巡", NOW)
    assert p and p.kind == "every" and p.value["seconds"] == 6 * 3600
    assert p.label == "每 6 小时"


def test_workdays() -> None:
    p = parse_schedule("每个工作日早上8点半发站会提醒", NOW)
    assert p and p.value["expr"] == "30 8 * * 1-5" and p.label == "工作日 08:30"


def test_nightly_bare_clock_gets_pm() -> None:
    p = parse_schedule("每晚10点备份", NOW)
    assert p and p.value["expr"] == "0 22 * * *" and p.label == "每晚 22:00"


def test_monthly() -> None:
    p = parse_schedule("每月1号生成月报", NOW)
    assert p and p.value["expr"] == "0 9 1 * *" and p.label == "每月 1 号 09:00"


def test_oneshot_uses_triage_when() -> None:
    p = parse_schedule("明早9点提醒我 review notch PR", NOW)
    assert p and p.kind == "at" and p.label == "明早 09:00"
    at = datetime.fromisoformat(p.value["at"])
    assert at.tzinfo is not None  # 本地时刻转带时区,compute_next_run 不当 UTC 误读
    assert (at.year, at.month, at.day, at.hour) == (2026, 7, 9, 9)


def test_no_time_returns_none() -> None:
    assert parse_schedule("整理一下桌面", NOW) is None
    assert parse_schedule("", NOW) is None


# ── API ─────────────────────────────────────────────────────────────────

def test_post_prompt_only_parses_schedule(config) -> None:
    """捕获坞/notch「交给 agent」契约:只发 {prompt},排期从句子解析。
    422 回归守卫——此前 TaskBody 必填 name/schedule 把这条路堵死了。"""
    c = TestClient(create_app(config))
    r = c.post("/api/tasks", json={"prompt": "每天早上9点汇总未读邮件"})
    assert r.status_code == 200
    t = r.json()
    assert t["schedule_kind"] == "cron"
    assert t["schedule_value"]["expr"] == "0 9 * * *"
    assert t["schedule_value"]["nl"] == "每天 09:00"   # chip 显示人话,不显示 cron
    assert t["name"] == "每天早上9点汇总未读邮件"        # name 缺省=prompt 截断
    assert t["next_run"] is not None


def test_post_no_time_422_with_hint(config) -> None:
    c = TestClient(create_app(config))
    r = c.post("/api/tasks", json={"prompt": "整理桌面"})
    assert r.status_code == 422 and "时间" in r.json()["detail"]


def test_post_explicit_schedule_unchanged(config) -> None:
    """显式 schedule 老契约不动。"""
    c = TestClient(create_app(config))
    r = c.post("/api/tasks", json={
        "name": "digest", "prompt": "do it",
        "schedule_kind": "cron", "schedule_value": {"expr": "0 9 * * *"}})
    assert r.status_code == 200 and r.json()["schedule_value"] == {"expr": "0 9 * * *"}


def test_parse_endpoint_live_badge(config) -> None:
    c = TestClient(create_app(config))
    r = c.get("/api/tasks/parse", params={"q": "每周五下午3点回顾本周"})
    assert r.json()["parsed"]["label"] == "每周五 15:00"
    assert c.get("/api/tasks/parse", params={"q": "还没说时间"}).json()["parsed"] is None


def test_note_to_task_with_nl(config) -> None:
    c = TestClient(create_app(config))
    nid = c.post("/api/notes", json={"content": "review notch PR"}).json()["id"]
    r = c.post(f"/api/notes/{nid}/to-task", json={"schedule_nl": "明早9点"})
    assert r.status_code == 200
    t = r.json()
    assert t["schedule_kind"] == "at" and t["schedule_value"]["nl"] == "明早 09:00"
    assert t["linked_note_id"] == nid
    # note 内容里也没有时间、又不给 nl → 422 提示
    nid2 = c.post("/api/notes", json={"content": "整理桌面"}).json()["id"]
    assert c.post(f"/api/notes/{nid2}/to-task", json={}).status_code == 422
