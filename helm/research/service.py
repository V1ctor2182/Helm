"""Research session persistence + engine driving. m1 exposes read (list/get)
over the API; the run path is exercised here with an injected engine (real
providers + a start route land in m2)."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.research.engine import ResearchEngine
from helm.research.models import ResearchSession, ResearchSource


def session_public(s: ResearchSession, sources: list[ResearchSource] | None = None) -> dict:
    out = {
        "id": s.id,
        "question": s.question,
        "status": s.status,
        "rounds_done": s.rounds_done,
        "report": json.loads(s.report_json) if s.report_json else None,
        "error": s.error,
        "created_at": s.created_at.isoformat() if s.created_at else None,
        "ended_at": s.ended_at.isoformat() if s.ended_at else None,
    }
    if sources is not None:
        out["sources"] = [
            {"url": x.url, "title": x.title, "snippet": x.snippet, "round": x.round}
            for x in sources
        ]
    return out


class ResearchService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list(self, limit: int = 50) -> list[ResearchSession]:
        return list(
            self.session.scalars(
                select(ResearchSession)
                .order_by(ResearchSession.created_at.desc())
                .limit(limit)
            )
        )

    def get(self, session_id: int) -> ResearchSession | None:
        return self.session.get(ResearchSession, session_id)

    def sources(self, session_id: int) -> list[ResearchSource]:
        return list(
            self.session.scalars(
                select(ResearchSource)
                .where(ResearchSource.session_id == session_id)
                .order_by(ResearchSource.round, ResearchSource.id)
            )
        )

    def run_research(self, question: str, engine: ResearchEngine) -> ResearchSession:
        """Persist a session, run the (provider-injected) engine, store the
        cited report + sources. Engine failure ⇒ status=failed (no partial
        report claimed as complete)."""
        sess = ResearchSession(question=question, status="running")
        self.session.add(sess)
        self.session.flush()
        try:
            report = engine.run(question)
            for s in report.sources:
                self.session.add(
                    ResearchSource(
                        session_id=sess.id,
                        url=s["url"],
                        title=s.get("title"),
                        snippet=s.get("snippet"),
                    )
                )
            sess.report_json = json.dumps(report.to_dict(), ensure_ascii=False)
            sess.rounds_done = report.rounds
            sess.status = "completed"
        except Exception as exc:  # noqa: BLE001 - engine/provider failure is recorded
            sess.status = "failed"
            sess.error = str(exc)
        sess.ended_at = datetime.now(timezone.utc)
        self.session.flush()
        return sess
