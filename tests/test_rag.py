"""m4 (rag): document extraction + chunking + indexing + retrieval."""

from pathlib import Path

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.rag.extract import chunk_text, extract_text, is_supported, iter_files
from helm.rag.service import RagService
from helm.rag.vector import RagVectorStore
from tests.test_memory_vector import FakeEmbedder  # reuse deterministic embedder


# ---- extraction + chunking (pure, no deps) --------------------------------

def test_extract_text_and_support(tmp_path):
    md = tmp_path / "a.md"
    md.write_text("# Title\nbody text", encoding="utf-8")
    assert is_supported(md)
    assert extract_text(md) == "# Title\nbody text"
    assert not is_supported(tmp_path / "img.png")
    assert extract_text(tmp_path / "img.png") is None


def test_iter_files_skips_noise_dirs(tmp_path):
    (tmp_path / "keep.py").write_text("x = 1", encoding="utf-8")
    (tmp_path / "node_modules").mkdir()
    (tmp_path / "node_modules" / "skip.js").write_text("y", encoding="utf-8")
    (tmp_path / "notes.md").write_text("hi", encoding="utf-8")
    found = {p.name for p in iter_files(tmp_path)}
    assert found == {"keep.py", "notes.md"}


def test_chunk_text_windows_and_overlap():
    assert chunk_text("") == []
    text = "\n".join(f"line {i}" for i in range(400))
    chunks = chunk_text(text, size=200, overlap=40)
    assert len(chunks) > 1
    assert all(len(c) <= 220 for c in chunks)  # ~size, newline-trimmed
    # a single short text is one chunk
    assert chunk_text("just a little text", size=200) == ["just a little text"]


# ---- service: indexing + retrieval (FakeEmbedder + real Chroma) -----------

def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_add_source_indexes_dir(config, tmp_path):
    (tmp_path / "cars.md").write_text("I love my car and driving the vehicle", encoding="utf-8")
    (tmp_path / "pets.md").write_text("the cat and the dog are friends", encoding="utf-8")
    db = _db(config)
    store = RagVectorStore(config.data_dir, FakeEmbedder())
    with db.session_scope() as s:
        src = RagService(s, store).add_source(str(tmp_path))
        assert src.status == "indexed"
        assert src.file_count == 2
        assert src.chunk_count >= 2

    with db.session_scope() as s:
        hits = RagService(s, store).search("automobile", limit=3)
    assert hits
    assert "car" in hits[0]["text"]  # vehicle-concept chunk ranks first
    assert hits[0]["path"].endswith("cars.md")
    assert hits[0]["score"] > 0


def test_remove_source_drops_chunks(config, tmp_path):
    (tmp_path / "a.md").write_text("the dog runs", encoding="utf-8")
    db = _db(config)
    store = RagVectorStore(config.data_dir, FakeEmbedder())
    with db.session_scope() as s:
        sid = RagService(s, store).add_source(str(tmp_path)).id
    assert store.count() >= 1
    with db.session_scope() as s:
        assert RagService(s, store).remove_source(sid) is True
    assert store.count() == 0
    with db.session_scope() as s:
        assert RagService(s, store).search("dog") == []


def test_reindex_rebuilds(config, tmp_path):
    f = tmp_path / "a.md"
    f.write_text("the cat sleeps", encoding="utf-8")
    db = _db(config)
    store = RagVectorStore(config.data_dir, FakeEmbedder())
    with db.session_scope() as s:
        sid = RagService(s, store).add_source(str(tmp_path)).id
    f.write_text("a loyal dog barks", encoding="utf-8")  # content changed
    with db.session_scope() as s:
        RagService(s, store).reindex(sid)
    with db.session_scope() as s:
        hits = RagService(s, store).search("canine", limit=3)
    assert hits and "dog" in hits[0]["text"]


# ---- REST API (vectors disabled by conftest → registry works, search empty)

def test_rag_routes_register_and_count_without_vectors(config, tmp_path):
    (tmp_path / "doc.md").write_text("hello world\n" * 50, encoding="utf-8")
    c = TestClient(create_app(config))
    assert c.get("/api/rag/sources").json()["sources"] == []

    created = c.post("/api/rag/sources", json={"path": str(tmp_path)})
    assert created.status_code == 200
    body = created.json()
    # response returns immediately as 'indexing'; the background task indexes
    # (TestClient runs background tasks, so by the next request it's done).
    assert body["status"] == "indexing"

    after = c.get("/api/rag/sources").json()["sources"][0]
    assert after["status"] == "indexed"
    assert after["file_count"] == 1
    assert after["chunk_count"] >= 1  # counted even with vectors disabled

    stats = c.get("/api/rag/stats").json()
    assert stats["sources"] == 1 and stats["vector_count"] == 0
    # vectors disabled → semantic search returns nothing, but doesn't error
    assert c.get("/api/rag/search", params={"q": "hello"}).json()["results"] == []

    sid = body["id"]
    assert c.delete(f"/api/rag/sources/{sid}").status_code == 200
    assert c.get("/api/rag/sources").json()["sources"] == []


def test_rag_add_missing_path_404(config):
    c = TestClient(create_app(config))
    r = c.post("/api/rag/sources", json={"path": "/no/such/dir-xyz"})
    assert r.status_code == 404
