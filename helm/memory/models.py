"""Memory ORM model. m1 ships `memories`; the ChromaDB vector index (m2) is a
sidecar keyed by `memories.id`, not a column here.

Fields mirror Odysseus's memory entry shape (text/category/source/uses/
timestamp) so the recall semantics port faithfully, but the store is the
platform-shell SQLite DB rather than Odysseus's memory.json (constraint
8ace2b3a). `session_id` is a free-form string ref, NOT a FK to chat.sessions —
memory must not hard-couple to the chat room (cross-room contract; kept loose
on purpose, see decision 2cb56d3b).
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class Memory(Base):
    """A single persisted memory: a short fact/preference/decision the brain
    keeps across sessions and projects."""

    __tablename__ = "memories"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    # fact | preference | decision — free-form but these three are the intent's
    # categories; defaulted rather than enum'd so new kinds don't need migration.
    category: Mapped[str] = mapped_column(String(40), nullable=False, default="fact")
    # manual | chat | agent — where the memory came from.
    source: Mapped[str] = mapped_column(String(40), nullable=False, default="manual")
    # Loose ref to an originating session (e.g. a chat session id), or null.
    session_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # JSON-encoded list[str] of tags; "[]" when none.
    tags_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    # Recall counter — bumped each time the memory is surfaced (touch()).
    uses: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # Pinned memories are always-on context, never auto-pruned later.
    pinned: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"Memory(id={self.id!r}, category={self.category!r})"
