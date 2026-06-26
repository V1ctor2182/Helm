"""Helm FastAPI application factory.

platform-shell: the bootable backend. m1 added the health endpoint and the
loopback-only binding; m2 wires the local SQLite storage (engine + session
factory) onto the app and bootstraps the schema. Feature rooms mount their
routers onto the app returned by :func:`create_app`; the brain
(chat/research/rag/memory) is pulled in from Odysseus per-room rather than
vendored wholesale (recorded decision).
"""

from __future__ import annotations

import os
from collections.abc import Iterator
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
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

    # Local storage: open the SQLite DB under the data dir. Tables are created
    # after routers import their models (see create_all below).
    db = Database.from_data_dir(config.data_dir)
    app.state.db = db

    # Encrypted-at-rest secrets (API keys). Lazy: the key file is only read on
    # first encrypt/decrypt, so constructing it here is free.
    app.state.secret_box = SecretBox.from_data_dir(config.data_dir)

    # Vector indexes (memory-rag-skills m2/m4): memory recall + RAG retrieval.
    # One fastembed embedder serves both (mirrors Odysseus sharing its
    # EmbeddingClient). Construction is cheap — the Chroma clients open local
    # dirs and the model loads lazily on first embed. Set HELM_MEMORY_VECTORS=0
    # to disable (the tests do this so the gate never downloads a model); each
    # store also self-degrades if Chroma/fastembed can't initialize.
    app.state.memory_vectors = None
    app.state.rag_vectors = None
    if os.getenv("HELM_MEMORY_VECTORS", "1") != "0":
        from helm.memory.embedding import FastEmbedEmbedder
        from helm.memory.vector import MemoryVectorStore
        from helm.rag.vector import RagVectorStore

        embedder = FastEmbedEmbedder()
        app.state.memory_vectors = MemoryVectorStore(config.data_dir, embedder)
        app.state.rag_vectors = RagVectorStore(config.data_dir, embedder)

    @app.get("/healthz")
    def healthz() -> dict:
        """Liveness probe — used by the desktop shell (m5) to know when the
        backend is ready before loading the UI, and by the smoke tests."""
        return {"status": "ok", "version": __version__}

    # Routers are imported here (not at module top) to avoid a circular import:
    # routes depend on the dependencies defined below in this module. Importing
    # them also registers each room's ORM models on Base.metadata.
    from helm.chat.routes import router as chat_router
    from helm.cockpit.routes import router as cockpit_router
    from helm.memory.routes import router as memory_router
    from helm.rag.routes import router as rag_router
    from helm.routes.settings import router as settings_router
    from helm.routes.setup import router as setup_router
    from helm.skills.routes import router as skills_router

    app.include_router(settings_router)
    app.include_router(setup_router)
    app.include_router(cockpit_router)
    app.include_router(chat_router)
    app.include_router(memory_router)
    app.include_router(rag_router)
    app.include_router(skills_router)

    # Create tables now that every router module has imported its models.
    db.create_all()

    # Serve the built Svelte frontend (workspace-layout) when present; until it's
    # built, fall back to the minimal boot page. Mounted LAST so /healthz and
    # /api/* (registered above) win over this catch-all static mount.
    dist = _frontend_dist()
    if dist is not None:
        app.mount("/", StaticFiles(directory=dist, html=True), name="frontend")
    else:

        @app.get("/", response_class=HTMLResponse)
        def index() -> str:
            return _BOOT_PAGE

    return app


def _frontend_dist() -> Path | None:
    """Locate the built Svelte app. Defaults to ``<repo>/frontend/dist``;
    override with ``HELM_FRONTEND_DIST`` (used by packaging). Returns None until
    it's built, so dev/CI fall back to the boot page."""
    override = os.getenv("HELM_FRONTEND_DIST")
    base = (
        Path(override)
        if override
        else Path(__file__).resolve().parent.parent / "frontend" / "dist"
    )
    return base if (base / "index.html").exists() else None


_BOOT_PAGE = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Helm</title>
  <style>
    html,body{{height:100%;margin:0}}
    body{{display:flex;align-items:center;justify-content:center;
      font:16px -apple-system,system-ui,sans-serif;color:#222;background:#fafafa}}
    .box{{text-align:center}}
    h1{{font-weight:600;letter-spacing:.02em;margin:0 0 .25em}}
    .v{{color:#888;font-size:.85em}}
  </style>
</head>
<body>
  <div class="box">
    <h1>Helm</h1>
    <div class="v">backend running · v{__version__}</div>
  </div>
</body>
</html>"""


def get_db(request: Request) -> Database:
    """FastAPI dependency: the app-wide :class:`Database`."""
    return request.app.state.db


def get_secret_box(request: Request) -> SecretBox:
    """FastAPI dependency: the app-wide :class:`SecretBox`."""
    return request.app.state.secret_box


def get_memory_vectors(request: Request):
    """FastAPI dependency: the app-wide memory vector index, or None when
    vector recall is disabled (keyword-only)."""
    return request.app.state.memory_vectors


def get_rag_vectors(request: Request):
    """FastAPI dependency: the app-wide RAG vector index, or None when vectors
    are disabled."""
    return request.app.state.rag_vectors


def db_session(request: Request) -> Iterator[Session]:
    """FastAPI dependency yielding a transactional session per request.

    Routes added by later rooms depend on this instead of touching the engine
    directly.
    """
    with get_db(request).session_scope() as session:
        yield session
