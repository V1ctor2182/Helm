"""m1 smoke test: the backend imports, boots, and serves /healthz."""

from fastapi.testclient import TestClient

from helm import __version__
from helm.app import create_app
from helm.config import HelmConfig


def test_healthz_ok():
    app = create_app(HelmConfig())
    client = TestClient(app)
    resp = client.get("/healthz")

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["version"] == __version__


def test_config_attached_to_app_state():
    config = HelmConfig()
    app = create_app(config)
    assert app.state.config is config
