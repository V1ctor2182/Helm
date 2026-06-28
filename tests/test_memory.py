"""m1 (memory): CRUD + keyword recall over /api/memories."""

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.memory.service import keyword_similarity


def _client(config) -> TestClient:
    return TestClient(create_app(config))


def test_memory_crud(config):
    c = _client(config)
    assert c.get("/api/memories").json()["memories"] == []

    created = c.post(
        "/api/memories",
        json={"text": "用户偏好 dark mode", "category": "preference", "tags": ["ui"]},
    )
    assert created.status_code == 200
    m = created.json()
    assert m["id"] >= 1
    assert m["category"] == "preference"
    assert m["tags"] == ["ui"]
    assert m["uses"] == 0
    assert m["source"] == "manual"

    listed = c.get("/api/memories").json()["memories"]
    assert len(listed) == 1

    got = c.get(f"/api/memories/{m['id']}")
    assert got.status_code == 200
    assert got.json()["text"] == "用户偏好 dark mode"

    patched = c.patch(
        f"/api/memories/{m['id']}", json={"text": "用户偏好暗色主题", "pinned": True}
    )
    assert patched.status_code == 200
    assert patched.json()["text"] == "用户偏好暗色主题"
    assert patched.json()["pinned"] is True

    deleted = c.delete(f"/api/memories/{m['id']}")
    assert deleted.status_code == 200
    assert c.get(f"/api/memories/{m['id']}").status_code == 404


def test_memory_missing_returns_404(config):
    c = _client(config)
    assert c.get("/api/memories/999").status_code == 404
    assert c.patch("/api/memories/999", json={"text": "x"}).status_code == 404
    assert c.delete("/api/memories/999").status_code == 404


def test_memory_validation(config):
    c = _client(config)
    assert c.post("/api/memories", json={"text": "   "}).status_code == 422
    assert (
        c.post("/api/memories", json={"text": "ok", "category": "bogus"}).status_code
        == 422
    )


def test_memory_category_filter_and_pin_order(config):
    c = _client(config)
    c.post("/api/memories", json={"text": "fact one", "category": "fact"})
    c.post(
        "/api/memories",
        json={"text": "a pinned decision", "category": "decision", "pinned": True},
    )
    c.post("/api/memories", json={"text": "another fact", "category": "fact"})

    facts = c.get("/api/memories", params={"category": "fact"}).json()["memories"]
    assert len(facts) == 2
    assert {m["category"] for m in facts} == {"fact"}

    # pinned sorts first regardless of recency
    everything = c.get("/api/memories").json()["memories"]
    assert everything[0]["pinned"] is True

    pinned_only = c.get("/api/memories", params={"pinned": True}).json()["memories"]
    assert len(pinned_only) == 1


def test_memory_keyword_search(config):
    c = _client(config)
    c.post("/api/memories", json={"text": "the cat sat on the mat"})
    c.post("/api/memories", json={"text": "dogs are loyal companions"})
    c.post("/api/memories", json={"text": "a cat and a dog"})

    res = c.get("/api/memories/search", params={"q": "cat"}).json()["results"]
    # both cat-mentioning memories match; the loyal-dogs one does not
    texts = [r["text"] for r in res]
    assert any("cat sat" in t for t in texts)
    assert all("loyal companions" not in t for t in texts)
    assert all(r["score"] > 0 for r in res)
    # ranked descending by score
    scores = [r["score"] for r in res]
    assert scores == sorted(scores, reverse=True)

    empty = c.get("/api/memories/search", params={"q": "xyzzy"}).json()["results"]
    assert empty == []


def test_keyword_similarity_unit():
    assert keyword_similarity("", "anything") == 0.0
    assert keyword_similarity("cat dog", "cat dog") == 1.0
    # jaccard of {cat,dog} vs {cat,fish} = 1/3
    assert abs(keyword_similarity("cat dog", "cat fish") - 1 / 3) < 1e-9


def test_memory_export_import_roundtrip(config):
    c = _client(config)
    c.post("/api/memories", json={"text": "fact A", "category": "fact", "tags": ["x"]})
    c.post(
        "/api/memories",
        json={"text": "pref B", "category": "preference", "pinned": True},
    )

    export = c.get("/api/memories/export").json()
    assert export["version"] == 1
    assert len(export["memories"]) == 2

    # import into a fresh store → append (default)
    c2 = _client(config.__class__(data_dir=config.data_dir.parent / "other"))
    imported = c2.post("/api/memories/import", json={"memories": export["memories"]})
    assert imported.status_code == 200
    assert imported.json()["imported"] == 2
    got = c2.get("/api/memories").json()["memories"]
    assert {m["text"] for m in got} == {"fact A", "pref B"}
    assert any(m["pinned"] and m["tags"] == [] for m in got)
    # pinned/tags survived the round-trip
    a = next(m for m in got if m["text"] == "fact A")
    assert a["tags"] == ["x"]


def test_memory_import_replace_and_skips_blank(config):
    c = _client(config)
    c.post("/api/memories", json={"text": "old one"})
    # replace=True wipes existing; blank rows are skipped
    res = c.post(
        "/api/memories/import",
        json={"memories": [{"text": "new one"}, {"text": "   "}], "replace": True},
    )
    assert res.json()["imported"] == 1
    texts = [m["text"] for m in c.get("/api/memories").json()["memories"]]
    assert texts == ["new one"]


def test_memory_touch_bumps_uses(config):
    """touch() is the recall counter m2/m6 call when surfacing a memory."""
    from helm.db import Database
    from helm.memory.service import MemoryService

    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    with db.session_scope() as s:
        svc = MemoryService(s)
        m = svc.create(text="recall me")
        mid = m.id
    with db.session_scope() as s:
        svc = MemoryService(s)
        svc.touch(mid)
        svc.touch(mid)
    with db.session_scope() as s:
        assert MemoryService(s).get(mid).uses == 2
        assert MemoryService(s).touch(999) is None


def test_cjk_keyword_search(config):
    """Chinese keyword search must match substrings (no whitespace boundaries)."""
    c = _client(config)
    c.post("/api/memories", json={"text": "用户偏好暗色主题", "category": "preference"})
    c.post("/api/memories", json={"text": "项目用 Stripe 结算", "category": "decision"})
    res = c.get("/api/memories/search", params={"q": "暗色"}).json()["results"]
    assert any("暗色主题" in r["text"] for r in res), "中文子串搜索应命中"
    # unrelated query doesn't match
    assert c.get("/api/memories/search", params={"q": "完全无关的词"}).json()["results"] == []


def test_tokenize_cjk_and_english():
    from helm.memory.service import tokenize, keyword_similarity
    # English unchanged
    assert tokenize("cat dog") == ["cat", "dog"]
    # CJK → unigrams + bigrams
    toks = set(tokenize("暗色"))
    assert "暗" in toks and "色" in toks and "暗色" in toks
    assert keyword_similarity("暗色", "用户偏好暗色主题") > 0
