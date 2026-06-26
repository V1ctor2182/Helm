"""Memory REST. m1: CRUD + keyword recall over `/api/memories`. Hybrid vector
search (m2) extends `/search`; JSON import/export (m3) adds bulk endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.memory import models  # noqa: F401  (register models on Base.metadata)
from helm.memory.service import CATEGORIES, MemoryService, memory_public

router = APIRouter(prefix="/api", tags=["memory"])


class MemoryBody(BaseModel):
    text: str
    category: str = "fact"
    source: str = "manual"
    session_id: str | None = None
    tags: list[str] | None = None
    pinned: bool = False


class MemoryPatch(BaseModel):
    text: str | None = None
    category: str | None = None
    tags: list[str] | None = None
    pinned: bool | None = None


def _validate_category(category: str) -> None:
    # Soft validation: the column is free-form, but a typo'd category would
    # silently break the UI filter, so reject unknown ones at the edge.
    if category not in CATEGORIES:
        raise HTTPException(
            status_code=422,
            detail=f"category must be one of {CATEGORIES}",
        )


@router.get("/memories")
def list_memories(
    category: str | None = Query(default=None),
    pinned: bool | None = Query(default=None),
    session: Session = Depends(db_session),
) -> dict:
    memories = MemoryService(session).list(category=category, pinned=pinned)
    return {"memories": [memory_public(m) for m in memories]}


@router.post("/memories")
def create_memory(
    body: MemoryBody,
    session: Session = Depends(db_session),
) -> dict:
    if not body.text.strip():
        raise HTTPException(status_code=422, detail="text must not be empty")
    _validate_category(body.category)
    memory = MemoryService(session).create(
        text=body.text,
        category=body.category,
        source=body.source,
        session_id=body.session_id,
        tags=body.tags,
        pinned=body.pinned,
    )
    return memory_public(memory)


@router.get("/memories/search")
def search_memories(
    q: str = Query(..., min_length=1),
    limit: int = Query(default=10, ge=1, le=100),
    category: str | None = Query(default=None),
    session: Session = Depends(db_session),
) -> dict:
    results = MemoryService(session).search(q, limit=limit, category=category)
    return {
        "results": [
            {**memory_public(m), "score": round(score, 4)} for m, score in results
        ]
    }


@router.get("/memories/{memory_id}")
def get_memory(
    memory_id: int,
    session: Session = Depends(db_session),
) -> dict:
    memory = MemoryService(session).get(memory_id)
    if memory is None:
        raise HTTPException(status_code=404, detail="memory not found")
    return memory_public(memory)


@router.patch("/memories/{memory_id}")
def update_memory(
    memory_id: int,
    body: MemoryPatch,
    session: Session = Depends(db_session),
) -> dict:
    if body.category is not None:
        _validate_category(body.category)
    memory = MemoryService(session).update(
        memory_id,
        text=body.text,
        category=body.category,
        tags=body.tags,
        pinned=body.pinned,
    )
    if memory is None:
        raise HTTPException(status_code=404, detail="memory not found")
    return memory_public(memory)


@router.delete("/memories/{memory_id}")
def delete_memory(
    memory_id: int,
    session: Session = Depends(db_session),
) -> dict:
    if not MemoryService(session).delete(memory_id):
        raise HTTPException(status_code=404, detail="memory not found")
    return {"deleted": memory_id}
