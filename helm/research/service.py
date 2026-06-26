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

    def run_research(
        self,
        question: str,
        engine: ResearchEngine,
        *,
        cancel=None,
        resume_session_id: int | None = None,
    ) -> ResearchSession:
        """Persist + run the engine, store the cited report + sources.
        ``cancel`` (a no-arg predicate) interrupts → status=stopped with the
        partial report kept. ``resume_session_id`` continues a stopped session
        from its saved summary + sources. Engine failure ⇒ status=failed."""
        from helm.research.providers import SearchResult

        seed_summary = ""
        seed_sources: list[SearchResult] | None = None
        if resume_session_id is not None:
            sess = self.get(resume_session_id)
            if sess is None:
                raise KeyError(f"research session {resume_session_id} not found")
            if sess.report_json:
                seed_summary = (json.loads(sess.report_json) or {}).get("summary", "")
            seed_sources = [
                SearchResult(url=x.url, title=x.title or "", snippet=x.snippet or "")
                for x in self.sources(sess.id)
            ]
            question = sess.question
            sess.status = "running"
        else:
            sess = ResearchSession(question=question, status="running")
            self.session.add(sess)
            self.session.flush()

        try:
            report = engine.run(
                question,
                cancel=cancel,
                resume_summary=seed_summary,
                resume_sources=seed_sources,
            )
            existing = {x.url for x in self.sources(sess.id)}
            for s in report.sources:
                if s["url"] not in existing:
                    self.session.add(
                        ResearchSource(
                            session_id=sess.id,
                            url=s["url"],
                            title=s.get("title"),
                            snippet=s.get("snippet"),
                        )
                    )
            sess.report_json = json.dumps(report.to_dict(), ensure_ascii=False)
            sess.rounds_done = (sess.rounds_done or 0) + report.rounds
            sess.status = "stopped" if (cancel is not None and cancel()) else "completed"
        except Exception as exc:  # noqa: BLE001 - engine/provider failure is recorded
            sess.status = "failed"
            sess.error = str(exc)
        sess.ended_at = datetime.now(timezone.utc)
        self.session.flush()
        return sess
