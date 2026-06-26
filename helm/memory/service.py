"""Memory store: CRUD + keyword recall over the SQLite `memories` table.

m1 recall is keyword-only — a Jaccard token-overlap score ported from Odysseus
(`src/memory.py: tokenize` / `get_text_similarity`). m2 adds the ChromaDB +
fastembed vector index and fuses the two into hybrid search; keeping the
keyword path here means recall works (and is verifiable) before the embedding
dependency is wired in, and stays as the graceful-degradation fallback.
"""

from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.memory.models import Memory

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

    def __init__(self, session: Session) -> None:
        self.session = session

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
        if text is not None:
            memory.text = text.strip()
        if category is not None:
            memory.category = category
        if tags is not None:
            memory.tags_json = json.dumps(tags, ensure_ascii=False)
        if pinned is not None:
            memory.pinned = pinned
        self.session.flush()
        return memory

    def delete(self, memory_id: int) -> bool:
        memory = self.get(memory_id)
        if memory is None:
            return False
        self.session.delete(memory)
        return True

    def search(
        self, query: str, limit: int = 10, category: str | None = None
    ) -> list[tuple[Memory, float]]:
        """Keyword recall: rank candidates by token-overlap similarity to the
        query, drop zero-score rows, return top `limit` as (memory, score).

        m1 scores in Python over the candidate set (single-user local store —
        the memory table is small). m2 replaces this with a ChromaDB ANN query
        fused with this keyword score."""
        if not query.strip():
            return []
        candidates = self.list(category=category)
        scored = [
            (m, keyword_similarity(query, m.text))
            for m in candidates
        ]
        scored = [pair for pair in scored if pair[1] > 0.0]
        scored.sort(key=lambda pair: pair[1], reverse=True)
        return scored[:limit]

    def touch(self, memory_id: int) -> Memory | None:
        """Bump the recall counter — called when a memory is surfaced to the
        brain/agent so usage can later inform pruning/ranking."""
        memory = self.get(memory_id)
        if memory is None:
            return None
        memory.uses += 1
        self.session.flush()
        return memory
