"""Calendar REST. m4: events CRUD + date-range list + .ics import/export +
encrypted CalDAV accounts. Real CalDAV sync is a [needs-human] integration."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session, get_secret_box
from helm.calendar import models  # noqa: F401  (register tables on Base)
from helm.calendar.service import (
    CalDavAccountService,
    EventService,
    event_public,
)
from helm.crypto import SecretBox

router = APIRouter(prefix="/api/calendar", tags=["calendar"])


class EventBody(BaseModel):
    summary: str
    start: datetime
    end: datetime | None = None
    description: str = ""
    location: str = ""
    all_day: bool = False


class ImportBody(BaseModel):
    ics: str


class CalDavBody(BaseModel):
    name: str
    url: str
    username: str
    password: str


@router.get("/events")
def list_events(
    start: datetime | None = Query(default=None),
    end: datetime | None = Query(default=None),
    session: Session = Depends(db_session),
) -> dict:
    events = EventService(session).list(start=start, end=end)
    return {"events": [event_public(e) for e in events]}


@router.post("/events")
def create_event(body: EventBody, session: Session = Depends(db_session)) -> dict:
    if not body.summary.strip():
        raise HTTPException(status_code=422, detail="summary required")
    event = EventService(session).create(
        summary=body.summary, start=body.start, end=body.end,
        description=body.description, location=body.location, all_day=body.all_day,
    )
    return event_public(event)


@router.delete("/events/{event_id}")
def delete_event(event_id: int, session: Session = Depends(db_session)) -> dict:
    if not EventService(session).delete(event_id):
        raise HTTPException(status_code=404, detail="event not found")
    return {"deleted": event_id}


@router.post("/import")
def import_ics(body: ImportBody, session: Session = Depends(db_session)) -> dict:
    return {"imported": EventService(session).import_ics(body.ics)}


@router.get("/export", response_class=PlainTextResponse)
def export_ics(session: Session = Depends(db_session)) -> str:
    return EventService(session).export_ics()


@router.get("/accounts")
def list_caldav(
    session: Session = Depends(db_session), box: SecretBox = Depends(get_secret_box)
) -> dict:
    return {
        "accounts": [
            {"id": a.id, "name": a.name, "url": a.url, "username": a.username}
            for a in CalDavAccountService(session, box).list()
        ]
    }


@router.post("/accounts")
def create_caldav(
    body: CalDavBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    a = CalDavAccountService(session, box).create(
        name=body.name, url=body.url, username=body.username, password=body.password
    )
    return {"id": a.id, "name": a.name, "url": a.url, "username": a.username}
