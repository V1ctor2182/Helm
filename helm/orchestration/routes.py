"""Agent orchestration REST. m1: Claude Code MCP config injection."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    WebSocket,
    WebSocketDisconnect,
)
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.orchestration import mcp_config
from helm.orchestration import models  # noqa: F401  (register agent_runs on Base)
from helm.orchestration.acp import RunStatus
from helm.orchestration.adapters import available_adapters, get_adapter
from helm.orchestration.runs import AgentRunService, run_public
from helm.orchestration.session import iter_process_lines

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


@router.websocket("/runs/ws")
async def run_ws(ws: WebSocket) -> None:
    """Run an agent and stream its ACP events to the cockpit.

    client → {agent, prompt, cwd?, project_path?, session_id?}
    server → {type:'run_started', run_id} · <acp event dicts> · {type:'done'|'error'}

    The structured lane (this) coexists with the raw-pty terminal (fallback).
    A session is committed per output line so the /runs API reflects live status.
    """
    await ws.accept()
    db = ws.app.state.db
    try:
        start = await ws.receive_json()
    except (WebSocketDisconnect, RuntimeError, ValueError):
        return

    agent = start.get("agent", "claude-code")
    prompt = start.get("prompt", "")
    cwd = start.get("cwd") or None
    try:
        adapter = get_adapter(agent)
    except KeyError as exc:
        await ws.send_json({"type": "error", "error": str(exc)})
        await ws.close()
        return

    with db.session_scope() as s:
        run_id = AgentRunService(s).create(
            agent, prompt, start.get("project_path"), start.get("session_id")
        ).id
    await ws.send_json({"type": "run_started", "run_id": run_id})

    argv = adapter.command(prompt, cwd)
    try:
        async for line in iter_process_lines(argv, cwd):
            with db.session_scope() as s:
                svc = AgentRunService(s)
                run = svc.get(run_id)
                for event in svc.consume_line(run, line):
                    await ws.send_json(event.to_dict())
    except FileNotFoundError:
        with db.session_scope() as s:
            svc = AgentRunService(s)
            svc.fail(svc.get(run_id), f"agent not found: {argv[0]}")
        await ws.send_json({"type": "error", "error": f"agent not found: {argv[0]}"})
        await ws.close()
        return
    except WebSocketDisconnect:
        return

    # Process exited without a terminal ACP event → close the run out.
    with db.session_scope() as s:
        svc = AgentRunService(s)
        run = svc.get(run_id)
        if run.status in (RunStatus.PENDING.value, RunStatus.RUNNING.value):
            run.status = RunStatus.COMPLETED.value
            run.ended_at = datetime.now(timezone.utc)
            s.flush()
    await ws.send_json({"type": "done", "run_id": run_id})
    await ws.close()
