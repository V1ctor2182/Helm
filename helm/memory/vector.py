"""ChromaDB-backed vector index over memory entries (semantic recall).

Mirrors Odysseus `src/memory_vector.py`: a persistent Chroma collection keyed by
the SQLite `memories.id`, storing pre-computed embeddings from an injected
:class:`~helm.memory.embedding.Embedder`. The store carries a ``healthy`` flag
and degrades gracefully — if Chroma or the embedder fails to initialize, the
service falls back to keyword-only recall (constraint: local-first, the brain
must still work without the vector path).
"""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)

# 3–512 chars, [a-zA-Z0-9._-]; Odysseus uses "odysseus_memories".
COLLECTION_NAME = "helm_memories"


class MemoryVectorStore:
    """Vector index for memory semantic search. One per app (lives on
    ``app.state``); cheap to construct (the embedder model loads lazily)."""

    def __init__(self, data_dir, embedder, *, subdir: str = "memory_vectors") -> None:
        self._embedder = embedder
        self._collection = None
        self._healthy = False
        try:
            import chromadb
            from chromadb.config import Settings

            path = str(data_dir / subdir)
            client = chromadb.PersistentClient(
                path=path, settings=Settings(anonymized_telemetry=False)
            )
            # cosine space: bge embeddings are normalized, so similarity = 1 - distance.
            self._collection = client.get_or_create_collection(
                COLLECTION_NAME, metadata={"hnsw:space": "cosine"}
            )
            self._healthy = True
        except Exception as exc:  # pragma: no cover - exercised via degraded tests
            logger.warning("MemoryVectorStore init failed, degrading: %s", exc)

    @property
    def healthy(self) -> bool:
        return self._healthy

    def count(self) -> int:
        if not self._healthy:
            return 0
        return self._collection.count()

    def upsert(self, memory_id: int, text: str) -> None:
        """Index (or re-index) one memory. Embedding failure degrades to no-op
        so a transient embedder error never breaks the write path."""
        if not self._healthy:
            return
        try:
            vectors = self._embedder.embed([text])
            if not vectors:
                return
            self._collection.upsert(
                ids=[str(memory_id)], embeddings=vectors, documents=[text]
            )
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("vector upsert failed for %s: %s", memory_id, exc)

    def delete(self, memory_id: int) -> None:
        if not self._healthy:
            return
        try:
            self._collection.delete(ids=[str(memory_id)])
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("vector delete failed for %s: %s", memory_id, exc)

    def query(self, text: str, n: int = 10) -> list[tuple[int, float]]:
        """Return up to ``n`` (memory_id, similarity) pairs, best first.
        Similarity is ``1 - cosine_distance`` in [0, 1]. Empty/failed → []."""
        if not self._healthy or not text.strip() or self.count() == 0:
            return []
        try:
            vectors = self._embedder.embed([text])
            if not vectors:
                return []
            res = self._collection.query(
                query_embeddings=vectors, n_results=min(n, self.count())
            )
            ids = res["ids"][0]
            distances = res["distances"][0]
            return [(int(i), 1.0 - float(d)) for i, d in zip(ids, distances)]
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("vector query failed: %s", exc)
            return []

    def reset(self) -> None:
        """Drop all vectors (used by JSON import/clear in m3)."""
        if not self._healthy:
            return
        existing = self._collection.get()["ids"]
        if existing:
            self._collection.delete(ids=existing)
