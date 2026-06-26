"""Agent orchestration REST. m1: Claude Code MCP config injection."""

from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.orchestration import mcp_config
from helm.orchestration import models  # noqa: F401  (register agent_runs on Base)
from helm.orchestration.adapters import available_adapters
from helm.orchestration.runs import AgentRunService, run_public

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


@router.get("/agents")
def list_agents() -> dict:
    """Available agent backends (MVP: claude-code)."""
    return {"agents": available_adapters()}


@router.get("/runs")
def list_runs(session: Session = Depends(db_session)) -> dict:
    return {"runs": [run_public(r) for r in AgentRunService(session).list()]}


@router.get("/runs/{run_id}")
def get_run(run_id: int, session: Session = Depends(db_session)) -> dict:
    run = AgentRunService(session).get(run_id)
    if run is None:
        raise HTTPException(status_code=404, detail="run not found")
    return run_public(run)
