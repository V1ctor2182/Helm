"""REST client the MCP server uses to reach the running Helm backend.

Kept separate from the server so the network surface is unit-testable: inject a
``starlette.TestClient`` (itself an ``httpx.Client``) bound to the app and the
tools run fully in-process, no real socket. In production it opens a real
``httpx.Client`` against the loopback backend (host/port from HelmConfig).
"""

from __future__ import annotations

import os

import httpx

from helm.config import HelmConfig


def default_base_url() -> str:
    """Loopback base URL of the running backend. ``HELM_BASE_URL`` overrides;
    otherwise derived from HelmConfig (single source of truth for host/port)."""
    override = os.getenv("HELM_BASE_URL")
    if override:
        return override
    cfg = HelmConfig.from_env()
    return f"http://{cfg.host}:{cfg.port}"


class HelmClient:
    def __init__(
        self, client: httpx.Client | None = None, base_url: str | None = None
    ) -> None:
        self._owned = client is None
        self._client = client or httpx.Client(
            base_url=base_url or default_base_url(), timeout=15.0
        )

    def close(self) -> None:
        if self._owned:
            self._client.close()

    def _get(self, path: str, **params) -> dict:
        resp = self._client.get(
            path, params={k: v for k, v in params.items() if v is not None}
        )
        resp.raise_for_status()
        return resp.json()

    def memory_search(self, query: str, limit: int = 5) -> list[dict]:
        return self._get("/api/memories/search", q=query, limit=limit)["results"]

    def memory_list(self, category: str | None = None) -> list[dict]:
        return self._get("/api/memories", category=category)["memories"]

    def memory_add(self, text: str, category: str = "fact") -> dict:
        resp = self._client.post(
            "/api/memories", json={"text": text, "category": category}
        )
        resp.raise_for_status()
        return resp.json()

    def rag_search(self, query: str, limit: int = 5) -> list[dict]:
        return self._get("/api/rag/search", q=query, limit=limit)["results"]
