"""Cockpit REST. m1: browse a directory + list/open projects. The terminal
(WS) and file-change stream come in m4/m5.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import zipfile
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.cockpit import models  # noqa: F401  (register models on Base.metadata)
from helm.cockpit.git import NotInRepo, file_diff
from helm.cockpit.git import status as git_status
from helm.cockpit.models import FileChange, TerminalSession
from helm.cockpit.preview import list_zip, read_text
from helm.cockpit.service import ProjectService, list_dir
from helm.cockpit.terminal import PtyProcess
from helm.cockpit.watcher import DirWatcher

router = APIRouter(prefix="/api/cockpit", tags=["cockpit"])


class OpenProjectBody(BaseModel):
    path: str


def _project_dict(p) -> dict:
    return {
        "path": p.path,
        "name": p.name,
        "badges": p.badge_list(),
        "last_opened": p.last_opened.isoformat() if p.last_opened else None,
    }


@router.get("/files")
def browse(path: str, session: Session = Depends(db_session)) -> dict:
    try:
        entries = list_dir(path)
    except (NotADirectoryError, FileNotFoundError):
        raise HTTPException(status_code=404, detail="not a directory") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="permission denied") from None
    return {
        "path": str(Path(path).expanduser()),
        "entries": [
            {
                "name": e.name,
                "path": e.path,
                "is_dir": e.is_dir,
                "size": e.size,
                "ext": e.ext,
            }
            for e in entries
        ],
    }


@router.get("/text")
def file_text(path: str) -> dict:
    try:
        content, truncated = read_text(path)
    except (FileNotFoundError, IsADirectoryError):
        raise HTTPException(status_code=404, detail="not a file") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="permission denied") from None
    return {"path": str(Path(path).expanduser()), "content": content, "truncated": truncated}


@router.get("/raw")
def file_raw(path: str) -> FileResponse:
    p = Path(path).expanduser()
    if not p.is_file():
        raise HTTPException(status_code=404, detail="not a file")
    return FileResponse(p)


@router.get("/zip")
def file_zip(path: str) -> dict:
    try:
        entries = list_zip(path)
    except (FileNotFoundError, IsADirectoryError):
        raise HTTPException(status_code=404, detail="not a file") from None
    except zipfile.BadZipFile:
        raise HTTPException(status_code=400, detail="not a zip") from None
    return {"entries": entries}


@router.get("/git/diff")
def git_diff(path: str) -> dict:
    try:
        return file_diff(path)
    except NotInRepo:
        raise HTTPException(status_code=404, detail="not in a git repo") from None


@router.get("/git/status")
def git_status_route(path: str) -> dict:
    return {"entries": git_status(path)}


@router.get("/projects")
def list_projects(session: Session = Depends(db_session)) -> dict:
    return {"projects": [_project_dict(p) for p in ProjectService(session).list()]}


def _record_session(ws: WebSocket, cwd: str | None) -> None:
    db = ws.app.state.db
    with db.session_scope() as s:
        s.add(TerminalSession(project_path=cwd))


@router.websocket("/terminal/ws")
async def terminal_ws(
    ws: WebSocket, path: str | None = None, cols: int = 80, rows: int = 24
) -> None:
    """Bridge a pty shell ↔ xterm.js. Protocol (JSON both ways):
    client → {type:'input',data} / {type:'resize',cols,rows};
    server → {type:'output',data} / {type:'exit',code}."""
    await ws.accept()
    cwd = path if path and os.path.isdir(path) else None
    shell = os.environ.get("SHELL") or shutil.which("bash") or "/bin/sh"
    pty_proc = PtyProcess([shell], cwd=cwd, cols=cols, rows=rows)
    _record_session(ws, cwd)

    loop = asyncio.get_running_loop()
    out_q: asyncio.Queue[bytes | None] = asyncio.Queue()

    def on_readable() -> None:
        data = pty_proc.read()
        if data:
            out_q.put_nowait(data)
        elif data == b"":  # EOF — child exited
            loop.remove_reader(pty_proc.master)
            out_q.put_nowait(None)

    loop.add_reader(pty_proc.master, on_readable)

    async def pump_output() -> None:
        # A send failure here (client vanished) is non-fatal: the receive loop's
        # finally owns teardown (remove_reader + close).
        while True:
            data = await out_q.get()
            if data is None:
                await ws.send_text(json.dumps({"type": "exit", "code": pty_proc.poll()}))
                return
            await ws.send_text(
                json.dumps({"type": "output", "data": data.decode("utf-8", "replace")})
            )

    out_task = asyncio.create_task(pump_output())
    try:
        while True:
            msg = json.loads(await ws.receive_text())
            if msg.get("type") == "input":
                pty_proc.write(msg["data"])
            elif msg.get("type") == "resize":
                pty_proc.resize(int(msg["cols"]), int(msg["rows"]))
    except (WebSocketDisconnect, KeyError, ValueError):
        pass
    finally:
        try:
            loop.remove_reader(pty_proc.master)
        except (ValueError, OSError):
            pass
        out_task.cancel()
        pty_proc.close()


@router.websocket("/watch/ws")
async def watch_ws(ws: WebSocket, path: str) -> None:
    """Stream filesystem changes under `path` to the dashboard: server →
    {type:'change', path, kind}. Each change is also recorded (best-effort)."""
    if not os.path.isdir(path):
        await ws.close(code=1008)
        return
    await ws.accept()

    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[dict] = asyncio.Queue()
    closed = False

    def on_change(event: dict) -> None:  # runs on the watchdog thread
        # Guard the cross-thread post: an in-flight event during teardown must
        # not call into a closing loop (RuntimeError on the observer thread).
        if closed:
            return
        try:
            loop.call_soon_threadsafe(queue.put_nowait, event)
        except RuntimeError:
            pass

    watcher = DirWatcher(path, on_change)
    watcher.start()
    db = ws.app.state.db

    try:
        while True:
            event = await queue.get()
            # Send first (keep highlight latency low), then persist best-effort.
            # NOTE(perf follow-up): this sync SQLite write is per-event and can
            # block the loop under write bursts; debounce/batch when throttling.
            await ws.send_text(json.dumps({"type": "change", **event}))
            try:
                with db.session_scope() as s:
                    s.add(FileChange(path=event["path"], change_kind=event["kind"]))
            except Exception:
                pass
    except (WebSocketDisconnect, RuntimeError, ConnectionError):
        pass
    finally:
        closed = True
        watcher.stop()


@router.post("/projects")
def open_project(
    body: OpenProjectBody, session: Session = Depends(db_session)
) -> dict:
    try:
        project = ProjectService(session).open(body.path)
    except (NotADirectoryError, FileNotFoundError):
        raise HTTPException(status_code=404, detail="not a directory") from None
    session.flush()  # populate defaults (last_opened) before serializing
    return _project_dict(project)
