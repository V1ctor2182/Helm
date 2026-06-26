"""RAG service: register document sources, index them into the vector store,
and retrieve. Indexing walks a directory (or single file), extracts text,
chunks it, and upserts the chunks; the SQLite `rag_sources` row tracks status
and counts so the UI (m5) can show what's indexed.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.rag.extract import chunk_text, extract_text, iter_files
from helm.rag.models import RagSource
from helm.rag.vector import RagVectorStore


def source_public(s: RagSource) -> dict:
    return {
        "id": s.id,
        "path": s.path,
        "kind": s.kind,
        "status": s.status,
        "file_count": s.file_count,
        "chunk_count": s.chunk_count,
        "error": s.error,
        "created_at": s.created_at.isoformat() if s.created_at else None,
        "indexed_at": s.indexed_at.isoformat() if s.indexed_at else None,
    }


class RagService:
    def __init__(self, session: Session, vectors: RagVectorStore | None = None) -> None:
        self.session = session
        self.vectors = vectors

    def list_sources(self) -> list[RagSource]:
        return list(
            self.session.scalars(
                select(RagSource).order_by(RagSource.created_at.desc())
            )
        )

    def get(self, source_id: int) -> RagSource | None:
        return self.session.get(RagSource, source_id)

    def add_source(self, path: str) -> RagSource:
        """Register a directory/file and index it. Raises FileNotFoundError if
        the path doesn't exist."""
        p = Path(path).expanduser()
        if not p.exists():
            raise FileNotFoundError(path)
        src = RagSource(
            path=str(p), kind="dir" if p.is_dir() else "file", status="pending"
        )
        self.session.add(src)
        self.session.flush()
        self._index(src)
        return src

    def _index(self, src: RagSource) -> None:
        """(Re)build the index for one source. Counts chunks even when no vector
        store is attached, so the registry is meaningful in keyword-less mode."""
        files = 0
        chunks = 0
        try:
            for f in iter_files(Path(src.path)):
                text = extract_text(f)
                if text is None:
                    continue
                pieces = chunk_text(text)
                if not pieces:
                    continue
                files += 1
                chunks += len(pieces)
                if self.vectors is not None:
                    self.vectors.add_chunks(src.id, str(f), pieces)
            src.file_count = files
            src.chunk_count = chunks
            src.status = "indexed"
            src.error = None
            src.indexed_at = datetime.now(timezone.utc)
        except Exception as exc:  # pragma: no cover - defensive
            src.status = "error"
            src.error = str(exc)
        self.session.flush()

    def reindex(self, source_id: int) -> RagSource | None:
        src = self.get(source_id)
        if src is None:
            return None
        if self.vectors is not None:
            self.vectors.delete_source(src.id)
        self._index(src)
        return src

    def remove_source(self, source_id: int) -> bool:
        src = self.get(source_id)
        if src is None:
            return False
        if self.vectors is not None:
            self.vectors.delete_source(src.id)
        self.session.delete(src)
        return True

    def search(self, query: str, limit: int = 5) -> list[dict]:
        """Semantic retrieval over all indexed chunks. Empty when no healthy
        vector store (RAG has no keyword fallback — it's vector-native)."""
        if self.vectors is None or not self.vectors.healthy:
            return []
        return self.vectors.query(query, n=limit)

    def stats(self) -> dict:
        sources = self.list_sources()
        return {
            "sources": len(sources),
            "files": sum(s.file_count for s in sources),
            "chunks": sum(s.chunk_count for s in sources),
            "vector_count": self.vectors.count() if self.vectors else 0,
        }
