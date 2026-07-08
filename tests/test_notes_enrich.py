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
            # feed 级 <title>(查询描述)必须被跳过——只取 <entry> 内的(回归守卫)
            return httpx.Response(200, text=(
                "<feed><title>ArXiv Query: search_query=…</title>"
                "<entry><title>Paper T</title>"
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


def test_norm_label_collapses_aliases() -> None:
    """F1:label 归一化——来源/子类修饰塌回泛类(prompt 兜底网)。"""
    from helm.notes.enrich import _norm_label

    assert _norm_label("YouTube视频") == "视频"
    assert _norm_label("岗位") == "招聘"
    assert _norm_label("GitHub仓库") == "仓库"
    assert _norm_label("招聘") == "招聘"  # 已规范的不动
    assert _norm_label("骑行路线") == "骑行路线"  # 不认识的原样返回


def test_fetch_layer_sets_family_default(config, monkeypatch) -> None:
    """F1:抓取层按 type 给 family 默认(没 provider 也有视觉族)。"""
    from fastapi.testclient import TestClient

    from helm.app import create_app
    from helm.notes import enrich as enrich_mod

    async def fake_fetch(url, client=None):
        return {"url": url, "type": "youtube", "title": "V"}

    monkeypatch.setattr(enrich_mod, "fetch_link_meta", fake_fetch)
    c = TestClient(create_app(config))
    nid = c.post("/api/notes", json={"content": "看 https://youtu.be/x"}).json()["id"]
    meta = next(n for n in c.get("/api/notes").json()["notes"] if n["id"] == nid)["meta"]
    assert meta["family"] == "video"  # youtube → video 族


def test_llm_layer_family_label_and_existing_injection(config, monkeypatch) -> None:
    """F1:LLM 出 family(白名单)+label(归一化);已有 label 注入 prompt 供复用。"""
    from fastapi.testclient import TestClient

    from helm.app import create_app
    from helm.notes import enrich as enrich_mod
    import helm.ai as ai_mod

    async def fake_fetch(url, client=None):
        return {"url": url, "type": "article", "title": "某公司后端工程师"}

    captured: dict = {}

    async def fake_llm(session, box, provider, system, user, cwd=None):
        captured["system"] = system
        return '{"family":"link","label":"职位","summary":"某公司招后端","tags":["招聘"],"topic":"求职"}'

    monkeypatch.setattr(enrich_mod, "fetch_link_meta", fake_fetch)
    monkeypatch.setattr(ai_mod, "pick_provider", lambda s, b: object())
    monkeypatch.setattr(ai_mod, "llm_once", fake_llm)
    c = TestClient(create_app(config))
    nid = c.post("/api/notes", json={"content": "招聘 https://linkedin.com/jobs/123"}).json()["id"]
    meta = next(n for n in c.get("/api/notes").json()["notes"] if n["id"] == nid)["meta"]
    assert meta["family"] == "link"        # 白名单
    assert meta["label"] == "招聘"          # 职位 → 招聘(alias 归一化)
    assert meta["topic"] == "求职"          # label 与 topic 正交
    assert "暂无" in captured["system"]     # 首条:已有 label 为空


def test_all_urls_dedup_and_order() -> None:
    from helm.notes.enrich import all_urls

    t = "看 https://a.com/x 和 https://b.com/y 还有重复 https://a.com/x"
    assert all_urls(t) == ["https://a.com/x", "https://b.com/y"]


@pytest.mark.anyio
async def test_multi_link_note_gets_links_array(config, monkeypatch) -> None:
    """两个链接的速记:meta.links=2 张,顶层字段=第一个(向后兼容)。"""
    from fastapi.testclient import TestClient

    from helm.app import create_app
    from helm.notes import enrich as enrich_mod

    async def fake_fetch(url, client=None):
        return {"url": url, "type": "article", "title": f"T:{url[-1]}", "site": "s"}

    monkeypatch.setattr(enrich_mod, "fetch_link_meta", fake_fetch)
    c = TestClient(create_app(config))
    r = c.post("/api/notes", json={"content": "对比 https://x.com/a 和 https://y.com/b", "kind": "note"})
    nid = r.json()["id"]
    got = c.get("/api/notes", params={"kind": "note"}).json()["notes"]
    meta = next(n for n in got if n["id"] == nid)["meta"]
    assert meta["url"] == "https://x.com/a"          # 顶层=第一个
    assert len(meta["links"]) == 2
    assert meta["links"][1]["url"] == "https://y.com/b"


def test_patch_meta_rewrites_topic(config) -> None:
    """AI 归类纠错:PATCH /notes/{id} 带 meta 整份回写(移出集合)。"""
    from fastapi.testclient import TestClient

    from helm.app import create_app

    c = TestClient(create_app(config))
    nid = c.post("/api/notes", json={"content": "hello", "kind": "note"}).json()["id"]
    r = c.patch(f"/api/notes/{nid}", json={"meta": {"type": "text", "topic": "测试集合"}})
    assert r.status_code == 200
    assert r.json()["meta"]["topic"] == "测试集合"
    # 移出集合 = topic 拿掉后整份回写
    r2 = c.patch(f"/api/notes/{nid}", json={"meta": {"type": "text"}})
    assert "topic" not in (r2.json()["meta"] or {})
