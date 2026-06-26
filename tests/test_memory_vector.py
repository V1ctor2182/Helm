"""m2 (memory): ChromaDB vector index + hybrid recall.

The vector path is tested with a deterministic FakeEmbedder over real ChromaDB
(local, no network). One opt-in integration test exercises the real fastembed
model — gated on HELM_TEST_EMBED=1 so the default gate never downloads a model.
"""

import math
import os

import pytest

from helm.db import Database
from helm.memory.service import MemoryService
from helm.memory.vector import MemoryVectorStore


class FakeEmbedder:
    """Maps a handful of words to concept dimensions so semantically-related
    texts get close vectors even with zero token overlap (e.g. car↔automobile).
    Deterministic, no model download."""

    VOCAB = {
        "car": 0, "automobile": 0, "vehicle": 0, "drive": 0, "driving": 0,
        "cat": 1, "feline": 1, "kitten": 1, "cats": 1,
        "dog": 2, "puppy": 2, "canine": 2, "dogs": 2,
    }
    DIM = 3

    def embed(self, texts: list[str]) -> list[list[float]]:
        out = []
        for t in texts:
            v = [0.0] * self.DIM
            for tok in t.lower().replace(".", " ").replace(",", " ").split():
                if tok in self.VOCAB:
                    v[self.VOCAB[tok]] += 1.0
            norm = math.sqrt(sum(x * x for x in v))
            if norm == 0.0:  # unmatched text → tiny uniform vector
                v = [1e-6] * self.DIM
                norm = math.sqrt(sum(x * x for x in v))
            out.append([x / norm for x in v])
        return out


def _session(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_vector_store_roundtrip(config):
    store = MemoryVectorStore(config.data_dir, FakeEmbedder())
    assert store.healthy is True
    assert store.count() == 0

    store.upsert(1, "I drive a car")
    store.upsert(2, "the cat sleeps")
    assert store.count() == 2

    hits = store.query("automobile", n=5)  # vehicle concept
    assert hits[0][0] == 1  # the car memory ranks first
    assert hits[0][1] > hits[1][1]  # higher similarity than the cat memory

    store.delete(1)
    assert store.count() == 1
    assert all(mid != 1 for mid, _ in store.query("automobile", n=5))


def test_hybrid_search_surfaces_semantic_match(config):
    """A vector neighbour with zero shared tokens should still surface."""
    from helm.memory.service import keyword_similarity

    db = _session(config)
    store = MemoryVectorStore(config.data_dir, FakeEmbedder())
    with db.session_scope() as s:
        svc = MemoryService(s, store)
        svc.create(text="I drive a car")
        svc.create(text="the cat sleeps on the mat")
        svc.create(text="a loyal dog")

    with db.session_scope() as s:
        results = MemoryService(s, store).search("automobile", limit=5)

    assert results, "hybrid search returned nothing"
    top_text = results[0][0].text
    assert "car" in top_text
    # keyword alone would have scored this 0 (no shared token with 'automobile')
    assert keyword_similarity("automobile", top_text) == 0.0


def test_search_degrades_to_keyword_when_unhealthy(config):
    db = _session(config)
    store = MemoryVectorStore(config.data_dir, FakeEmbedder())
    with db.session_scope() as s:
        MemoryService(s, store).create(text="the cat sat on the mat")

    # Simulate the vector backend going down: search must still work via keyword.
    store._healthy = False
    with db.session_scope() as s:
        results = MemoryService(s, store).search("cat", limit=5)
    assert results
    assert "cat" in results[0][0].text
    # 'automobile' has no keyword match and no (healthy) vector path → empty
    with db.session_scope() as s:
        assert MemoryService(s, store).search("automobile", limit=5) == []


def test_update_reindexes_and_delete_removes(config):
    db = _session(config)
    store = MemoryVectorStore(config.data_dir, FakeEmbedder())
    with db.session_scope() as s:
        mid = MemoryService(s, store).create(text="I drive a car").id

    # Re-point the memory at a different concept; the index must follow.
    with db.session_scope() as s:
        MemoryService(s, store).update(mid, text="a fluffy cat")
    with db.session_scope() as s:
        results = MemoryService(s, store).search("feline", limit=5)
    assert results and results[0][0].id == mid

    with db.session_scope() as s:
        MemoryService(s, store).delete(mid)
    assert store.count() == 0


def test_vector_store_reset(config):
    store = MemoryVectorStore(config.data_dir, FakeEmbedder())
    store.upsert(1, "I drive a car")
    store.upsert(2, "a loyal dog")
    assert store.count() == 2
    store.reset()
    assert store.count() == 0
    assert store.query("automobile", n=5) == []


@pytest.mark.skipif(
    os.getenv("HELM_TEST_EMBED") != "1",
    reason="downloads the fastembed ONNX model; set HELM_TEST_EMBED=1 to run",
)
def test_real_fastembed_roundtrip(config):
    from helm.memory.embedding import FastEmbedEmbedder

    store = MemoryVectorStore(config.data_dir, FastEmbedEmbedder())
    assert store.healthy is True
    store.upsert(1, "The cat sat on the warm windowsill.")
    store.upsert(2, "Quarterly revenue grew by twelve percent.")
    hits = dict(store.query("a feline resting in the sun", n=2))
    # the cat sentence must be the closer semantic neighbour
    assert hits[1] > hits[2]
