"""m1 (journal-notes-tasks): unified notes CRUD (quick notes + journal entries)."""

from fastapi.testclient import TestClient

from helm.app import create_app


def _client(config) -> TestClient:
    return TestClient(create_app(config))


def test_note_crud(config):
    c = _client(config)
    assert c.get("/api/notes").json()["notes"] == []

    created = c.post("/api/notes", json={"content": "buy milk", "source": "capture", "tags": ["todo"]})
    assert created.status_code == 200
    n = created.json()
    assert n["kind"] == "note" and n["source"] == "capture" and n["tags"] == ["todo"]

    patched = c.patch(f"/api/notes/{n['id']}", json={"pinned": True, "content": "buy oat milk"})
    assert patched.json()["pinned"] is True and patched.json()["content"] == "buy oat milk"

    assert len(c.get("/api/notes").json()["notes"]) == 1
    assert c.delete(f"/api/notes/{n['id']}").status_code == 200
    assert c.get("/api/notes").json()["notes"] == []


def test_note_validation_and_404(config):
    c = _client(config)
    assert c.post("/api/notes", json={"content": "   "}).status_code == 422
    assert c.post("/api/notes", json={"content": "x", "kind": "bogus"}).status_code == 422
    assert c.patch("/api/notes/999", json={"content": "x"}).status_code == 404
    assert c.delete("/api/notes/999").status_code == 404


def test_journal_kind_and_date_filter(config):
    c = _client(config)
    c.post("/api/notes", json={"content": "a quick note"})
    c.post("/api/notes", json={"content": "dear diary", "kind": "journal", "journal_date": "2026-06-27"})
    c.post("/api/notes", json={"content": "older entry", "kind": "journal", "journal_date": "2026-06-26"})

    journals = c.get("/api/notes", params={"kind": "journal"}).json()["notes"]
    assert len(journals) == 2
    assert {j["kind"] for j in journals} == {"journal"}

    today = c.get("/api/notes", params={"kind": "journal", "journal_date": "2026-06-27"}).json()["notes"]
    assert len(today) == 1 and today[0]["content"] == "dear diary"

    notes = c.get("/api/notes", params={"kind": "note"}).json()["notes"]
    assert len(notes) == 1


def test_pinned_sorts_first(config):
    c = _client(config)
    c.post("/api/notes", json={"content": "first"})
    second = c.post("/api/notes", json={"content": "second"}).json()
    c.patch(f"/api/notes/{second['id']}", json={"pinned": True})
    notes = c.get("/api/notes").json()["notes"]
    assert notes[0]["content"] == "second" and notes[0]["pinned"] is True
