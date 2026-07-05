"""速记 AI 管线:URL 提取 / 抓取层路由(oEmbed·arXiv·OG) / LLM JSON 解析。"""

from __future__ import annotations

import httpx
import pytest

from helm.notes.enrich import _meta_tag, _parse_llm_json, fetch_link_meta, first_url


def test_first_url_extracts_and_trims() -> None:
    assert first_url("看这个 https://youtu.be/abc123 很酷。") == "https://youtu.be/abc123"
    assert first_url("论文 https://arxiv.org/abs/2406.01234,读一下") == "https://arxiv.org/abs/2406.01234"
    assert first_url("没有链接") is None


def test_meta_tag_both_attribute_orders() -> None:
    html = (
        '<meta property="og:title" content="Helm 设计"/>'
        '<meta content="一段描述" name="description">'
    )
    assert _meta_tag(html, "og:title") == "Helm 设计"
    assert _meta_tag(html, "description") == "一段描述"


def test_parse_llm_json_tolerates_prose() -> None:
    assert _parse_llm_json('好的,这是结果:{"type":"paper","summary":"S"}')["type"] == "paper"
    assert _parse_llm_json("不是 json") == {}


@pytest.mark.anyio
async def test_fetch_link_meta_routes_youtube_arxiv_og() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        if "youtube.com/oembed" in url:
            return httpx.Response(200, json={
                "title": "Demo Video", "author_name": "Ch", "thumbnail_url": "https://i.ytimg.com/x.jpg"})
        if "export.arxiv.org" in url:
            return httpx.Response(200, text=(
                "<feed><entry><title>Paper T</title>"
                "<summary> Long abstract. </summary></entry></feed>"))
        return httpx.Response(200, text=(
            "<html><head><title>Site T</title>"
            '<meta property="og:description" content="Desc"/>'
            '<meta property="og:image" content="https://x/i.png"/></head></html>'))

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        yt = await fetch_link_meta("https://www.youtube.com/watch?v=abc", client)
        assert (yt["type"], yt["title"], yt["image"]) == (
            "youtube", "Demo Video", "https://i.ytimg.com/x.jpg")
        ax = await fetch_link_meta("https://arxiv.org/abs/2406.01234", client)
        assert (ax["type"], ax["title"]) == ("paper", "Paper T")
        assert "Long abstract" in ax["abstract"]
        og = await fetch_link_meta("https://example.com/post", client)
        assert (og["type"], og["title"], og["summary_raw"], og["image"]) == (
            "article", "Site T", "Desc", "https://x/i.png")


@pytest.mark.anyio
async def test_fetch_link_meta_degrades_on_error() -> None:
    transport = httpx.MockTransport(lambda r: httpx.Response(500))
    async with httpx.AsyncClient(transport=transport) as client:
        meta = await fetch_link_meta("https://broken.example/x", client)
    assert meta["url"] == "https://broken.example/x"
    assert meta["type"] == "article"  # 最小降级,卡片仍能显示裸链接


def test_create_note_background_enrich_wires_up(config, monkeypatch) -> None:
    """POST /api/notes 的后台 enrich 真被调度并落 meta(TestClient 同步执行)。"""
    from fastapi.testclient import TestClient

    from helm.app import create_app
    from helm.notes import enrich as enrich_mod

    async def fake_fetch(url, client=None):
        return {"url": url, "type": "youtube", "title": "T", "image": "i.jpg"}

    monkeypatch.setattr(enrich_mod, "fetch_link_meta", fake_fetch)
    c = TestClient(create_app(config))
    r = c.post("/api/notes", json={"content": "看 https://youtu.be/x", "kind": "note"})
    assert r.status_code == 200
    nid = r.json()["id"]
    got = c.get("/api/notes", params={"kind": "note"}).json()["notes"]
    meta = next(n for n in got if n["id"] == nid)["meta"]
    assert meta and meta["type"] == "youtube" and meta["title"] == "T"
