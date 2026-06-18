"""Shared fixtures: keep every test hermetic by pinning the data dir to a tmp
path, so booting the app never touches the real ~/Library/Application Support."""

from pathlib import Path

import pytest

from helm.config import HelmConfig


@pytest.fixture
def config(tmp_path: Path) -> HelmConfig:
    return HelmConfig(data_dir=tmp_path / "helm-data")
