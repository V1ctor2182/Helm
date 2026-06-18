"""m1: the loopback-only binding constraint is enforced and testable.

Constraint (platform-shell): backend binds 127.0.0.1, never exposed off-box.
"""

from pathlib import Path

import pytest

from helm.config import DEFAULT_PORT, LOOPBACK_HOSTS, HelmConfig, default_data_dir


def test_default_host_is_loopback():
    cfg = HelmConfig()
    assert cfg.host == "127.0.0.1"
    assert cfg.host in LOOPBACK_HOSTS
    assert cfg.port == DEFAULT_PORT


def test_non_loopback_host_is_rejected():
    with pytest.raises(ValueError):
        HelmConfig(host="0.0.0.0")


def test_from_env_rejects_non_loopback(monkeypatch):
    monkeypatch.setenv("HELM_HOST", "0.0.0.0")
    with pytest.raises(ValueError):
        HelmConfig.from_env()


def test_from_env_reads_loopback_overrides(monkeypatch):
    monkeypatch.setenv("HELM_HOST", "::1")
    monkeypatch.setenv("HELM_PORT", "9999")
    cfg = HelmConfig.from_env()
    assert cfg.host == "::1"
    assert cfg.port == 9999


def test_localhost_hostname_is_rejected():
    # "localhost" is a hostname, not a literal loopback IP — rejected so the
    # off-box guarantee can't be weakened by resolver config.
    with pytest.raises(ValueError):
        HelmConfig(host="localhost")


def test_from_env_rejects_non_integer_port(monkeypatch):
    monkeypatch.setenv("HELM_PORT", "not-a-port")
    with pytest.raises(ValueError):
        HelmConfig.from_env()


def test_data_dir_env_override(monkeypatch, tmp_path):
    target = tmp_path / "helm-data"
    monkeypatch.setenv("HELM_DATA_DIR", str(target))
    assert default_data_dir() == target


def test_default_data_dir_is_application_support(monkeypatch):
    monkeypatch.delenv("HELM_DATA_DIR", raising=False)
    expected = Path.home() / "Library" / "Application Support" / "Helm"
    assert default_data_dir() == expected
