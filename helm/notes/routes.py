"""Notes REST. m1: CRUD over /api/notes (quick captures + journal entries).
Convert-to memory/task/journal lands in m2."""

from __future__ import annotations

from datetime import date

import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.app import db_session, get_memory_vectors, get_secret_box
from helm.chat.models import Provider
from helm.chat.service import ProviderService
from helm.crypto import SecretBox
from helm.notes import models  # noqa: F401  (register notes table on Base)
from helm.notes.enrich import enrich_note
from helm.notes.models import Note
from helm.notes.service import KINDS, NoteService, note_public
from helm.notes.summary import summarize_journal
from helm.research.llm import ChatLLM  # patched in tests

router = APIRouter(prefix="/api/notes", tags=["notes"])


class NoteBody(BaseModel):
    content: str
    kind: str = "note"
    title: str | None = None
    tags: list[str] | None = None
    pinned: bool = False
    source: str = "user"
    journal_date: date | None = None


class NotePatch(BaseModel):
    content: str | None = None
    title: str | None = None
    kind: str | None = None
    tags: list[str] | None = None
    pinned: bool | None = None
    journal_date: date | None = None


def _check_kind(kind: str | None) -> None:
    if kind is not None and kind not in KINDS:
        raise HTTPException(status_code=422, detail=f"kind must be one of {KINDS}")


@router.get("")
def list_notes(
    kind: str | None = Query(default=None),
    journal_date: date | None = Query(default=None),
    session: Session = Depends(db_session),
) -> dict:
    notes = NoteService(session).list(kind=kind, journal_date=journal_date)
    return {"notes": [note_public(n) for n in notes]}


@router.post("")
async def create_note(
    body: NoteBody,
    request: Request,
    session: Session = Depends(db_session),
) -> dict:
    if not body.content.strip() and not (body.title or "").strip():
        raise HTTPException(status_code=422, detail="content or title required")
    _check_kind(body.kind)
    note = NoteService(session).create(
        content=body.content,
        kind=body.kind,
        title=body.title,
        tags=body.tags,
        pinned=body.pinned,
        source=body.source,
        journal_date=body.journal_date,
    )
    # 速记 AI 管线(2026-07-06):除日记外,发送后后台 enrich(链接 parse/AI 整理)。
    # 不用 BackgroundTasks——BaseHTTPMiddleware 会在响应结束时取消未完的
    # background(著名坑,实测 enrich 被静默杀掉);asyncio.create_task 与响应
    # 生命周期解耦。先显式 commit 让任务的独立 session 读得到这条 note;
    # 任务引用挂 app.state 防 GC。
    if body.kind != "journal":
        session.commit()
        task = asyncio.create_task(enrich_note(
            request.app.state.db, request.app.state.secret_box,
            note.id, request.app.state.config.data_dir))
        pending = getattr(request.app.state, "enrich_tasks", None)
        if pending is None:
            pending = request.app.state.enrich_tasks = set()
        pending.add(task)

        def _on_done(t: asyncio.Task) -> None:
            pending.discard(t)
            if not t.cancelled() and t.exception() is not None:
                logging.getLogger("uvicorn.error").warning(
                    "notes enrich task failed: %r", t.exception())

        task.add_done_callback(_on_done)
    return note_public(note)


@router.patch("/{note_id}")
def update_note(
    note_id: int, body: NotePatch, session: Session = Depends(db_session)
) -> dict:
    _check_kind(body.kind)
    note = NoteService(session).update(
        note_id,
        content=body.content,
        title=body.title,
        kind=body.kind,
        tags=body.tags,
        pinned=body.pinned,
        journal_date=body.journal_date,
    )
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    return note_public(note)


@router.delete("/{note_id}")
def delete_note(note_id: int, session: Session = Depends(db_session)) -> dict:
    if not NoteService(session).delete(note_id):
        raise HTTPException(status_code=404, detail="note not found")
    return {"deleted": note_id}


class ToJournalBody(BaseModel):
    journal_date: date | None = None


@router.post("/{note_id}/to-journal")
def note_to_journal(
    note_id: int,
    body: ToJournalBody | None = None,
    session: Session = Depends(db_session),
) -> dict:
    note = NoteService(session).to_journal(
        note_id, body.journal_date if body else None
    )
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    return note_public(note)


@router.post("/{note_id}/to-memory")
def note_to_memory(
    note_id: int,
    session: Session = Depends(db_session),
    vectors=Depends(get_memory_vectors),
) -> dict:
    from helm.memory.service import MemoryService

    out = NoteService(session).to_memory(note_id, MemoryService(session, vectors))
    if out is None:
        raise HTTPException(status_code=404, detail="note not found")
    return out


class JournalSummaryBody(BaseModel):
    provider_id: int
    model: str
    journal_date: date | None = None
    # 回顾窗口:1=当日小结;7=周回顾(自 journal_date 往前含当日)。
    days: int = 1
    save: bool = False


@router.post("/journal/summary")
def journal_summary(
    body: JournalSummaryBody,
    session: Session = Depends(db_session),
    box: SecretBox = Depends(get_secret_box),
) -> dict:
    """AI 「今日小结」: summarize a day's journal entries (intent#2). The LLM
    call is paid but user-initiated. Optionally save the summary as a note."""
    day = body.journal_date
    if day is not None:
        if body.days > 1:
            from datetime import timedelta

            start = day - timedelta(days=body.days - 1)
            stmt = select(Note).where(
                Note.kind == "journal",
                Note.journal_date >= start,
                Note.journal_date <= day,
            )
        else:
            stmt = select(Note).where(Note.kind == "journal", Note.journal_date == day)
        entries = [n.content for n in session.scalars(stmt)]
    else:
        entries = [n.content for n in NoteService(session).list(kind="journal")]
    if not entries:
        raise HTTPException(status_code=404, detail="no journal entries to summarize")

    provider = session.scalar(select(Provider).where(Provider.id == body.provider_id))
    if provider is None:
        raise HTTPException(status_code=404, detail="provider not found")
    key = ProviderService(session, box).api_key(body.provider_id)
    llm = ChatLLM(provider.type, provider.base_url, body.model, key)
    summary = summarize_journal(entries, llm)

    saved_id = None
    if body.save and summary:
        saved_id = NoteService(session).create(
            content=summary, kind="journal", journal_date=day, source="agent"
        ).id
    return {"summary": summary, "saved_note_id": saved_id}


class ToTaskBody(BaseModel):
    name: str | None = None
    schedule_kind: str  # at | every | cron
    schedule_value: dict
    execution_mode: str = "new_conversation"


@router.post("/{note_id}/to-task")
def note_to_task(
    note_id: int, body: ToTaskBody, session: Session = Depends(db_session)
) -> dict:
    """Turn a quick note into a scheduled task (intent#1 note→task): the note's
    content becomes the task prompt."""
    from helm.tasks.service import TaskService, task_public

    note = NoteService(session).get(note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    try:
        task = TaskService(session).create(
            body.name or (note.title or note.content[:40] or "task"),
            note.content,
            body.schedule_kind,
            body.schedule_value,
            execution_mode=body.execution_mode,
            linked_note_id=note.id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    return task_public(task)
