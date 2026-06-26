"""FileService + project detection. Reads the user's local filesystem directly
(local-first single-user app — browsing your own files is the point); no
sandbox. Backend pipe rewritten in Python per F1 (replaces FanBox's Node fs).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from helm.cockpit.models import FileChange, Project

# file_changes is append-only (drives the live dashboard WS; the DB copy is for
# future replay/inbox) with no reader yet — cap it so a long watch session can't
# grow the table without bound (ticket 5582cd77).
MAX_FILE_CHANGES = 5000
_PRUNE_EVERY = 200


def record_change(
    session: Session, path: str, kind: str, *, cap: int = MAX_FILE_CHANGES
) -> FileChange:
    """Persist one file change, pruning the oldest beyond ``cap`` amortized
    (every ~``_PRUNE_EVERY`` inserts, a cheap id-threshold DELETE)."""
    change = FileChange(path=path, change_kind=kind)
    session.add(change)
    session.flush()  # assign id
    if change.id % _PRUNE_EVERY == 0:
        cutoff = change.id - cap
        if cutoff > 0:
            session.execute(delete(FileChange).where(FileChange.id <= cutoff))
    return change


def file_change_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(FileChange)) or 0

# Marker file → project type badge.
_BADGE_MARKERS: list[tuple[str, str]] = [
    ("package.json", "node"),
    ("pyproject.toml", "py"),
    ("requirements.txt", "py"),
    ("setup.py", "py"),
    ("Cargo.toml", "rs"),
    ("go.mod", "go"),
    ("index.html", "web"),
]


@dataclass
class DirEntry:
    name: str
    path: str
    is_dir: bool
    size: int
    ext: str


def detect_badges(folder: Path) -> list[str]:
    """Type tags for a folder, by marker files (deduped, stable order)."""
    badges: list[str] = []
    for marker, badge in _BADGE_MARKERS:
        if badge not in badges and (folder / marker).exists():
            badges.append(badge)
    return badges


def list_dir(path: str) -> list[DirEntry]:
    """List a directory: dirs first, then files, each alphabetical."""
    base = Path(path).expanduser()
    if not base.is_dir():
        raise NotADirectoryError(path)
    entries: list[DirEntry] = []
    for child in base.iterdir():
        try:
            is_dir = child.is_dir()
            size = 0 if is_dir else child.stat().st_size
        except OSError:
            continue  # unreadable entry — skip rather than fail the listing
        entries.append(
            DirEntry(
                name=child.name,
                path=str(child),
                is_dir=is_dir,
                size=size,
                ext="" if is_dir else child.suffix.lower().lstrip("."),
            )
        )
    entries.sort(key=lambda e: (not e.is_dir, e.name.lower()))
    return entries


class ProjectService:
    """Project registry backed by the `projects` table."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def list(self) -> list[Project]:
        return list(
            self._session.execute(
                select(Project).order_by(Project.last_opened.desc())
            ).scalars()
        )

    def open(self, path: str) -> Project:
        """Register/refresh a project by path: detect badges, bump last_opened."""
        folder = Path(path).expanduser()
        if not folder.is_dir():
            raise NotADirectoryError(path)
        abs_path = str(folder)
        badges = ",".join(detect_badges(folder))
        row = self._session.get(Project, abs_path)
        if row is None:
            row = Project(path=abs_path, name=folder.name, badges=badges)
            self._session.add(row)
        else:
            row.badges = badges
            row.last_opened = datetime.now(timezone.utc)
        return row
