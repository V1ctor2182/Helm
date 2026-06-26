"""Note store: CRUD over the unified notes table, filterable by kind / journal
date. Quick captures persist here (source='capture'); journal entries are the
same rows with kind='journal'."""

from __future__ import annotations

import json
from datetime import date as date_cls
from datetime import datetime as _dt

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.notes.models import Note

KINDS = ("note", "journal")


def note_public(n: Note) -> dict:
    return {
        "id": n.id,
        "kind": n.kind,
        "title": n.title,
        "content": n.content,
        "tags": json.loads(n.tags_json or "[]"),
        "pinned": n.pinned,
        "source": n.source,
        "journal_date": n.journal_date.isoformat() if n.journal_date else None,
        "created_at": n.created_at.isoformat() if n.created_at else None,
        "updated_at": n.updated_at.isoformat() if n.updated_at else None,
    }


class NoteService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list(
        self, kind: str | None = None, journal_date: date_cls | None = None
    ) -> list[Note]:
        stmt = select(Note).order_by(Note.pinned.desc(), Note.created_at.desc())
        if kind is not None:
            stmt = stmt.where(Note.kind == kind)
        if journal_date is not None:
            stmt = stmt.where(Note.journal_date == journal_date)
        return list(self.session.scalars(stmt))

    def get(self, note_id: int) -> Note | None:
        return self.session.get(Note, note_id)

    def create(
        self,
        content: str,
        *,
        kind: str = "note",
        title: str | None = None,
        tags: list[str] | None = None,
        pinned: bool = False,
        source: str = "user",
        journal_date: date_cls | None = None,
    ) -> Note:
        note = Note(
            kind=kind,
            title=title,
            content=content,
            tags_json=json.dumps(tags or [], ensure_ascii=False),
            pinned=pinned,
            source=source,
            journal_date=journal_date,
        )
        self.session.add(note)
        self.session.flush()
        return note

    def update(
        self,
        note_id: int,
        *,
        content: str | None = None,
        title: str | None = None,
        kind: str | None = None,
        tags: list[str] | None = None,
        pinned: bool | None = None,
        journal_date: date_cls | None = None,
    ) -> Note | None:
        note = self.get(note_id)
        if note is None:
            return None
        if content is not None:
            note.content = content
        if title is not None:
            note.title = title
        if kind is not None:
            note.kind = kind
        if tags is not None:
            note.tags_json = json.dumps(tags, ensure_ascii=False)
        if pinned is not None:
            note.pinned = pinned
        if journal_date is not None:
            note.journal_date = journal_date
        self.session.flush()
        return note

    def delete(self, note_id: int) -> bool:
        note = self.get(note_id)
        if note is None:
            return False
        self.session.delete(note)
        return True

    # ── convert (intent#1: 速记一键转 记忆/日记) ──────────────────────────

    def to_journal(
        self, note_id: int, journal_date: date_cls | None = None
    ) -> Note | None:
        """Turn a quick note into a journal entry in place (kind='journal' +
        date). Reversible — flip kind back. Defaults to the note's own day."""
        note = self.get(note_id)
        if note is None:
            return None
        note.kind = "journal"
        note.journal_date = (
            journal_date
            or (note.created_at.date() if note.created_at else None)
            or _dt.now().date()
        )
        self.session.flush()
        return note

    def to_memory(self, note_id: int, memory_service) -> dict | None:
        """Save a note's content as a memory (so it joins the brain / agent
        recall). Keeps the note — non-destructive; deleting it is a separate
        explicit action."""
        note = self.get(note_id)
        if note is None:
            return None
        text = (note.title + ": " if note.title else "") + note.content
        mem = memory_service.create(text=text.strip(), source="note", tags=["note"])
        return {"memory_id": mem.id, "text": mem.text}
