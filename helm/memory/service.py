"""Memory store: CRUD + hybrid (vector + keyword) recall over `memories`.

Keyword recall is a Jaccard token-overlap score ported from Odysseus
(`src/memory.py: tokenize` / `get_text_similarity`). m2 adds the ChromaDB +
fastembed vector index (:class:`~helm.memory.vector.MemoryVectorStore`) and
fuses semantic similarity with the keyword score. The keyword path stays as the
graceful-degradation fallback: when no vector store is attached, or it's
unhealthy, recall is keyword-only and the API behaves exactly as in m1.
"""

from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.memory.models import Memory
from helm.memory.vector import MemoryVectorStore

# Hybrid fusion weight: final = VECTOR_WEIGHT*semantic + (1-VECTOR_WEIGHT)*keyword.
# Leans semantic (the point of m2) while keeping exact-token matches influential.
VECTOR_WEIGHT = 0.7

# Categories the intent calls out; not enforced (free-form column) but used to
# validate API input softly and to seed the UI filter in m3.
CATEGORIES = ("fact", "preference", "decision")


def tokenize(text: str) -> list[str]:
    """Split on whitespace and strip trailing punctuation. Ported verbatim from
    Odysseus `src/memory.py` so keyword recall matches the source semantics."""
    return [word.strip('.,!?";') for word in text.split()]


def keyword_similarity(text1: str, text2: str) -> float:
    """Jaccard similarity over lowercased token sets (Odysseus
    `get_text_similarity`). 1.0 = identical token sets, 0.0 = disjoint."""
    if not text1 or not text2:
        return 0.0
    tokens1 = set(tokenize(text1.lower()))
    tokens2 = set(tokenize(text2.lower()))
    if not tokens1 and not tokens2:
        return 1.0
    if not tokens1 or not tokens2:
        return 0.0
    intersection = tokens1 & tokens2
    union = tokens1 | tokens2
    return len(intersection) / len(union)


def memory_public(m: Memory) -> dict:
    """Serialize a Memory for the API (tags decoded from JSON)."""
    return {
        "id": m.id,
        "text": m.text,
        "category": m.category,
        "source": m.source,
        "session_id": m.session_id,
        "tags": json.loads(m.tags_json or "[]"),
        "uses": m.uses,
        "pinned": m.pinned,
        "created_at": m.created_at.isoformat() if m.created_at else None,
        "updated_at": m.updated_at.isoformat() if m.updated_at else None,
    }


