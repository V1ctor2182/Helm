"""m1 (chat): provider management — templates, CRUD, encrypted keys never
exposed plaintext."""

from fastapi.testclient import TestClient
from sqlalchemy import select

from helm.app import create_app
from helm.chat.models import Provider


def test_provider_templates(config):
    c = TestClient(create_app(config))
    templates = c.get("/api/providers/templates").json()["templates"]
    types = {t["type"] for t in templates}
    assert {"anthropic", "ollama", "openai", "openrouter", "openai-compat"} <= types
    claude = next(t for t in templates if t["type"] == "anthropic")
    assert claude.get("default") is True


def test_provider_crud_hides_key(config):
    c = TestClient(create_app(config))
    assert c.get("/api/providers").json()["providers"] == []

    created = c.post(
        "/api/providers",
        json={
            "type": "anthropic",
            "name": "Claude",
            "base_url": "https://api.anthropic.com",
            "api_key": "sk-ant-SECRET",
            "models": ["claude-opus-4-8"],
        },
    )
    assert created.status_code == 200
    body = created.text
    assert "sk-ant-SECRET" not in body  # key never returned
    pj = created.json()
    assert pj["has_key"] is True
    assert pj["models"] == ["claude-opus-4-8"]

    listed = c.get("/api/providers").json()["providers"]
    assert len(listed) == 1
    assert "sk-ant-SECRET" not in c.get("/api/providers").text


def test_provider_key_encrypted_in_db(config):
    app = create_app(config)
    c = TestClient(app)
    c.post(
        "/api/providers",
        json={"type": "openai", "name": "O", "api_key": "sk-PLAIN", "base_url": "u"},
    )
    with app.state.db.session_scope() as s:
        row = s.execute(select(Provider)).scalars().one()
    assert row.api_key_enc is not None
    assert row.api_key_enc.startswith("enc:")
    assert "sk-PLAIN" not in row.api_key_enc


def test_keyless_provider_and_delete(config):
    c = TestClient(create_app(config))
    pj = c.post(
        "/api/providers", json={"type": "ollama", "name": "Ollama", "base_url": "u"}
    ).json()
    assert pj["has_key"] is False
    assert c.delete(f"/api/providers/{pj['id']}").status_code == 204
    assert c.delete(f"/api/providers/{pj['id']}").status_code == 404
