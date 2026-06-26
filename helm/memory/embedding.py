"""Embedder abstraction for the memory vector index.

The vector store stores *pre-computed* embeddings (ChromaDB does not embed for
us — mirrors Odysseus `src/memory_vector.py`). The concrete embedder is
fastembed's ONNX model (constraint 8ace2b3a), loaded lazily so importing this
module — and booting the app — never blocks on the model download; the first
`embed()` call pays that cost. Tests inject a deterministic fake embedder
instead, so the validation gate stays headless (no network / model download).
"""

from __future__ import annotations

from typing import Protocol

# fastembed's default small English model. Pinned here (not configurable) so the
# embedding choice is fixed — constraint 8ace2b3a: "no embedding selection risk".
DEFAULT_MODEL = "BAAI/bge-small-en-v1.5"


class Embedder(Protocol):
    """Turns text into vectors. Implementations must be deterministic per text
    and return one equal-length vector per input."""

    def embed(self, texts: list[str]) -> list[list[float]]: ...


class FastEmbedEmbedder:
    """fastembed ONNX embedder. The model is loaded on first use and cached."""

    def __init__(self, model_name: str = DEFAULT_MODEL) -> None:
        self.model_name = model_name
        self._model = None  # lazy: avoid the model download at import/boot

    def _ensure_model(self):
        if self._model is None:
            from fastembed import TextEmbedding

            self._model = TextEmbedding(model_name=self.model_name)
        return self._model

    def embed(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []
        model = self._ensure_model()
        # fastembed yields numpy arrays (already L2-normalized for bge models).
        return [vec.tolist() for vec in model.embed(texts)]
