"""m1 (deep-research): the iterative engine + persistence, with fake providers
(no web/LLM/cost). Verifies ≥3 rounds and that every claim traces to a gathered
source URL (constraint 180077c3)."""

import json

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.research.engine import ResearchEngine, _extract_json, untrusted
from helm.research.providers import SearchResult
from helm.research.service import ResearchService


class FakeSearcher:
    def __init__(self):
        self.calls = 0

    def search(self, query, limit=5):
        self.calls += 1
        # unique urls per call so rounds gather new sources
        return [SearchResult(url=f"https://ex.com/{self.calls}-{i}", title=f"t{i}", snippet="s") for i in range(2)]


class FakeFetcher:
    def fetch(self, url):
        return f"page body of {url} with facts"


class FakeLLM:
    """Scripts the engine: plan→queries→extract→synthesize→stop. Never stops
    before min_rounds because the engine guards that."""

    def __init__(self, stop_after=3):
        self.stop_after = stop_after
        self.round = 0

    def complete(self, prompt, system=None):
        if "sub-question" in prompt or "sub_question" in prompt or "research strategist" in prompt:
            return json.dumps(["sub a", "sub b", "sub c"])
        if "search queries" in prompt or "planning web searches" in prompt:
            return json.dumps(["query x", "query y"])
        if "Extract facts" in prompt:
            assert system and "untrusted_web_content" in system  # untrusted wrap reached the LLM
            return "extracted note"
        if "Update the research report" in prompt:
            self.round += 1
            # cite a real url + one bogus url (engine must drop the bogus one)
            return json.dumps({
                "summary": f"summary after round {self.round}",
                "claims": [
                    {"text": "claim one", "sources": ["https://ex.com/1-0", "https://bogus.com/x"]},
                ],
            })
        if 'Answer ONLY "yes"' in prompt or "complete, well-cited" in prompt:
            return "yes" if self.round >= self.stop_after else "no"
        return ""


def _engine(**kw):
    return ResearchEngine(FakeSearcher(), FakeFetcher(), FakeLLM(**kw))


def test_engine_runs_min_rounds_and_cites():
    rounds_seen = []
    eng = ResearchEngine(
        FakeSearcher(), FakeFetcher(), FakeLLM(stop_after=3),
        on_event=lambda k, d: rounds_seen.append(k) if k == "round_start" else None,
    )
    report = eng.run("is X better than Y?")
    assert report.rounds >= 3  # constraint 180077c3
    assert rounds_seen.count("round_start") >= 3
    assert report.summary
    assert report.claims
    # every claim's sources are real gathered URLs (bogus dropped)
    gathered = {s["url"] for s in report.sources}
    for c in report.claims:
        assert c["sources"]  # at least one valid citation survives
        assert all(u in gathered for u in c["sources"])
        assert "https://bogus.com/x" not in c["sources"]


def test_engine_stops_at_max_rounds_if_never_satisfied():
    eng = ResearchEngine(FakeSearcher(), FakeFetcher(), FakeLLM(stop_after=99), max_rounds=4)
    report = eng.run("q")
    assert report.rounds == 4  # capped


def test_untrusted_wrap_and_json_extract():
    assert "untrusted_web_content" in untrusted("hi")
    assert _extract_json('```json\n["a","b"]\n```') == ["a", "b"]
    assert _extract_json("prose {\"k\": 1} more") == {"k": 1}
    assert _extract_json("nothing here") is None


def test_run_research_persists(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    with db.session_scope() as s:
        sess = ResearchService(s).run_research("is X better?", _engine())
        sid = sess.id
        assert sess.status == "completed"
        assert sess.rounds_done >= 3
    with db.session_scope() as s:
        svc = ResearchService(s)
        loaded = svc.get(sid)
        report = json.loads(loaded.report_json)
        assert report["claims"]
        assert len(svc.sources(sid)) > 0


class _BoomLLM:
    def complete(self, prompt, system=None):
        raise RuntimeError("llm down")


def test_run_research_failure_recorded(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    eng = ResearchEngine(FakeSearcher(), FakeFetcher(), _BoomLLM())
    with db.session_scope() as s:
        sess = ResearchService(s).run_research("q", eng)
        assert sess.status == "failed" and "llm down" in sess.error


def test_research_routes(config):
    c = TestClient(create_app(config))
    assert c.get("/api/research").json()["sessions"] == []
    assert c.get("/api/research/999").status_code == 404
