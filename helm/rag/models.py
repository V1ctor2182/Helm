"""RAG ORM model: registered document sources. The chunk vectors live in
ChromaDB (keyed by source id); SQLite only tracks the source registry +
index status so the UI can list sources and their counts."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class RagSource(Base):
    """A directory or file the user registered for retrieval."""

    __tablename__ = "rag_sources"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    path: Mapped[str] = mapped_column(String, nullable=False)
    kind: Mapped[str] = mapped_column(String(8), nullable=False)  # dir | file
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="pending"  # pending|indexed|error
    )
    file_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    chunk_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    indexed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"RagSource(id={self.id!r}, path={self.path!r}, status={self.status!r})"
