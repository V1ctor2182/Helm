"""m1 (workspace-layout): backend serves the built Svelte app at /, falling
back to the boot page until it's built — and the static mount must not shadow
/healthz or /api."""

from fastapi.testclient import TestClient

from helm.app import create_app


def test_boot_page_when_frontend_not_built(config, tmp_path, monkeypatch):
    monkeypatch.setenv("HELM_FRONTEND_DIST", str(tmp_path / "empty"))  # no index.html
    c = TestClient(create_app(config))
    resp = c.get("/")
    assert resp.status_code == 200
    assert "text/html" in resp.headers["content-type"]
    assert "backend running" in resp.text  # the boot page


def test_serves_built_frontend_when_present(config, tmp_path, monkeypatch):
    dist = tmp_path / "dist"
    dist.mkdir()
    (dist / "index.html").write_text("<!doctype html><title>Helm</title>BUILT-UI")
    monkeypatch.setenv("HELM_FRONTEND_DIST", str(dist))

    c = TestClient(create_app(config))
    resp = c.get("/")
    assert resp.status_code == 200
    assert "BUILT-UI" in resp.text


def test_static_mount_does_not_shadow_api(config, tmp_path, monkeypatch):
    dist = tmp_path / "dist"
    dist.mkdir()
    (dist / "index.html").write_text("UI")
    monkeypatch.setenv("HELM_FRONTEND_DIST", str(dist))

    c = TestClient(create_app(config))
    # /healthz and /api/* still resolve to their routes, not the static catch-all.
    assert c.get("/healthz").json()["status"] == "ok"
    assert c.get("/api/settings").status_code == 200
