"""First-run state + data import/export.

First-run is a simple flag: feature rooms (e.g. chat-multimodel's "configure a
model" onboarding) read ``/api/setup/status`` to decide whether to show setup,
and POST ``/api/setup/complete`` when done. platform-shell owns the mechanism,
not the onboarding UI.
"""

from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from starlette.background import BackgroundTask

from helm import __version__
from helm.app import db_session, get_db
from helm.backup import export_archive, import_archive
from helm.db import Database
from helm.settings import SettingsService

router = APIRouter(prefix="/api", tags=["setup"])

_SETUP_DONE_KEY = "setup.completed"


@router.get("/setup/status")
def setup_status(session: Session = Depends(db_session)) -> dict:
    done = SettingsService(session).get(_SETUP_DONE_KEY) == "true"
    return {"first_run": not done, "version": __version__}


@router.post("/setup/complete")
def setup_complete(session: Session = Depends(db_session)) -> dict:
    SettingsService(session).set(_SETUP_DONE_KEY, "true")
    return {"first_run": False}


@router.get("/data/export")
def data_export(db: Database = Depends(get_db)) -> FileResponse:
    workdir = Path(tempfile.mkdtemp(prefix="helm-export-"))
    archive = workdir / "helm-backup.zip"
    export_archive(db, archive)

    def _cleanup() -> None:
        archive.unlink(missing_ok=True)
        try:
            workdir.rmdir()
        except OSError:
            pass

    return FileResponse(
        archive,
        filename="helm-backup.zip",
        media_type="application/zip",
        background=BackgroundTask(_cleanup),
    )


@router.post("/data/import")
async def data_import(file: UploadFile, db: Database = Depends(get_db)) -> dict:
    tmp = Path(tempfile.mkstemp(suffix=".zip")[1])
    try:
        tmp.write_bytes(await file.read())
        result = import_archive(db, tmp)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    finally:
        tmp.unlink(missing_ok=True)
    return {"imported": result}
