"""Deep Research ORM: a research session + the sources it gathered.

The structured report (summary + cited claims) is stored as JSON on the
session; sources are rows so citations (claim → source URL, constraint
180077c3) are queryable and the report view can link them."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class ResearchSession(Base):
    __tablename__ = "research_sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="pending"  # pending|running|completed|failed|stopped
    )
    rounds_done: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # Structured report: {"summary":..., "claims":[{"text",sources:[url]}], ...}
    report_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class ResearchSource(Base):
    """A source the engine found/read. Citations in the report reference these
    by URL."""

    __tablename__ = "research_sources"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("research_sessions.id"), nullable=False, index=True
    )
    url: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str | None] = mapped_column(String, nullable=True)
    snippet: Mapped[str | None] = mapped_column(Text, nullable=True)
    round: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
