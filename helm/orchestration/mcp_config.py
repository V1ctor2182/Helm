"""Inject Helm's MCP server into Claude Code's MCP config — merge + backup, never
overwrite (constraint 14eb7e1e). Toggling on/off rewrites the file so it takes
effect on the agent's next session, no app restart (constraint ae70bc36).

The injected entry launches the m6 stdio server via the SAME interpreter
(``sys.executable -m helm.mcp``) so it works without relying on PATH/console
scripts. That server bridges to the loopback backend, so no new network surface
is opened (constraint 9fad19c1).
"""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

SERVER_NAME = "helm"
BACKUP_SUFFIX = ".helm-backup"


def helm_server_spec() -> dict:
    """The stdio MCP server entry Claude Code will launch."""
    return {"command": sys.executable, "args": ["-m", "helm.mcp"]}


def default_config_path() -> Path:
    """Default target: the current project's ``.mcp.json`` (cockpit works per
    project, and the terminal agent runs inside it). ``HELM_CLAUDE_MCP_CONFIG``
    overrides."""
    override = os.getenv("HELM_CLAUDE_MCP_CONFIG")
    return Path(override) if override else Path.cwd() / ".mcp.json"


def _load(path: Path) -> dict:
    """Parse the existing config. Raise (don't silently wipe) if it exists but
    isn't a JSON object — we must never clobber a config we can't merge into."""
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"existing MCP config is not valid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("existing MCP config is not a JSON object")
    return data


def status(path: Path | None = None) -> dict:
    path = path or default_config_path()
    try:
        data = _load(path)
        servers = data.get("mcpServers") or {}
        injected = SERVER_NAME in servers
        error = None
    except ValueError as exc:
        servers, injected, error = {}, False, str(exc)
    return {
        "config_path": str(path),
        "exists": path.exists(),
        "injected": injected,
        "server": servers.get(SERVER_NAME),
        "error": error,
    }


def inject(path: Path | None = None, enabled: bool = True) -> dict:
    """Add (enabled) or remove (disabled) the ``helm`` MCP server in the config,
    preserving every other entry. Backs up the original once before the first
    modification. Returns the resulting status + backup path (if made)."""
    path = path or default_config_path()
    data = _load(path)  # raises on malformed → caller surfaces 400, file untouched

    backup_path = Path(str(path) + BACKUP_SUFFIX)
    made_backup = False
    if path.exists() and not backup_path.exists():
        shutil.copy2(path, backup_path)  # preserve the pre-Helm original once
        made_backup = True

    servers = data.setdefault("mcpServers", {})
    if enabled:
        servers[SERVER_NAME] = helm_server_spec()
    else:
        servers.pop(SERVER_NAME, None)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return {
        "config_path": str(path),
        "injected": enabled,
        "server": servers.get(SERVER_NAME),
        "backup": str(backup_path) if made_backup else None,
    }
