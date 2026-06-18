"""m4: security-headers middleware + the single-user/loopback posture."""

import pytest
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.config import HelmConfig


@pytest.fixture
def client(config):
    return TestClient(create_app(config))


def test_security_headers_present_on_healthz(client):
    resp = client.get("/healthz")
    h = resp.headers
    assert h["X-Content-Type-Options"] == "nosniff"
    assert h["X-Frame-Options"] == "DENY"
    assert h["Referrer-Policy"] == "no-referrer"
    assert "geolocation=()" in h["Permissions-Policy"]
    assert "default-src 'self'" in h["Content-Security-Policy"]
    assert "frame-ancestors 'none'" in h["Content-Security-Policy"]


def test_security_headers_present_on_api(client):
    resp = client.get("/api/settings")
    assert resp.headers["X-Frame-Options"] == "DENY"
    assert "Content-Security-Policy" in resp.headers


def test_csp_nonce_is_per_request(client):
    csp1 = client.get("/healthz").headers["Content-Security-Policy"]
    csp2 = client.get("/healthz").headers["Content-Security-Policy"]
    assert "nonce-" in csp1
    assert csp1 != csp2  # a fresh nonce each request


def test_bind_is_loopback_only():
    # The trust boundary: config refuses any non-loopback bind host, so the
    # backend can never be served off-box.
    with pytest.raises(ValueError):
        HelmConfig(host="0.0.0.0")
    assert HelmConfig().host == "127.0.0.1"
