"""Agent-orchestration ORM: a run of an agent (one Claude Code invocation).

The cockpit observes runs live via ACP events (m3/m4); this table is the
durable record — what ran, where, status, outcome — so a run survives the WS
and can be listed/inspected after the fact. ``session_id`` is a loose ref to a
terminal session, not a FK (the agent run outlives / is independent of the pty)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class AgentRun(Base):
    __tablename__ = "agent_runs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    project_path: Mapped[str | None] = mapped_column(String, nullable=True)
    agent: Mapped[str] = mapped_column(String(40), nullable=False)  # adapter name
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending")
    prompt: Mapped[str | None] = mapped_column(Text, nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"AgentRun(id={self.id!r}, agent={self.agent!r}, status={self.status!r})"
