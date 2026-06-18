"""m7: first-run status flag."""

from fastapi.testclient import TestClient

from helm.app import create_app


def test_fresh_install_is_first_run(config):
    c = TestClient(create_app(config))
    body = c.get("/api/setup/status").json()
    assert body["first_run"] is True
    assert "version" in body


def test_completing_setup_clears_first_run(config):
    c = TestClient(create_app(config))
    assert c.post("/api/setup/complete").json()["first_run"] is False
    assert c.get("/api/setup/status").json()["first_run"] is False
