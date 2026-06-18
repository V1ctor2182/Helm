"""Helm FastAPI application factory.

platform-shell: the bootable backend. m1 added the health endpoint and the
loopback-only binding; m2 wires the local SQLite storage (engine + session
factory) onto the app and bootstraps the schema. Feature rooms mount their
routers onto the app returned by :func:`create_app`; the brain
(chat/research/rag/memory) is pulled in from Odysseus per-room rather than
vendored wholesale (recorded decision).
"""

from __future__ import annotations

from collections.abc import Iterator

from fastapi import FastAPI, Request
from sqlalchemy.orm import Session

from helm import __version__
from helm.config import HelmConfig
from helm.crypto import SecretBox
from helm.db import Database
from helm.middleware import SecurityHeadersMiddleware


def create_app(config: HelmConfig | None = None) -> FastAPI:
    config = config or HelmConfig.from_env()
    app = FastAPI(title="Helm", version=__version__)
    app.state.config = config

    # Single-user, local-first: no auth layer. The trust boundary is the
    # loopback bind (helm.config). This middleware is browser/WebView
    # defense-in-depth (security headers + per-request CSP nonce).
    app.add_middleware(SecurityHeadersMiddleware)

    # Local storage: open the SQLite DB under the data dir and ensure the
    # schema exists before any request is served.
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    app.state.db = db

    # Encrypted-at-rest secrets (API keys). Lazy: the key file is only read on
    # first encrypt/decrypt, so constructing it here is free.
    app.state.secret_box = SecretBox.from_data_dir(config.data_dir)

    @app.get("/healthz")
    def healthz() -> dict:
        """Liveness probe — used by the desktop shell (m5) to know when the
        backend is ready before loading the UI, and by the smoke tests."""
        return {"status": "ok", "version": __version__}

    # Routers are imported here (not at module top) to avoid a circular import:
    # routes depend on the dependencies defined below in this module.
    from helm.routes.settings import router as settings_router

    app.include_router(settings_router)

    return app


def get_db(request: Request) -> Database:
    """FastAPI dependency: the app-wide :class:`Database`."""
    return request.app.state.db


def get_secret_box(request: Request) -> SecretBox:
    """FastAPI dependency: the app-wide :class:`SecretBox`."""
    return request.app.state.secret_box


def db_session(request: Request) -> Iterator[Session]:
    """FastAPI dependency yielding a transactional session per request.

    Routes added by later rooms depend on this instead of touching the engine
    directly.
    """
    with get_db(request).session_scope() as session:
        yield session
