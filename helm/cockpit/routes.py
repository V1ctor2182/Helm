"""Cockpit REST. m1: browse a directory + list/open projects. The terminal
(WS) and file-change stream come in m4/m5.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.cockpit import models  # noqa: F401  (register Project on Base.metadata)
from helm.cockpit.preview import list_zip, read_text
from helm.cockpit.service import ProjectService, list_dir

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


@router.get("/projects")
def list_projects(session: Session = Depends(db_session)) -> dict:
    return {"projects": [_project_dict(p) for p in ProjectService(session).list()]}


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
