"""Helm runtime configuration — single source of truth for host/port/data dir.

Mirrors Odysseus's constants pattern (exactly one place reads each env var) but
scoped to the platform-shell foundation. Feature rooms extend this; they must
not re-derive paths from ``__file__`` or hardcode the bind host.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

# Hosts treated as loopback. Constraint (platform-shell): the backend binds
# 127.0.0.1 and is never exposed off-box — no multi-user, no LAN, no cloud.
# Only literal loopback IPs are allowed: "localhost" is a hostname resolved by
# the OS (/etc/hosts, DNS) and could point off-box, so accepting it would give a
# false sense of safety.
LOOPBACK_HOSTS = frozenset({"127.0.0.1", "::1"})

DEFAULT_HOST = "127.0.0.1"
# Off the common 8000/8080 to avoid clashing with other local dev servers;
# override with HELM_PORT.
DEFAULT_PORT = 8769


def default_data_dir() -> Path:
    """Helm's data directory, overridable via ``HELM_DATA_DIR``.

    First version targets macOS only (constraint: Apple Silicon, no Win/Linux),
    so ``~/Library/Application Support/Helm`` is the right home. The env override
    keeps tests and packaging hermetic.
    """
    override = os.getenv("HELM_DATA_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Library" / "Application Support" / "Helm"


@dataclass(frozen=True)
class HelmConfig:
    """Resolved runtime config. Construct via :meth:`from_env` in real runs;
    the bare constructor (loopback defaults) is convenient for tests."""

    host: str = DEFAULT_HOST
    port: int = DEFAULT_PORT
    data_dir: Path = field(default_factory=default_data_dir)

    def __post_init__(self) -> None:
        if self.host not in LOOPBACK_HOSTS:
            raise ValueError(
                f"host={self.host!r} is not a loopback address; Helm only binds "
                f"{sorted(LOOPBACK_HOSTS)} (local-first, never exposed off-box)."
            )

    @classmethod
    def from_env(cls) -> "HelmConfig":
        raw_port = os.getenv("HELM_PORT", str(DEFAULT_PORT))
        try:
            port = int(raw_port)
        except ValueError as exc:
            raise ValueError(f"HELM_PORT={raw_port!r} is not an integer") from exc
        return cls(
            host=os.getenv("HELM_HOST", DEFAULT_HOST),
            port=port,
            data_dir=default_data_dir(),
        )
