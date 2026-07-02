"""Cockpit REST. m1: browse a directory + list/open projects. The terminal
(WS) and file-change stream come in m4/m5.
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
import subprocess
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
from helm.cockpit.models import TerminalSession
from fastapi import Request

from helm.cockpit import fsops, search as cksearch, thumbs
from helm.cockpit.preview import WriteConflict, list_zip, read_text, write_text
from helm.cockpit.service import ProjectService, list_dir, record_change
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
def browse(path: str, hidden: bool = False, session: Session = Depends(db_session)) -> dict:
    try:
        entries = list_dir(path, show_hidden=hidden)
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
                "mtime": e.mtime,
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
    return {
        "path": str(Path(path).expanduser()),
        "content": content,
        "truncated": truncated,
        "mtime": Path(path).expanduser().stat().st_mtime,
    }


class FsDirNameBody(BaseModel):
    dir: str
    name: str


class FsRenameBody(BaseModel):
    path: str
    name: str


class FsPathBody(BaseModel):
    path: str


def _fs_errors(fn):
    try:
        return fn()
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="not found") from None
    except FileExistsError:
        raise HTTPException(status_code=409, detail="已存在同名项") from None
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from None
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from None


@router.post("/fs/mkdir")
def fs_mkdir(body: FsDirNameBody) -> dict:
    return {"path": _fs_errors(lambda: fsops.make_dir(body.dir, body.name))}


@router.post("/fs/newfile")
def fs_newfile(body: FsDirNameBody) -> dict:
    return {"path": _fs_errors(lambda: fsops.make_file(body.dir, body.name))}


@router.post("/fs/rename")
def fs_rename(body: FsRenameBody) -> dict:
    return {"path": _fs_errors(lambda: fsops.rename_path(body.path, body.name))}


@router.post("/fs/open")
def fs_open(body: FsPathBody) -> dict:
    _fs_errors(lambda: fsops.open_with_system(body.path))
    return {"opened": body.path}


@router.post("/fs/trash")
def fs_trash(body: FsPathBody) -> dict:
    _fs_errors(lambda: fsops.move_to_trash(body.path))
    return {"trashed": body.path}


class ResolvePathsBody(BaseModel):
    cwd: str | None = None
    candidates: list[str]


@router.post("/paths/resolve")
def resolve_paths(body: ResolvePathsBody) -> dict:
    """终端路径点击的服务端验证层(承 FanBox srv:937-971):批量 stat 候选,
    相对路径以 cwd 为基准;只回存在的,前端只给验证过的划线。"""
    out: dict[str, dict] = {}
    base = Path(body.cwd).expanduser() if body.cwd else None
    for raw in body.candidates[:50]:
        if not raw or len(raw) > 1024:
            continue
        token = raw[7:] if raw.startswith("file://") else raw
        stripped = token.rstrip("/") or "/"
        p = Path(stripped).expanduser()
        try:
            cand = p if p.is_absolute() else (base / p if base is not None else None)
            if cand is None:
                continue
            cand = cand.resolve()
            if cand.exists():
                out[raw] = {"path": str(cand), "is_dir": cand.is_dir()}
        except OSError:
            continue
    return {"resolved": out}


class WriteTextBody(BaseModel):
    path: str
    content: str
    # 编辑器加载时的 mtime;磁盘更新则 409(agent 外改,覆盖需显式确认)
    expected_mtime: float | None = None


@router.post("/text")
def file_text_write(body: WriteTextBody) -> dict:
    try:
        mtime = write_text(body.path, body.content, body.expected_mtime)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="not a file") from None
    except PermissionError:
        raise HTTPException(status_code=403, detail="permission denied") from None
    except ValueError:
        raise HTTPException(status_code=413, detail="content too large") from None
    except WriteConflict as exc:
        raise HTTPException(
            status_code=409,
            detail={"error": "modified externally", "mtime": exc.mtime},
        ) from None
    return {"path": str(Path(body.path).expanduser()), "mtime": mtime}


@router.get("/search")
def cockpit_search(q: str, root: str, mode: str = "name") -> dict:
    """⌘K 文件名/内容搜索(承 FanBox)。mode=name|content。"""
    if mode == "content":
        return cksearch.search_content(q, root)
    return cksearch.search_files(q, root)


@router.get("/thumb")
def file_thumb(path: str, request: Request, w: int = 240) -> FileResponse:
    """图片缩略图(sips+缓存,承 FanBox);失败前端回退字形不留裂图。"""
    cache = thumbs.cache_dir_for(request.app.state.config.data_dir)
    try:
        out, mime = thumbs.ensure_thumb(path, w, cache)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="not a file") from None
    except ValueError:
        raise HTTPException(status_code=400, detail="not an image") from None
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from None
    return FileResponse(out, media_type=mime, headers={"Cache-Control": "max-age=604800"})


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


def shell_argv_env(environ: dict | None = None) -> tuple[list[str], dict]:
    """终端 shell 启动参数(承 FanBox 1.11.2):
    login shell(-l)——GUI 启动只继承精简 PATH、不读 .zprofile,用户在那里配的
    Homebrew/nvm 路径(claude 等)会丢;GUI 无 locale 时兜底 UTF-8,防中文路径乱码。"""
    base = dict(os.environ if environ is None else environ)
    shell = base.get("SHELL") or shutil.which("bash") or "/bin/sh"
    argv = [shell] if shell.endswith("powershell.exe") else [shell, "-l"]
    base["TERM"] = "xterm-256color"
    if not re.search(
        r"UTF-8", base.get("LC_ALL") or base.get("LC_CTYPE") or base.get("LANG") or "", re.I
    ):
        base["LANG"] = "zh_CN.UTF-8"
    return argv, base


@router.websocket("/terminal/ws")
async def terminal_ws(
    ws: WebSocket, path: str | None = None, cols: int = 80, rows: int = 24
) -> None:
    """Bridge a pty shell ↔ xterm.js. Protocol (JSON both ways):
    client → {type:'input',data} / {type:'resize',cols,rows};
    server → {type:'output',data} / {type:'exit',code}."""
    await ws.accept()
    cwd = path if path and os.path.isdir(path) else None
    argv, env = shell_argv_env()
    pty_proc = PtyProcess(argv, cwd=cwd, cols=cols, rows=rows, env=env)
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
                    record_change(s, event["path"], event["kind"])
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
