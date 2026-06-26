"""m3 (agent-orchestration): live ACP session plumbing + the run WS.

No real `claude` is launched (that's a paid external call). The WS is exercised
end-to-end with a stub adapter whose `command` emits canned Claude-format
stream-json via a local python subprocess — validating spawn → parse → stream.
"""

import json
import sys

import pytest
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.orchestration.adapters import (
    ClaudeCodeAdapter,
    register_adapter,
    unregister_adapter,
)
from helm.orchestration.session import iter_process_lines


@pytest.mark.anyio
async def test_iter_process_lines_yields_stdout():
    argv = [sys.executable, "-c", "print('a'); print('b'); print('c')"]
    lines = [ln.strip() async for ln in iter_process_lines(argv)]
    assert lines == ["a", "b", "c"]


@pytest.mark.anyio
async def test_iter_process_lines_missing_binary_raises():
    with pytest.raises(FileNotFoundError):
        async for _ in iter_process_lines(["definitely-not-a-real-binary-xyz"]):
            pass


# ---- WS end-to-end with a canned-output stub adapter -----------------------

CANNED = [
    {"type": "system", "subtype": "init", "session_id": "s", "model": "m"},
    {"type": "assistant", "session_id": "s", "message": {"content": [{"type": "text", "text": "hi there"}]}},
    {"type": "result", "is_error": False, "session_id": "s", "result": "ok"},
]


class _StubAdapter(ClaudeCodeAdapter):
    """Reuses the real Claude parser but emits canned stream-json locally."""

    name = "stub-claude"

    def command(self, prompt, cwd=None):
        script = "import sys\n" + "\n".join(
            f"print({json.dumps(line)!r})" for line in CANNED
        )
        return [sys.executable, "-c", script]


class _MissingBinAdapter(ClaudeCodeAdapter):
    name = "stub-missing"

    def command(self, prompt, cwd=None):
        return ["definitely-not-a-real-binary-xyz"]


@pytest.fixture
def stub_adapters():
    register_adapter(_StubAdapter())
    register_adapter(_MissingBinAdapter())
    yield
    unregister_adapter("stub-claude")
    unregister_adapter("stub-missing")


def test_run_ws_streams_acp_events(config, stub_adapters):
    c = TestClient(create_app(config))
    with c.websocket_connect("/api/orchestration/runs/ws") as ws:
        ws.send_json({"agent": "stub-claude", "prompt": "hello"})
        started = ws.receive_json()
        assert started["type"] == "run_started"
        run_id = started["run_id"]

        types = []
        while True:
            msg = ws.receive_json()
            if msg.get("type") == "done":
                break
            types.append(msg["type"])
        # init → status, text → message, result → session_end
        assert types == ["status", "message", "session_end"]

    # run persisted as completed
    run = c.get(f"/api/orchestration/runs/{run_id}").json()
    assert run["status"] == "completed" and run["ended_at"] is not None


def test_run_ws_unknown_agent_errors(config):
    c = TestClient(create_app(config))
    with c.websocket_connect("/api/orchestration/runs/ws") as ws:
        ws.send_json({"agent": "gemini", "prompt": "x"})
        msg = ws.receive_json()
        assert msg["type"] == "error" and "gemini" in msg["error"]


def test_run_ws_missing_binary_fails_run(config, stub_adapters):
    c = TestClient(create_app(config))
    with c.websocket_connect("/api/orchestration/runs/ws") as ws:
        ws.send_json({"agent": "stub-missing", "prompt": "x"})
        assert ws.receive_json()["type"] == "run_started"
        err = ws.receive_json()
        assert err["type"] == "error" and "not found" in err["error"]
    # the run is recorded failed
    runs = c.get("/api/orchestration/runs").json()["runs"]
    assert runs and runs[0]["status"] == "failed"
