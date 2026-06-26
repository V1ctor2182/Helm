"""Agent run lifecycle: create a run, feed it native output lines (parsed to
ACP events via the backend adapter), and advance its status. m3 drives this
from a live subprocess + streams the events over WS; here it's transport-free
so the state machine is unit-testable."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.orchestration.acp import AcpEvent, AcpEventType, RunStatus
from helm.orchestration.adapters import get_adapter
from helm.orchestration.models import AgentRun


def run_public(r: AgentRun) -> dict:
    return {
        "id": r.id,
        "session_id": r.session_id,
        "project_path": r.project_path,
        "agent": r.agent,
        "status": r.status,
        "prompt": r.prompt,
        "error": r.error,
        "started_at": r.started_at.isoformat() if r.started_at else None,
        "ended_at": r.ended_at.isoformat() if r.ended_at else None,
    }


class AgentRunService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def create(
        self,
        agent: str,
        prompt: str | None = None,
        project_path: str | None = None,
        session_id: str | None = None,
    ) -> AgentRun:
        get_adapter(agent)  # validate the backend exists (raises KeyError)
        run = AgentRun(
            agent=agent,
            prompt=prompt,
            project_path=project_path,
            session_id=session_id,
            status=RunStatus.PENDING.value,
        )
        self.session.add(run)
        self.session.flush()
        return run

    def list(self, limit: int = 50) -> list[AgentRun]:
        return list(
            self.session.scalars(
                select(AgentRun).order_by(AgentRun.started_at.desc()).limit(limit)
            )
        )

    def get(self, run_id: int) -> AgentRun | None:
        return self.session.get(AgentRun, run_id)

    def consume_line(self, run: AgentRun, raw: str) -> list[AcpEvent]:
        """Parse one native output line and advance the run's status from the
        ACP events it yields. Returns the events (for the caller to stream)."""
        events = get_adapter(run.agent).parse_line(raw)
        for event in events:
            if event.type == AcpEventType.PERMISSION_REQUEST:
                run.status = RunStatus.WAITING_PERMISSION.value
            elif event.type == AcpEventType.SESSION_END:
                run.status = (
                    RunStatus.FAILED.value
                    if event.data.get("is_error")
                    else RunStatus.COMPLETED.value
                )
                run.ended_at = datetime.now(timezone.utc)
            elif run.status == RunStatus.PENDING.value:
                # first substantive event ⇒ the run is live
                run.status = RunStatus.RUNNING.value
        self.session.flush()
        return events

    def fail(self, run: AgentRun, error: str) -> AgentRun:
        """Mark a run failed from an adapter/transport error (not an agent
        result)."""
        run.status = RunStatus.FAILED.value
        run.error = error
        run.ended_at = datetime.now(timezone.utc)
        self.session.flush()
        return run
