"""Skills REST. m7: panorama (list + health) + enable/disable + usage count."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.skills import models  # noqa: F401  (register models on Base.metadata)
from helm.skills.service import SkillsService

router = APIRouter(prefix="/api/skills", tags=["skills"])


class EnabledBody(BaseModel):
    enabled: bool


@router.get("")
def list_skills(session: Session = Depends(db_session)) -> dict:
    skills = SkillsService(session).discover()
    healthy = sum(1 for s in skills if s["healthy"])
    return {
        "skills": skills,
        "total": len(skills),
        "healthy": healthy,
        "unhealthy": len(skills) - healthy,
    }


@router.post("/{name}/enabled")
def set_enabled(
    name: str,
    body: EnabledBody,
    session: Session = Depends(db_session),
) -> dict:
    return SkillsService(session).set_enabled(name, body.enabled)


@router.post("/{name}/used")
def record_use(name: str, session: Session = Depends(db_session)) -> dict:
    return SkillsService(session).record_use(name)
