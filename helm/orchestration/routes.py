"""Agent orchestration REST. m1: Claude Code MCP config injection."""

from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from helm.orchestration import mcp_config

router = APIRouter(prefix="/api/orchestration", tags=["orchestration"])


class InjectBody(BaseModel):
    # Target Claude Code MCP config; defaults to the current project's .mcp.json.
    config_path: str | None = None
    enabled: bool = True


def _path(config_path: str | None) -> Path:
    return Path(config_path) if config_path else mcp_config.default_config_path()


@router.get("/mcp")
def mcp_status(config_path: str | None = None) -> dict:
    return mcp_config.status(_path(config_path))


@router.post("/mcp")
def mcp_inject(body: InjectBody) -> dict:
    try:
        return mcp_config.inject(_path(body.config_path), enabled=body.enabled)
    except ValueError as exc:
        # malformed existing config — refuse rather than clobber it
        raise HTTPException(status_code=400, detail=str(exc))