class MemoryService:
    """CRUD + keyword recall. One instance per request (wraps a Session)."""

    def __init__(
        self, session: Session, vectors: MemoryVectorStore | None = None
    ) -> None:
        self.session = session
        self.vectors = vectors

    def list(self, category: str | None = None, pinned: bool | None = None) -> list[Memory]:
        """All memories, newest first, optionally filtered by category/pinned."""
        stmt = select(Memory).order_by(Memory.pinned.desc(), Memory.created_at.desc())
        if category is not None:
            stmt = stmt.where(Memory.category == category)
        if pinned is not None:
            stmt = stmt.where(Memory.pinned == pinned)
        return list(self.session.scalars(stmt))

    def get(self, memory_id: int) -> Memory | None:
        return self.session.get(Memory, memory_id)

    def create(
        self,
        text: str,
        category: str = "fact",
        source: str = "manual",
        session_id: str | None = None,
        tags: list[str] | None = None,
        pinned: bool = False,
    ) -> Memory:
        memory = Memory(
            text=text.strip(),
            category=category,
            source=source,
            session_id=session_id,
            tags_json=json.dumps(tags or [], ensure_ascii=False),
            pinned=pinned,
        )
        self.session.add(memory)
        self.session.flush()  # assign id within the request transaction
        if self.vectors is not None:
            self.vectors.upsert(memory.id, memory.text)
        return memory

    def update(
        self,
        memory_id: int,
        *,
        text: str | None = None,
        category: str | None = None,
        tags: list[str] | None = None,
        pinned: bool | None = None,
    ) -> Memory | None:
        memory = self.get(memory_id)
        if memory is None:
            return None
        text_changed = False
        if text is not None:
            memory.text = text.strip()
            text_changed = True
        if category is not None:
            memory.category = category
        if tags is not None:
            memory.tags_json = json.dumps(tags, ensure_ascii=False)
        if pinned is not None:
            memory.pinned = pinned
        self.session.flush()
        # Re-index only when the embedded text changed (category/tags/pin don't
        # affect the vector).
        if text_changed and self.vectors is not None:
            self.vectors.upsert(memory.id, memory.text)
        return memory

    def delete(self, memory_id: int) -> bool:
        memory = self.get(memory_id)
        if memory is None:
            return False
        self.session.delete(memory)
        if self.vectors is not None:
            self.vectors.delete(memory_id)
        return True

    def search(
        self, query: str, limit: int = 10, category: str | None = None
    ) -> list[tuple[Memory, float]]:
        """Hybrid recall: fuse vector similarity (ChromaDB) with keyword
        Jaccard, return top `limit` as (memory, score) best-first.

        When no healthy vector store is attached, this is keyword-only (m1
        behavior) — every candidate scored by token overlap. With the vector
        store, semantic neighbours that share no tokens still surface, and the
        two scores are blended by :data:`VECTOR_WEIGHT`.

        Single-user local store, so keyword scoring runs in Python over the
        candidate set; the vector side uses Chroma's ANN index.
        """
        if not query.strip():
            return []
        candidates = self.list(category=category)
        by_id = {m.id: m for m in candidates}

        # Keyword score for every candidate.
        keyword: dict[int, float] = {
            m.id: keyword_similarity(query, m.text) for m in candidates
        }

        # Vector score for semantic neighbours (filtered to the candidate set so
        # a category filter still holds).
        vector: dict[int, float] = {}
        if self.vectors is not None and self.vectors.healthy:
            for mid, sim in self.vectors.query(query, n=max(limit * 4, 20)):
                if mid in by_id:
                    vector[mid] = sim

        if not vector:
            # Degraded / keyword-only path: drop zero-score rows (m1 semantics).
            scored = [(by_id[i], s) for i, s in keyword.items() if s > 0.0]
            scored.sort(key=lambda pair: pair[1], reverse=True)
            return scored[:limit]

        # Fuse across the union of ids that scored on either signal.
        fused: list[tuple[Memory, float]] = []
        for mid in keyword.keys() | vector.keys():
            score = VECTOR_WEIGHT * vector.get(mid, 0.0) + (
                1 - VECTOR_WEIGHT
            ) * keyword.get(mid, 0.0)
            if score > 0.0:
                fused.append((by_id[mid], score))
        fused.sort(key=lambda pair: pair[1], reverse=True)
        return fused[:limit]

    def export_all(self) -> list[dict]:
        """Every memory as a public dict — the JSON export payload (constraint
        463c14ca: memories must support JSON import/export)."""
        return [memory_public(m) for m in self.list()]

    def import_entries(self, entries: list[dict], replace: bool = False) -> int:
        """Insert memories from an export payload, re-indexing each into the
        vector store. Incoming ids are ignored (fresh ids assigned) so importing
        never collides with existing rows. ``replace=True`` clears the store
        first (explicit destructive opt-in, e.g. restoring a backup). Returns
        the number imported."""
        if replace:
            for m in self.list():
                self.delete(m.id)
            if self.vectors is not None:
                self.vectors.reset()
        count = 0
        for entry in entries:
            text = str(entry.get("text", "")).strip()
            if not text:
                continue  # skip malformed rows rather than fail the whole batch
            tags = entry.get("tags")
            self.create(
                text=text,
                category=entry.get("category") or "fact",
                source=entry.get("source") or "import",
                session_id=entry.get("session_id"),
                tags=tags if isinstance(tags, list) else None,
                pinned=bool(entry.get("pinned", False)),
            )
            count += 1
        return count

    def touch(self, memory_id: int) -> Memory | None:
        """Bump the recall counter — called when a memory is surfaced to the
        brain/agent so usage can later inform pruning/ranking."""
        memory = self.get(memory_id)
        if memory is None:
            return None
        memory.uses += 1
        self.session.flush()
        return memory
