"""Cockpit ORM models. m1 ships `projects`; `terminal_sessions` (m4) and
`file_changes` (m5) land with their milestones — their schemas are recorded in
the m1 decision (F0 §5) but not created until used, to avoid empty tables.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class Project(Base):
    """A local project folder the user has opened in the cockpit.

    Keyed by absolute path. ``badges`` is a comma-separated set of detected
    type tags (node/py/web/rs/go) so the file browser can label folders.
    """

    __tablename__ = "projects"

    path: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    badges: Mapped[str] = mapped_column(String, nullable=False, default="")
    last_opened: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    def badge_list(self) -> list[str]:
        return [b for b in self.badges.split(",") if b]


class TerminalSession(Base):
    """One embedded-terminal session. ``agent`` is set when an agent (Claude
    Code / Codex) is launched in it (F5); null for a plain shell."""

    __tablename__ = "terminal_sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_path: Mapped[str | None] = mapped_column(String, nullable=True)
    agent: Mapped[str | None] = mapped_column(String, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class FileChange(Base):
    """One observed filesystem change — drives the live dashboard (P0) and,
    later, replay/inbox (P1). ``session_id`` links to a terminal session when
    known (null for plain directory watching)."""

    __tablename__ = "file_changes"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int | None] = mapped_column(nullable=True)
    path: Mapped[str] = mapped_column(String, nullable=False)
    change_kind: Mapped[str] = mapped_column(String, nullable=False)
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
