"""Calendar event service: CRUD + date-range list + .ics import/export. CalDAV
account creds are SecretBox-encrypted (constraint 9ada9908)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.calendar.ics import events_to_ics, parse_ics
from helm.calendar.models import CalDavAccount, CalendarEvent
from helm.crypto import SecretBox


def event_public(e: CalendarEvent) -> dict:
    return {
        "id": e.id,
        "uid": e.uid,
        "summary": e.summary,
        "description": e.description,
        "location": e.location,
        "start": e.start.isoformat() if e.start else None,
        "end": e.end.isoformat() if e.end else None,
        "all_day": e.all_day,
        "source": e.source,
    }


class EventService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list(
        self, start: datetime | None = None, end: datetime | None = None
    ) -> list[CalendarEvent]:
        stmt = select(CalendarEvent).order_by(CalendarEvent.start)
        if start is not None:
            stmt = stmt.where(CalendarEvent.start >= start)
        if end is not None:
            stmt = stmt.where(CalendarEvent.start <= end)
        return list(self.session.scalars(stmt))

    def get(self, event_id: int) -> CalendarEvent | None:
        return self.session.get(CalendarEvent, event_id)

    def create(
        self,
        *,
        summary: str,
        start: datetime,
        end: datetime | None = None,
        description: str = "",
        location: str = "",
        all_day: bool = False,
        uid: str | None = None,
        source: str = "local",
    ) -> CalendarEvent:
        event = CalendarEvent(
            uid=uid or f"helm-{uuid.uuid4().hex[:12]}",
            summary=summary,
            description=description,
            location=location,
            start=start,
            end=end,
            all_day=all_day,
            source=source,
        )
        self.session.add(event)
        self.session.flush()
        return event

    def delete(self, event_id: int) -> bool:
        event = self.get(event_id)
        if event is None:
            return False
        self.session.delete(event)
        return True

    def import_ics(self, text: str) -> int:
        """Import VEVENTs; upsert by uid. Returns count of new events."""
        existing = {e.uid for e in self.session.scalars(select(CalendarEvent))}
        new = 0
        for ev in parse_ics(text):
            uid = ev.get("uid") or f"helm-{uuid.uuid4().hex[:12]}"
            if uid in existing:
                continue
            self.create(
                summary=ev.get("summary", ""),
                start=ev["start"],
                end=ev.get("end"),
                description=ev.get("description", ""),
                location=ev.get("location", ""),
                all_day=bool(ev.get("all_day", False)),
                uid=uid,
                source="ics",
            )
            existing.add(uid)
            new += 1
        return new

    def export_ics(self) -> str:
        return events_to_ics(self.list())

    def sync_caldav(self, client) -> dict:
        """Bidirectional sync against a CalDAV server (intent#2). Pull remote
        events (upsert by uid, source='caldav') + push local-only events. First
        pass: remote events not seen locally are added; existing uids are left
        (no overwrite of local edits); local 'local'-source events absent
        remotely are PUT. Returns counts."""
        remote_uids: set[str] = set()
        pulled = 0
        for ics_text in client.list_events():
            for ev in parse_ics(ics_text):
                uid = ev.get("uid")
                if not uid:
                    continue
                remote_uids.add(uid)
                existing = self.session.scalar(
                    select(CalendarEvent).where(CalendarEvent.uid == uid)
                )
                if existing is None:
                    self.create(
                        summary=ev.get("summary", ""),
                        start=ev["start"],
                        end=ev.get("end"),
                        description=ev.get("description", ""),
                        location=ev.get("location", ""),
                        all_day=bool(ev.get("all_day", False)),
                        uid=uid,
                        source="caldav",
                    )
                    pulled += 1

        pushed = 0
        for ev in list(
            self.session.scalars(
                select(CalendarEvent).where(CalendarEvent.source == "local")
            )
        ):
            if ev.uid not in remote_uids:
                client.create_event(events_to_ics([ev]))
                ev.source = "caldav"
                pushed += 1
        self.session.flush()
        return {"pulled_new": pulled, "pushed": pushed}


class CalDavAccountService:
    def __init__(self, session: Session, box: SecretBox) -> None:
        self.session = session
        self.box = box

    def list(self) -> list[CalDavAccount]:
        return list(self.session.scalars(select(CalDavAccount)))

    def create(self, *, name: str, url: str, username: str, password: str) -> CalDavAccount:
        account = CalDavAccount(
            name=name, url=url, username=username, password_enc=self.box.encrypt(password)
        )
        self.session.add(account)
        self.session.flush()
        return account

    def password(self, account_id: int) -> str | None:
        account = self.session.get(CalDavAccount, account_id)
        return self.box.decrypt(account.password_enc) if account else None
