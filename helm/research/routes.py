"""Deep Research REST. m1: read past research (list + report with sources).
The start route (real providers, async run) lands in m2/m3."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.research import models  # noqa: F401  (register tables on Base)
from helm.research.service import ResearchService, session_public

router = APIRouter(prefix="/api/research", tags=["research"])


@router.get("")
def list_research(session: Session = Depends(db_session)) -> dict:
    return {"sessions": [session_public(s) for s in ResearchService(session).list()]}


@router.get("/{session_id}")
def get_research(session_id: int, session: Session = Depends(db_session)) -> dict:
    svc = ResearchService(session)
    s = svc.get(session_id)
    if s is None:
        raise HTTPException(status_code=404, detail="research session not found")
    return session_public(s, svc.sources(session_id))
