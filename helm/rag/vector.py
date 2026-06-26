"""ChromaDB-backed vector index over document chunks (RAG retrieval).

Separate collection from memory (`helm_rag`), but shares the injected
:class:`~helm.memory.embedding.Embedder` — one embedder serves both, mirroring
Odysseus sharing its EmbeddingClient between memory and RAG. Each chunk stores
its text (document) + metadata (source_id, path, chunk index) so retrieval can
return the snippet and where it came from. Carries the same ``healthy``
graceful-degradation flag as the memory store.
"""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)

COLLECTION_NAME = "helm_rag"


class RagVectorStore:
    def __init__(self, data_dir, embedder, *, subdir: str = "rag_vectors") -> None:
        self._embedder = embedder
        self._collection = None
        self._healthy = False
        try:
            import chromadb
            from chromadb.config import Settings

            client = chromadb.PersistentClient(
                path=str(data_dir / subdir),
                settings=Settings(anonymized_telemetry=False),
            )
            self._collection = client.get_or_create_collection(
                COLLECTION_NAME, metadata={"hnsw:space": "cosine"}
            )
            self._healthy = True
        except Exception as exc:  # pragma: no cover - exercised via degraded path
            logger.warning("RagVectorStore init failed, degrading: %s", exc)

    @property
    def healthy(self) -> bool:
        return self._healthy

    def count(self) -> int:
        return self._collection.count() if self._healthy else 0

    def add_chunks(self, source_id: int, path: str, chunks: list[str]) -> int:
        """Embed and index a file's chunks. Returns the number indexed (0 when
        unhealthy or embedding fails — the caller still counts chunks for the
        source registry, indexing is best-effort)."""
        if not self._healthy or not chunks:
            return 0
        try:
            vectors = self._embedder.embed(chunks)
            if not vectors:
                return 0
            ids = [f"{source_id}:{path}:{i}" for i in range(len(chunks))]
            metadatas = [
                {"source_id": source_id, "path": path, "chunk": i}
                for i in range(len(chunks))
            ]
            self._collection.upsert(
                ids=ids, embeddings=vectors, documents=chunks, metadatas=metadatas
            )
            return len(chunks)
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("rag add_chunks failed for source %s: %s", source_id, exc)
            return 0

    def delete_source(self, source_id: int) -> None:
        if not self._healthy:
            return
        try:
            self._collection.delete(where={"source_id": source_id})
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("rag delete_source failed for %s: %s", source_id, exc)

    def query(self, text: str, n: int = 5) -> list[dict]:
        """Return up to ``n`` chunk hits, best first:
        ``{source_id, path, chunk, text, score}`` (score = 1 - cosine dist)."""
        if not self._healthy or not text.strip() or self.count() == 0:
            return []
        try:
            vectors = self._embedder.embed([text])
            if not vectors:
                return []
            res = self._collection.query(
                query_embeddings=vectors, n_results=min(n, self.count())
            )
            out = []
            for doc, meta, dist in zip(
                res["documents"][0], res["metadatas"][0], res["distances"][0]
            ):
                out.append(
                    {
                        "source_id": meta.get("source_id"),
                        "path": meta.get("path"),
                        "chunk": meta.get("chunk"),
                        "text": doc,
                        "score": round(1.0 - float(dist), 4),
                    }
                )
            return out
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("rag query failed: %s", exc)
            return []
