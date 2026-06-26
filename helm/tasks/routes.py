"""Scheduled-task REST. m4: CRUD + run history. The fire/poll loop is m5."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.tasks import models  # noqa: F401  (register tables on Base)
from helm.tasks.service import TaskService, run_public, task_public

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


class TaskBody(BaseModel):
    name: str
    prompt: str
    schedule_kind: str  # at | every | cron
    schedule_value: dict
    execution_mode: str = "new_conversation"
    enabled: bool = True


class EnabledBody(BaseModel):
    enabled: bool


@router.get("")
def list_tasks(session: Session = Depends(db_session)) -> dict:
    return {"tasks": [task_public(t) for t in TaskService(session).list()]}


@router.post("")
def create_task(body: TaskBody, session: Session = Depends(db_session)) -> dict:
    try:
        task = TaskService(session).create(
            body.name, body.prompt, body.schedule_kind, body.schedule_value,
            execution_mode=body.execution_mode, enabled=body.enabled,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    return task_public(task)


@router.get("/{task_id}/runs")
def task_runs(task_id: int, session: Session = Depends(db_session)) -> dict:
    svc = TaskService(session)
    if svc.get(task_id) is None:
        raise HTTPException(status_code=404, detail="task not found")
    return {"runs": [run_public(r) for r in svc.runs(task_id)]}


@router.post("/{task_id}/enabled")
def set_enabled(
    task_id: int, body: EnabledBody, session: Session = Depends(db_session)
) -> dict:
    task = TaskService(session).set_enabled(task_id, body.enabled)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    return task_public(task)


@router.delete("/{task_id}")
def delete_task(task_id: int, session: Session = Depends(db_session)) -> dict:
    if not TaskService(session).delete(task_id):
        raise HTTPException(status_code=404, detail="task not found")
    return {"deleted": task_id}
