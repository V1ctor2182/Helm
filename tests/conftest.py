"""Shared fixtures: keep every test hermetic by pinning the data dir to a tmp
path, so booting the app never touches the real ~/Library/Application Support."""

from pathlib import Path

import pytest

from helm.config import HelmConfig


@pytest.fixture(autouse=True)
def _disable_memory_vectors(monkeypatch) -> None:
    # Keep the gate headless: app-level tests run memory recall keyword-only so
    # create_app never spins up fastembed (which would download an ONNX model).
    # The vector path is covered directly in test_memory_vector.py with a fake
    # embedder (real ChromaDB, no network).
    monkeypatch.setenv("HELM_MEMORY_VECTORS", "0")


@pytest.fixture
def config(tmp_path: Path) -> HelmConfig:
    return HelmConfig(data_dir=tmp_path / "helm-data")


@pytest.fixture
def anyio_backend() -> str:
    # Run @pytest.mark.anyio tests on asyncio only (trio isn't installed).
    return "asyncio"
