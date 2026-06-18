"""Helm FastAPI application factory.

m1 (platform-shell): the minimal bootable backend — a health endpoint and the
loopback-only binding. Feature rooms mount their routers onto the app returned
by :func:`create_app`; the brain (chat/research/rag/memory) is pulled in from
Odysseus per-room rather than vendored wholesale (recorded decision).
"""

from __future__ import annotations

from fastapi import FastAPI

from helm import __version__
from helm.config import HelmConfig


def create_app(config: HelmConfig | None = None) -> FastAPI:
    config = config or HelmConfig.from_env()
    app = FastAPI(title="Helm", version=__version__)
    app.state.config = config

    @app.get("/healthz")
    def healthz() -> dict:
        """Liveness probe — used by the desktop shell (m5) to know when the
        backend is ready before loading the UI, and by the smoke tests."""
        return {"status": "ok", "version": __version__}

    return app
