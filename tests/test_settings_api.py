"""m3: settings + secrets REST surface, and the no-plaintext-keys-in-DB
constraint."""

from fastapi.testclient import TestClient
from sqlalchemy import select

from helm.app import create_app
from helm.crypto import SecretBox
from helm.models import Secret


def client(config) -> TestClient:
    return TestClient(create_app(config))


def test_settings_crud(config):
    c = client(config)

    assert c.get("/api/settings").json() == {}

    assert c.put("/api/settings/theme", json={"value": "dark"}).status_code == 200
    assert c.get("/api/settings/theme").json() == {"key": "theme", "value": "dark"}
    assert c.get("/api/settings").json() == {"theme": "dark"}

    # update
    c.put("/api/settings/theme", json={"value": "light"})
    assert c.get("/api/settings/theme").json()["value"] == "light"

    assert c.delete("/api/settings/theme").status_code == 204
    assert c.get("/api/settings/theme").status_code == 404


def test_missing_setting_404(config):
    assert client(config).get("/api/settings/nope").status_code == 404


def test_secret_set_list_delete(config):
    c = client(config)

    assert c.get("/api/secrets").json() == {"keys": []}

    assert (
        c.put("/api/secrets/openai_api_key", json={"value": "sk-abc"}).status_code
        == 200
    )
    assert c.get("/api/secrets").json() == {"keys": ["openai_api_key"]}

    assert c.delete("/api/secrets/openai_api_key").status_code == 204
    assert c.get("/api/secrets").json() == {"keys": []}


def test_secret_value_never_returned_over_rest(config):
    c = client(config)
    c.put("/api/secrets/openai_api_key", json={"value": "sk-PLAINTEXT-SECRET"})

    # No REST path exposes the plaintext value.
    body = c.put("/api/secrets/openai_api_key", json={"value": "sk-PLAINTEXT-SECRET"})
    assert "sk-PLAINTEXT-SECRET" not in body.text
    assert c.get("/api/secrets").text.find("sk-PLAINTEXT-SECRET") == -1


def test_secret_stored_encrypted_in_db(config):
    app = create_app(config)
    c = TestClient(app)
    c.put("/api/secrets/openai_api_key", json={"value": "sk-PLAINTEXT-SECRET"})

    # Read the raw row: it must be ciphertext, not the plaintext key.
    with app.state.db.session_scope() as session:
        row = session.execute(select(Secret)).scalars().one()
    assert row.value.startswith("enc:")
    assert "sk-PLAINTEXT-SECRET" not in row.value
    # And it must decrypt back to the original.
    assert SecretBox.from_data_dir(config.data_dir).decrypt(row.value) == (
        "sk-PLAINTEXT-SECRET"
    )
