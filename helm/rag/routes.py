"""RAG REST. m4: source registration + indexing + retrieval over /api/rag."""

from __future__ import annotations

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    HTTPException,
    Query,
    Request,
)
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session, get_rag_vectors
from helm.rag import models  # noqa: F401  (register models on Base.metadata)
from helm.rag.service import RagService, source_public

router = APIRouter(prefix="/api/rag", tags=["rag"])


class SourceBody(BaseModel):
    path: str


def _index_in_background(db, vectors, source_id: int) -> None:
    """Index a registered source in its own session (runs after the response is
    sent, so a large directory never blocks the request — ticket 7842c722)."""
    with db.session_scope() as session:
        RagService(session, vectors).index_source(source_id)


@router.get("/sources")
def list_sources(session: Session = Depends(db_session)) -> dict:
    return {"sources": [source_public(s) for s in RagService(session).list_sources()]}


@router.post("/sources")
def add_source(
    body: SourceBody,
    request: Request,
    background: BackgroundTasks,
    vectors=Depends(get_rag_vectors),
) -> dict:
    # Register in its OWN committed session so the row is durable before the
    # background task (a separate session) reads it — don't rely on the request
    # dependency's commit ordering relative to background tasks.
    db = request.app.state.db
    try:
        with db.session_scope() as session:
            src = RagService(session, vectors).register_source(body.path)
            payload = source_public(src)
            source_id = src.id
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"path not found: {body.path}")
    # Index after the response is sent (status 'indexing' → 'indexed').
    background.add_task(_index_in_background, db, vectors, source_id)
    return payload


@router.post("/sources/{source_id}/reindex")
def reindex_source(
    source_id: int,
    session: Session = Depends(db_session),
    vectors=Depends(get_rag_vectors),
) -> dict:
    src = RagService(session, vectors).reindex(source_id)
    if src is None:
        raise HTTPException(status_code=404, detail="source not found")
    return source_public(src)


@router.delete("/sources/{source_id}")
def delete_source(
    source_id: int,
    session: Session = Depends(db_session),
    vectors=Depends(get_rag_vectors),
) -> dict:
    if not RagService(session, vectors).remove_source(source_id):
        raise HTTPException(status_code=404, detail="source not found")
    return {"deleted": source_id}


@router.get("/search")
def search(
    q: str = Query(..., min_length=1),
    limit: int = Query(default=5, ge=1, le=50),
    session: Session = Depends(db_session),
    vectors=Depends(get_rag_vectors),
) -> dict:
    return {"results": RagService(session, vectors).search(q, limit=limit)}


@router.get("/stats")
def stats(
    session: Session = Depends(db_session),
    vectors=Depends(get_rag_vectors),
) -> dict:
    return RagService(session, vectors).stats()
