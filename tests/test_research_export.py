"""m5 (deep-research): export a report → memory (agent reads via MCP) / project file."""

import json

import pytest
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.memory.service import MemoryService
from helm.research.engine import ResearchEngine
from helm.research.export import report_to_markdown, report_to_memory_text
from helm.research.service import ResearchService
from tests.test_research import FakeFetcher, FakeLLM, FakeSearcher


def _engine():
    return ResearchEngine(FakeSearcher(), FakeFetcher(), FakeLLM(stop_after=3))


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_report_to_markdown_numbers_citations():
    report = {
        "question": "X vs Y?",
        "summary": "X wins.",
        "claims": [{"text": "X cheaper", "sources": ["https://a.com"]}],
        "sources": [{"url": "https://a.com", "title": "A"}],
        "rounds": 3,
    }
    md = report_to_markdown(report)
    assert "# X vs Y?" in md
    assert "- X cheaper [1]" in md
    assert "1. [A](https://a.com)" in md
    assert report_to_memory_text("X vs Y?", report).startswith("研究「X vs Y?」")


def test_export_to_memory(config):
    db = _db(config)
    with db.session_scope() as s:
        sid = ResearchService(s).run_research("is X better?", _engine()).id
    with db.session_scope() as s:
        out = ResearchService(s).export_to_memory(sid, MemoryService(s))
        assert out["memory_id"] >= 1
    # the memory is now recallable (what the agent would hit via MCP)
    with db.session_scope() as s:
        mems = MemoryService(s).list()
        assert any(m.source == "research" for m in mems)


def test_write_report_file_and_refuse_overwrite(config, tmp_path):
    db = _db(config)
    with db.session_scope() as s:
        sid = ResearchService(s).run_research("q", _engine()).id
    out = tmp_path / "sub" / "report.md"
    with db.session_scope() as s:
        path = ResearchService(s).write_report_file(sid, str(out))
        assert out.read_text(encoding="utf-8").startswith("# q")
    # second write refuses to overwrite
    with db.session_scope() as s:
        with pytest.raises(FileExistsError):
            ResearchService(s).write_report_file(sid, str(out))


def test_export_no_report_raises(config):
    db = _db(config)
    with db.session_scope() as s:
        # a session with no report_json
        from helm.research.models import ResearchSession

        sess = ResearchSession(question="q", status="pending")
        s.add(sess)
        s.flush()
        with pytest.raises(ValueError):
            ResearchService(s).export_to_memory(sess.id, MemoryService(s))


def test_export_routes(config, tmp_path):
    c = TestClient(create_app(config))
    db = Database.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        sid = ResearchService(s).run_research("is X better?", _engine()).id

    mem = c.post(f"/api/research/{sid}/export/memory")
    assert mem.status_code == 200 and mem.json()["memory_id"] >= 1

    out = tmp_path / "r.md"
    f = c.post(f"/api/research/{sid}/export/file", json={"path": str(out)})
    assert f.status_code == 200 and out.exists()
    # overwrite → 400
    assert c.post(f"/api/research/{sid}/export/file", json={"path": str(out)}).status_code == 400
    # unknown session → 404
    assert c.post("/api/research/9999/export/memory").status_code == 404
