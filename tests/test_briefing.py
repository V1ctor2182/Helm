"""Briefing(Today 右柱世界输入)——HN 头条,假 transport 全覆盖。"""

import httpx
from fastapi.testclient import TestClient

from helm import briefing
from helm.app import create_app


def _fake_client() -> httpx.AsyncClient:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("topstories.json"):
            return httpx.Response(200, json=[1, 2, 3, 4])
        sid = int(request.url.path.split("/")[-1].split(".")[0])
        if sid == 2:
            return httpx.Response(200, json={})  # 无 title,跳过
        return httpx.Response(
            200,
            json={"title": f"Story {sid}", "url": f"https://x/{sid}", "time": 1_700_000_000},
        )

    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


def test_briefing_top3_skips_broken(config, monkeypatch):
    briefing.reset_cache_for_tests()
    monkeypatch.setattr(briefing, "_make_client", _fake_client)
    c = TestClient(create_app(config))
    r = c.get("/api/briefing")
    assert r.status_code == 200
    items = r.json()["items"]
    assert [i["title"] for i in items] == ["Story 1", "Story 3", "Story 4"]
    assert items[0]["source"] == "Hacker News"
    assert "天前" in items[0]["ago"] or "小时前" in items[0]["ago"] or "分钟前" in items[0]["ago"]


def test_briefing_offline_returns_empty(config, monkeypatch):
    briefing.reset_cache_for_tests()

    def dead_client() -> httpx.AsyncClient:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("offline")

        return httpx.AsyncClient(transport=httpx.MockTransport(handler))

    monkeypatch.setattr(briefing, "_make_client", dead_client)
    c = TestClient(create_app(config))
    assert c.get("/api/briefing").json() == {"items": []}


def test_briefing_cache_hits(config, monkeypatch):
    briefing.reset_cache_for_tests()
    calls = {"n": 0}

    def counting_client() -> httpx.AsyncClient:
        calls["n"] += 1
        return _fake_client()

    monkeypatch.setattr(briefing, "_make_client", counting_client)
    c = TestClient(create_app(config))
    c.get("/api/briefing")
    c.get("/api/briefing")
    assert calls["n"] == 1  # 10 分钟内不重取
