"""Scheduled-task service: CRUD, due-task lookup, and run recording. The
executor that actually fires the agent (paid) + the background poll loop are m5;
``record_run`` here is what that executor calls to log a run and advance the
schedule — driven directly in tests, no agent needed."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.tasks.models import ScheduledTask, TaskRun
from helm.tasks.schedule import KINDS, compute_next_run


def _now() -> datetime:
    return datetime.now(timezone.utc)


def task_public(t: ScheduledTask) -> dict:
    return {
        "id": t.id,
        "name": t.name,
        "prompt": t.prompt,
        "schedule_kind": t.schedule_kind,
        "schedule_value": json.loads(t.schedule_value_json or "{}"),
        "execution_mode": t.execution_mode,
        "enabled": t.enabled,
        "next_run": t.next_run.isoformat() if t.next_run else None,
        "last_status": t.last_status,
        "run_count": t.run_count,
        "linked_note_id": t.linked_note_id,
        "created_at": t.created_at.isoformat() if t.created_at else None,
    }


def run_public(r: TaskRun) -> dict:
    return {
        "id": r.id,
        "task_id": r.task_id,
        "status": r.status,
        "output": r.output,
        "started_at": r.started_at.isoformat() if r.started_at else None,
        "ended_at": r.ended_at.isoformat() if r.ended_at else None,
    }


class TaskService:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list(self) -> list[ScheduledTask]:
        return list(
            self.session.scalars(
                select(ScheduledTask).order_by(ScheduledTask.created_at.desc())
            )
        )

    def get(self, task_id: int) -> ScheduledTask | None:
        return self.session.get(ScheduledTask, task_id)

    def runs(self, task_id: int) -> list[TaskRun]:
        return list(
            self.session.scalars(
                select(TaskRun)
                .where(TaskRun.task_id == task_id)
                .order_by(TaskRun.started_at.desc())
            )
        )

    def create(
        self,
        name: str,
        prompt: str,
        schedule_kind: str,
        schedule_value: dict,
        *,
        execution_mode: str = "new_conversation",
        enabled: bool = True,
        linked_note_id: int | None = None,
    ) -> ScheduledTask:
        if schedule_kind not in KINDS:
            raise ValueError(f"schedule_kind must be one of {KINDS}")
        task = ScheduledTask(
            name=name,
            prompt=prompt,
            schedule_kind=schedule_kind,
            schedule_value_json=json.dumps(schedule_value, ensure_ascii=False),
            execution_mode=execution_mode,
            enabled=enabled,
            linked_note_id=linked_note_id,
            next_run=compute_next_run(schedule_kind, schedule_value, _now()),
        )
        self.session.add(task)
        self.session.flush()
        return task

    def set_enabled(self, task_id: int, enabled: bool) -> ScheduledTask | None:
        task = self.get(task_id)
        if task is None:
            return None
        task.enabled = enabled
        # re-arm next_run when re-enabling a recurring task
        if enabled and task.next_run is None:
            task.next_run = compute_next_run(
                task.schedule_kind, json.loads(task.schedule_value_json), _now()
            )
        self.session.flush()
        return task

    def delete(self, task_id: int) -> bool:
        task = self.get(task_id)
        if task is None:
            return False
        for r in self.runs(task_id):
            self.session.delete(r)
        self.session.delete(task)
        return True

    def due(self, now: datetime | None = None) -> list[ScheduledTask]:
        """Enabled tasks whose next_run has passed — the scheduler fires these."""
        now = now or _now()
        return list(
            self.session.scalars(
                select(ScheduledTask).where(
                    ScheduledTask.enabled.is_(True),
                    ScheduledTask.next_run.is_not(None),
                    ScheduledTask.next_run <= now,
                )
            )
        )

    def record_run(
        self, task: ScheduledTask, status: str, output: str | None = None
    ) -> TaskRun:
        """Log a run (intent#3: 结果写入 task_runs) and advance the schedule.
        The m5 executor calls this with the agent's result; a one-shot 'at' task
        disarms (next_run=None) after firing."""
        now = _now()
        run = TaskRun(task_id=task.id, status=status, output=output, ended_at=now)
        self.session.add(run)
        task.last_status = status
        task.run_count += 1
        # 'at' is one-shot: once it has fired it never re-arms (even if its
        # scheduled instant is still in the future, e.g. a manual run). every/
        # cron recompute the next occurrence.
        task.next_run = (
            None
            if task.schedule_kind == "at"
            else compute_next_run(
                task.schedule_kind, json.loads(task.schedule_value_json), now
            )
        )
        self.session.flush()
        return run
