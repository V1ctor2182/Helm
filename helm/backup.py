"""Backup: export/import Helm's local data (settings + encrypted secrets).

The archive is a zip with a manifest and a snapshot of the SQLite DB. The
encryption key (``.app_key``) is deliberately NOT included — a leaked backup
must not be able to decrypt secrets. Consequence: restoring onto a *different*
machine (new key) brings settings back but secret ciphertext won't decrypt under
the new key (surfaces as DecryptionError) — the user re-enters those. Restoring
on the same machine is a full restore.
"""

from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import zipfile
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from helm import __version__
from helm.db import Database
from helm.models import Secret, Setting

BACKUP_FORMAT = "helm-backup"
BACKUP_FORMAT_VERSION = 1
_MANIFEST_NAME = "manifest.json"
_DB_NAME = "app.db"


def export_archive(db: Database, dest_path: Path) -> Path:
    """Write a backup zip (manifest + a clean SQLite snapshot) to dest_path."""
    dest_path = Path(dest_path)
    db_path = db.engine.url.database  # sqlite file path

    # VACUUM INTO produces a single-file snapshot of committed state (handles
    # WAL) from a separate connection without disturbing the live engine.
    snapshot = dest_path.with_suffix(".dbsnapshot")
    snapshot.unlink(missing_ok=True)
    try:
        with closing(sqlite3.connect(db_path)) as src:
            src.execute("VACUUM INTO ?", (str(snapshot),))

        manifest = {
            "format": BACKUP_FORMAT,
            "format_version": BACKUP_FORMAT_VERSION,
            "app_version": __version__,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        with zipfile.ZipFile(dest_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr(_MANIFEST_NAME, json.dumps(manifest, indent=2))
            zf.write(snapshot, _DB_NAME)
    finally:
        snapshot.unlink(missing_ok=True)
    return dest_path


def import_archive(db: Database, archive_path: Path) -> dict[str, int]:
    """Restore settings + secrets from a backup zip into the live DB (upsert).

    Raises ValueError on a malformed / non-Helm archive.
    """
    archive_path = Path(archive_path)
    try:
        with zipfile.ZipFile(archive_path) as zf:
            manifest = json.loads(zf.read(_MANIFEST_NAME))
            if manifest.get("format") != BACKUP_FORMAT:
                raise ValueError("not a Helm backup archive")
            db_bytes = zf.read(_DB_NAME)
    except (zipfile.BadZipFile, KeyError) as exc:
        raise ValueError("invalid or corrupt backup archive") from exc

    fd, tmp_name = tempfile.mkstemp(suffix=".importdb")
    os.close(fd)
    tmp = Path(tmp_name)
    try:
        tmp.write_bytes(db_bytes)
        with closing(sqlite3.connect(tmp)) as src:
            src.row_factory = sqlite3.Row
            settings_rows = src.execute("SELECT key, value FROM settings").fetchall()
            secret_rows = src.execute("SELECT key, value FROM secrets").fetchall()
    except sqlite3.DatabaseError as exc:
        raise ValueError("backup database is unreadable or missing tables") from exc
    finally:
        tmp.unlink(missing_ok=True)

    with db.session_scope() as session:
        for r in settings_rows:
            _upsert(session, Setting, r["key"], r["value"])
        for r in secret_rows:
            # value is already ciphertext; copied verbatim (no re-encrypt).
            _upsert(session, Secret, r["key"], r["value"])

    return {"settings": len(settings_rows), "secrets": len(secret_rows)}


def _upsert(session, model, key: str, value: str) -> None:
    row = session.get(model, key)
    if row is None:
        session.add(model(key=key, value=value))
    else:
        row.value = value
