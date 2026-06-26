"""m5 (journal-notes-tasks): task executor + scheduler tick + AI journal summary.
No real agent/LLM is invoked (paid) — a stub adapter (canned stream-json via a
local python subprocess) and fake LLMs drive everything headlessly."""

import json
import sys
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

import helm.notes.routes as notes_routes
from helm.app import create_app
from helm.chat.service import ProviderService
from helm.crypto import SecretBox
from helm.db import Database
from helm.notes.summary import summarize_journal
from helm.orchestration.adapters import (
    ClaudeCodeAdapter,
    register_adapter,
    unregister_adapter,
)
from helm.tasks.executor import AgentTaskExecutor
from helm.tasks.scheduler import tick
from helm.tasks.service import TaskService

UTC = timezone.utc


# ── executor (stub adapter, local subprocess) ───────────────────────────────

class _StubAdapter(ClaudeCodeAdapter):
    name = "stub-task"

    def command(self, prompt, cwd=None):
        lines = [
            {"type": "assistant", "session_id": "s", "message": {"content": [{"type": "text", "text": "working"}]}},
            {"type": "result", "is_error": False, "result": "summary: 3 unread", "session_id": "s"},
        ]
        script = "import sys\n" + "\n".join(f"print({json.dumps(l)!r})" for l in lines)
        return [sys.executable, "-c", script]


@pytest.fixture
def stub_task_adapter():
    register_adapter(_StubAdapter())
    yield
    unregister_adapter("stub-task")


@pytest.mark.anyio
async def test_agent_executor_collects_result(stub_task_adapter):
    status, output = await AgentTaskExecutor(agent="stub-task").execute("digest mail")
    assert status == "ok"
    assert "3 unread" in output


@pytest.mark.anyio
async def test_agent_executor_missing_binary():
    class _Missing(ClaudeCodeAdapter):
        name = "stub-missing-task"

        def command(self, prompt, cwd=None):
            return ["definitely-not-real-binary-xyz"]

    register_adapter(_Missing())
    try:
        status, output = await AgentTaskExecutor(agent="stub-missing-task").execute("x")
        assert status == "error" and "not found" in output
    finally:
        unregister_adapter("stub-missing-task")


# ── scheduler tick (fake executor) ──────────────────────────────────────────

class _FakeExecutor:
    def __init__(self):
        self.calls = []

    async def execute(self, prompt):
        self.calls.append(prompt)
        return "ok", f"ran: {prompt}"


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


@pytest.mark.anyio
async def test_tick_fires_due_tasks(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = TaskService(s)
        t = svc.create("digest", "summarize mail", "every", {"seconds": 3600})
        t.next_run = datetime(2000, 1, 1, tzinfo=UTC)  # overdue
        not_due = svc.create("later", "p", "cron", {"expr": "0 9 * * *"})  # future
        tid, ndid = t.id, not_due.id

    ex = _FakeExecutor()
    fired = await tick(db, ex)
    assert fired == 1 and ex.calls == ["summarize mail"]

    with db.session_scope() as s:
        svc = TaskService(s)
        assert len(svc.runs(tid)) == 1 and svc.runs(tid)[0].status == "ok"
        assert svc.get(tid).run_count == 1
        assert svc.runs(ndid) == []  # future task untouched


@pytest.mark.anyio
async def test_tick_records_executor_failure(config):
    db = _db(config)
    with db.session_scope() as s:
        t = TaskService(s).create("x", "p", "every", {"seconds": 60})
        t.next_run = datetime(2000, 1, 1, tzinfo=UTC)
        tid = t.id

    class _Boom:
        async def execute(self, prompt):
            raise RuntimeError("agent crashed")

    await tick(db, _Boom())
    with db.session_scope() as s:
        runs = TaskService(s).runs(tid)
        assert runs[0].status == "error" and "crashed" in runs[0].output


# ── AI journal summary ──────────────────────────────────────────────────────

class _FakeLLM:
    def __init__(self, *a, **k):
        pass

    def complete(self, prompt, system=None):
        assert "日记条目" in prompt
        return "今天推进了 m5,心情不错。"


def test_summarize_journal_unit():
    class L:
        def complete(self, p, system=None):
            return "  小结  "

    assert summarize_journal([], L()) == ""
    assert summarize_journal(["a", "  "], L()) == "小结"


def test_journal_summary_route(config, monkeypatch):
    monkeypatch.setattr(notes_routes, "ChatLLM", _FakeLLM)
    c = TestClient(create_app(config))
    # no entries → 404
    assert c.post("/api/notes/journal/summary", json={"provider_id": 1, "model": "m"}).status_code == 404

    # a provider + a journal entry
    db = Database.from_data_dir(config.data_dir)
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        pid = ProviderService(s, box).create(type="openai", name="O", base_url="u", api_key="k", models=["m"]).id
    c.post("/api/notes", json={"content": "今天写了定时任务", "kind": "journal", "journal_date": "2026-06-27"})

    res = c.post("/api/notes/journal/summary", json={"provider_id": pid, "model": "m", "journal_date": "2026-06-27", "save": True})
    assert res.status_code == 200
    assert "m5" in res.json()["summary"]
    assert res.json()["saved_note_id"] is not None
    # unknown provider → 404
    assert c.post("/api/notes/journal/summary", json={"provider_id": 999, "model": "m", "journal_date": "2026-06-27"}).status_code == 404
