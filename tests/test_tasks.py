"""m4 (journal-notes-tasks): scheduled-task model + schedule math + note→task."""

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.tasks.schedule import compute_next_run
from helm.tasks.service import TaskService

UTC = timezone.utc


# ── schedule math ───────────────────────────────────────────────────────────

def test_compute_next_run_cron():
    after = datetime(2026, 6, 27, 8, 0, tzinfo=UTC)
    nxt = compute_next_run("cron", {"expr": "0 9 * * *"}, after)
    assert nxt == datetime(2026, 6, 27, 9, 0, tzinfo=UTC)
    assert compute_next_run("cron", {"expr": "not a cron"}, after) is None


def test_compute_next_run_every():
    after = datetime(2026, 6, 27, 8, 0, tzinfo=UTC)
    assert compute_next_run("every", {"seconds": 3600}, after) == after + timedelta(hours=1)
    assert compute_next_run("every", {"seconds": 0}, after) is None


def test_compute_next_run_at_one_shot():
    after = datetime(2026, 6, 27, 8, 0, tzinfo=UTC)
    future = "2026-06-27T10:00:00+00:00"
    past = "2026-06-27T07:00:00+00:00"
    assert compute_next_run("at", {"at": future}, after) == datetime(2026, 6, 27, 10, 0, tzinfo=UTC)
    assert compute_next_run("at", {"at": past}, after) is None  # past one-shot won't fire


# ── service ───────────────────────────────────────────────────────────────

def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_create_computes_next_run_and_due(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = TaskService(s)
        t = svc.create("daily digest", "summarize unread mail", "cron", {"expr": "0 9 * * *"})
        assert t.next_run is not None
        tid = t.id
        # not due yet (next_run in the future)
        assert svc.due() == []
        # a task already past-due
        past = svc.create("now", "do it", "every", {"seconds": 60})
        past.next_run = datetime(2000, 1, 1, tzinfo=UTC)
        s.flush()
        due_ids = {x.id for x in svc.due()}
        assert past.id in due_ids and tid not in due_ids


def test_record_run_advances_and_disarms(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = TaskService(s)
        recurring = svc.create("r", "p", "every", {"seconds": 3600})
        svc.record_run(recurring, "ok", "did the thing")
        assert recurring.run_count == 1 and recurring.last_status == "ok"
        # recurring task re-arms ~1h out (in the future)
        assert recurring.next_run is not None
        assert recurring.next_run > datetime.now(UTC) + timedelta(minutes=59)
        assert len(svc.runs(recurring.id)) == 1

        once = svc.create("once", "p", "at", {"at": "2026-06-27T10:00:00+00:00"})
        svc.record_run(once, "ok")
        assert once.next_run is None  # one-shot disarms after firing


def test_create_rejects_bad_kind(config):
    db = _db(config)
    with db.session_scope() as s:
        import pytest

        with pytest.raises(ValueError):
            TaskService(s).create("x", "p", "bogus", {})


# ── routes + note→task ──────────────────────────────────────────────────────

def test_task_routes(config):
    c = TestClient(create_app(config))
    assert c.get("/api/tasks").json()["tasks"] == []
    created = c.post("/api/tasks", json={
        "name": "digest", "prompt": "summarize mail", "schedule_kind": "cron",
        "schedule_value": {"expr": "0 9 * * *"},
    })
    assert created.status_code == 200
    tid = created.json()["id"]
    assert created.json()["next_run"] is not None

    assert c.post("/api/tasks", json={"name": "x", "prompt": "p", "schedule_kind": "nope", "schedule_value": {}}).status_code == 422
    assert c.post(f"/api/tasks/{tid}/enabled", json={"enabled": False}).json()["enabled"] is False
    assert c.get(f"/api/tasks/{tid}/runs").json()["runs"] == []
    assert c.delete(f"/api/tasks/{tid}").status_code == 200
    assert c.get("/api/tasks/999/runs").status_code == 404


def test_note_to_task(config):
    c = TestClient(create_app(config))
    note = c.post("/api/notes", json={"content": "每天汇总未读邮件"}).json()
    res = c.post(f"/api/notes/{note['id']}/to-task", json={
        "schedule_kind": "cron", "schedule_value": {"expr": "0 9 * * *"},
    })
    assert res.status_code == 200
    body = res.json()
    assert body["prompt"] == "每天汇总未读邮件"
    assert body["linked_note_id"] == note["id"]
    assert body["next_run"] is not None
    # bad schedule → 422; missing note → 404
    assert c.post(f"/api/notes/{note['id']}/to-task", json={"schedule_kind": "x", "schedule_value": {}}).status_code == 422
    assert c.post("/api/notes/999/to-task", json={"schedule_kind": "cron", "schedule_value": {"expr": "0 9 * * *"}}).status_code == 404
