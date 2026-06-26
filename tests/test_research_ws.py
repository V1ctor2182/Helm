"""m3 (deep-research): cancel/resume in run_research + the research WS.

No real providers — the WS test monkeypatches build_engine to a fake-provider
engine (canned LLM/search), so spawn → progress → persist is verified with zero
network/LLM cost."""

import json

from fastapi.testclient import TestClient

import helm.research.routes as research_routes
from helm.app import create_app
from helm.db import Database
from helm.research.engine import ResearchEngine
from helm.research.service import ResearchService
from tests.test_research import FakeFetcher, FakeLLM, FakeSearcher


def _fake_engine(on_event=None, **kw):
    return ResearchEngine(FakeSearcher(), FakeFetcher(), FakeLLM(stop_after=3), on_event=on_event)


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_run_research_cancel_marks_stopped(config):
    db = _db(config)
    # cancel immediately → engine breaks at round 1 boundary, status=stopped
    with db.session_scope() as s:
        sess = ResearchService(s).run_research("q", _fake_engine(), cancel=lambda: True)
        assert sess.status == "stopped"


def test_run_research_resume_continues(config):
    db = _db(config)
    with db.session_scope() as s:
        first = ResearchService(s).run_research("q", _fake_engine(), cancel=lambda: True)
        sid = first.id
        assert first.status == "stopped"
        rounds_after_stop = first.rounds_done
    with db.session_scope() as s:
        resumed = ResearchService(s).run_research("", _fake_engine(), resume_session_id=sid)
        assert resumed.id == sid
        assert resumed.status == "completed"
        assert resumed.rounds_done >= rounds_after_stop  # accumulated
        report = json.loads(resumed.report_json)
        assert report["claims"]


def test_run_research_resume_missing_raises(config):
    db = _db(config)
    with db.session_scope() as s:
        import pytest

        with pytest.raises(KeyError):
            ResearchService(s).run_research("q", _fake_engine(), resume_session_id=123)


# ---- WS end-to-end (fake engine via monkeypatch) ---------------------------

def test_research_ws_streams_and_persists(config, monkeypatch):
    captured = {}

    def fake_build_engine(session, box, provider_id, model, *, on_event=None, **kw):
        captured["provider_id"] = provider_id
        return _fake_engine(on_event=on_event)

    monkeypatch.setattr(research_routes, "build_engine", fake_build_engine)
    c = TestClient(create_app(config))
    with c.websocket_connect("/api/research/ws") as ws:
        ws.send_json({"provider_id": 1, "model": "m", "question": "is X better?"})
        progress_kinds = []
        session_id = None
        while True:
            msg = ws.receive_json()
            if msg["type"] == "done":
                session_id = msg["session_id"]
                assert msg["status"] == "completed"
                break
            if msg["type"] == "progress":
                progress_kinds.append(msg["kind"])
    assert "round_start" in progress_kinds and "done" in progress_kinds
    # persisted + readable via REST
    got = c.get(f"/api/research/{session_id}").json()
    assert got["report"]["claims"] and got["sources"]


def test_research_ws_unknown_provider_errors(config, monkeypatch):
    def boom(*a, **k):
        raise KeyError("provider 9 not found")

    monkeypatch.setattr(research_routes, "build_engine", boom)
    c = TestClient(create_app(config))
    with c.websocket_connect("/api/research/ws") as ws:
        ws.send_json({"provider_id": 9, "model": "m", "question": "q"})
        msg = ws.receive_json()
        assert msg["type"] == "error" and "not found" in msg["error"]
