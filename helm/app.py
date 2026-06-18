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
from helm.db import Database


def create_app(config: HelmConfig | None = None) -> FastAPI:
    config = config or HelmConfig.from_env()
    app = FastAPI(title="Helm", version=__version__)
    app.state.config = config

    # Local storage: open the SQLite DB under the data dir and ensure the
    # schema exists before any request is served.
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    app.state.db = db

    @app.get("/healthz")
    def healthz() -> dict:
        """Liveness probe — used by the desktop shell (m5) to know when the
        backend is ready before loading the UI, and by the smoke tests."""
        return {"status": "ok", "version": __version__}

    return app


def get_db(request: Request) -> Database:
    """FastAPI dependency: the app-wide :class:`Database`."""
    return request.app.state.db


def db_session(request: Request) -> Iterator[Session]:
    """FastAPI dependency yielding a transactional session per request.

    Routes added by later rooms depend on this instead of touching the engine
    directly.
    """
    with get_db(request).session_scope() as session:
        yield session
