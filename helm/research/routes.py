"""Deep Research REST. m1: read past research (list + report with sources).
The start route (real providers, async run) lands in m2/m3."""

from __future__ import annotations

import asyncio
import contextlib
import threading

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    WebSocket,
    WebSocketDisconnect,
)
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.research import models  # noqa: F401  (register tables on Base)
from helm.research.factory import build_engine
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


@router.websocket("/ws")
async def research_ws(ws: WebSocket) -> None:
    """Run (or resume) a research session, streaming progress to the client.

    client → {provider_id, model, question?|resume_session_id?} then optionally
             {type:'stop'} to interrupt.
    server → {type:'started', session_id} · {type:'progress', kind, ...} ·
             {type:'done', session_id, status} | {type:'error', error}

    The engine loop is sync → run in a thread; its on_event callback hands
    progress to the WS via a thread-safe queue. Stop (or client disconnect)
    sets a cancel flag the engine polls each round (intent#2: observable +
    interruptible/resumable).
    """
    await ws.accept()
    db = ws.app.state.db
    box = ws.app.state.secret_box
    try:
        start = await ws.receive_json()
    except (WebSocketDisconnect, RuntimeError, ValueError):
        return

    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()
    cancel_flag = threading.Event()

    def on_event(kind: str, data: dict) -> None:
        loop.call_soon_threadsafe(
            queue.put_nowait, {"type": "progress", "kind": kind, **data}
        )

    try:
        with db.session_scope() as s:
            engine = build_engine(
                s, box, start.get("provider_id"), start.get("model", ""),
                on_event=on_event,
            )
    except KeyError as exc:
        await ws.send_json({"type": "error", "error": str(exc)})
        await ws.close()
        return

    result: dict = {}

    def do_run() -> None:
        try:
            with db.session_scope() as s:
                sess = ResearchService(s).run_research(
                    start.get("question", ""),
                    engine,
                    cancel=cancel_flag.is_set,
                    resume_session_id=start.get("resume_session_id"),
                )
                result["session_id"] = sess.id
                result["status"] = sess.status
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)  # sentinel

    async def receiver() -> None:
        try:
            while True:
                msg = await ws.receive_json()
                if msg.get("type") == "stop":
                    cancel_flag.set()
        except (WebSocketDisconnect, RuntimeError, ValueError):
            cancel_flag.set()  # client gone → interrupt the run

    recv_task = asyncio.create_task(receiver())
    run_task = asyncio.create_task(asyncio.to_thread(do_run))
    try:
        while True:
            item = await queue.get()
            if item is None:
                break
            await ws.send_json(item)
        await run_task
        await ws.send_json(
            {
                "type": "done",
                "session_id": result.get("session_id"),
                "status": result.get("status"),
            }
        )
    except WebSocketDisconnect:
        cancel_flag.set()
        await run_task
    finally:
        recv_task.cancel()
        with contextlib.suppress(Exception):
            await ws.close()
