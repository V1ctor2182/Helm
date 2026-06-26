"""Background scheduler: poll for due tasks and fire them via an executor.

``tick`` is the unit (find due → execute → record_run), testable with a fake
executor. The live loop (``run_loop``) is opt-in via HELM_SCHEDULER=1 and uses
the real AgentTaskExecutor (paid) — off by default so neither tests nor a plain
dev boot fire agents. Each due task is fired in its own session so one failure
doesn't roll back the others.
"""

from __future__ import annotations

import asyncio
import logging
import os

from helm.tasks.executor import AgentTaskExecutor, TaskExecutor
from helm.tasks.service import TaskService

logger = logging.getLogger(__name__)


async def tick(db, executor: TaskExecutor) -> int:
    """Fire every currently-due task once. Returns how many fired."""
    with db.session_scope() as session:
        due = [(t.id, t.prompt) for t in TaskService(session).due()]

    for task_id, prompt in due:
        try:
            status, output = await executor.execute(prompt)
        except Exception as exc:  # noqa: BLE001 - record, don't crash the loop
            status, output = "error", str(exc)
        with db.session_scope() as session:
            svc = TaskService(session)
            task = svc.get(task_id)
            if task is not None:
                svc.record_run(task, status, output)
    return len(due)


async def run_loop(db, executor: TaskExecutor, interval: float = 30.0) -> None:
    while True:
        await asyncio.sleep(interval)
        try:
            await tick(db, executor)
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("scheduler tick failed: %s", exc)


def maybe_start(app) -> None:
    """Register the scheduler on app startup when HELM_SCHEDULER=1 (opt-in, so
    the loop/tests never fire real agents)."""
    if os.getenv("HELM_SCHEDULER", "0") != "1":
        return

    @app.on_event("startup")
    async def _start() -> None:  # pragma: no cover - live wiring
        app.state.scheduler_task = asyncio.create_task(
            run_loop(app.state.db, AgentTaskExecutor())
        )
