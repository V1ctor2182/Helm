"""m2 (agent-orchestration): ACP adapter parsing + agent run state machine."""

import json

import pytest
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.orchestration.acp import AcpEventType, RunStatus
from helm.orchestration.adapters import (
    ClaudeCodeAdapter,
    available_adapters,
    get_adapter,
)
from helm.orchestration.runs import AgentRunService


# ---- adapter ---------------------------------------------------------------

def test_registry_has_claude_code():
    assert "claude-code" in available_adapters()
    assert isinstance(get_adapter("claude-code"), ClaudeCodeAdapter)
    with pytest.raises(KeyError):
        get_adapter("codex")  # P1, not in MVP


def test_command_is_stream_json():
    cmd = ClaudeCodeAdapter().command("do a thing", cwd="/p")
    assert cmd[0] == "claude" and "stream-json" in cmd


def test_parse_init_message_toolcall_result():
    a = ClaudeCodeAdapter()
    # system init
    ev = a.parse_line(json.dumps({"type": "system", "subtype": "init", "session_id": "s1", "model": "claude", "tools": ["Read"], "cwd": "/p"}))
    assert ev[0].type == AcpEventType.STATUS and ev[0].data["model"] == "claude"

    # assistant turn with text + a tool_use → two events
    ev = a.parse_line(json.dumps({
        "type": "assistant", "session_id": "s1",
        "message": {"content": [
            {"type": "text", "text": "let me read it"},
            {"type": "tool_use", "id": "t1", "name": "Read", "input": {"file_path": "a.py"}},
        ]},
    }))
    assert [e.type for e in ev] == [AcpEventType.MESSAGE, AcpEventType.TOOL_CALL]
    assert ev[1].data["name"] == "Read" and ev[1].data["input"]["file_path"] == "a.py"

    # tool_result (content as list of blocks → flattened)
    ev = a.parse_line(json.dumps({
        "type": "user", "session_id": "s1",
        "message": {"content": [
            {"type": "tool_result", "tool_use_id": "t1", "content": [{"type": "text", "text": "file body"}]},
        ]},
    }))
    assert ev[0].type == AcpEventType.TOOL_RESULT and ev[0].data["content"] == "file body"

    # result
    ev = a.parse_line(json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "done", "session_id": "s1"}))
    assert ev[0].type == AcpEventType.SESSION_END and ev[0].data["is_error"] is False


def test_parse_ignores_noise():
    a = ClaudeCodeAdapter()
    assert a.parse_line("") == []
    assert a.parse_line("not json at all") == []
    assert a.parse_line(json.dumps({"type": "unknown"})) == []


def test_event_to_dict_serializable():
    ev = ClaudeCodeAdapter().parse_line(
        json.dumps({"type": "result", "is_error": True, "session_id": "s"})
    )[0]
    d = ev.to_dict()
    assert d["type"] == "session_end" and d["session_id"] == "s"
    json.dumps(d)  # must be JSON-serializable for the WS


# ---- run state machine -----------------------------------------------------

def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_run_lifecycle_advances_on_events(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = AgentRunService(s)
        run = svc.create("claude-code", prompt="hi", project_path="/p")
        assert run.status == RunStatus.PENDING.value
        rid = run.id

        # first event ⇒ running
        svc.consume_line(run, json.dumps({"type": "system", "subtype": "init", "session_id": "s1"}))
        assert run.status == RunStatus.RUNNING.value

        # result(success) ⇒ completed + ended_at
        svc.consume_line(run, json.dumps({"type": "result", "is_error": False, "session_id": "s1"}))
        assert run.status == RunStatus.COMPLETED.value
        assert run.ended_at is not None

    with db.session_scope() as s:
        assert AgentRunService(s).get(rid).status == RunStatus.COMPLETED.value


def test_run_fails_on_error_result(config):
    db = _db(config)
    with db.session_scope() as s:
        svc = AgentRunService(s)
        run = svc.create("claude-code")
        svc.consume_line(run, json.dumps({"type": "result", "is_error": True}))
        assert run.status == RunStatus.FAILED.value


def test_create_unknown_agent_raises(config):
    db = _db(config)
    with db.session_scope() as s:
        with pytest.raises(KeyError):
            AgentRunService(s).create("gemini")


# ---- routes ----------------------------------------------------------------

def test_orchestration_run_routes(config):
    c = TestClient(create_app(config))
    assert "claude-code" in c.get("/api/orchestration/agents").json()["agents"]
    assert c.get("/api/orchestration/runs").json()["runs"] == []
    assert c.get("/api/orchestration/runs/999").status_code == 404
