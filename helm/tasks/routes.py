"""Scheduled-task REST. m4: CRUD + run history. The fire/poll loop is m5."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from helm.app import db_session
from helm.tasks import models  # noqa: F401  (register tables on Base)
from helm.tasks.nl import parse_schedule
from helm.tasks.service import TaskService, run_public, task_public

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


class TaskBody(BaseModel):
    # T2 人话排期:name/schedule 全部可省——只发 {prompt} 整句(捕获坞/notch
    # 「交给 agent」契约),排期从句子里解析;显式 schedule_kind+value 照旧。
    name: str = ""
    prompt: str
    schedule_kind: str | None = None  # at | every | cron
    schedule_value: dict | None = None
    schedule_nl: str | None = None  # 人话时间单独给时优先于从 prompt 解析
    execution_mode: str = "new_conversation"
    enabled: bool = True


_NL_422 = "没听出时间——把「什么时候」放进句子,如「每天早上 9 点汇总未读邮件」"


class EnabledBody(BaseModel):
    enabled: bool


@router.get("")
def list_tasks(session: Session = Depends(db_session)) -> dict:
    return {"tasks": [task_public(t) for t in TaskService(session).list()]}


@router.post("")
def create_task(body: TaskBody, session: Session = Depends(db_session)) -> dict:
    kind, value = body.schedule_kind, body.schedule_value
    if not kind or value is None:
        parsed = parse_schedule(body.schedule_nl or body.prompt)
        if parsed is None:
            raise HTTPException(status_code=422, detail=_NL_422)
        kind, value = parsed.kind, parsed.value
    try:
        task = TaskService(session).create(
            body.name or body.prompt[:40], body.prompt, kind, value,
            execution_mode=body.execution_mode, enabled=body.enabled,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    return task_public(task)


@router.get("/parse")
def parse_preview(q: str = Query(default="")) -> dict:
    """派发条实时排期徽章(边打字边显示)——与提交用同一解析器,不双轨。"""
    p = parse_schedule(q)
    return {"parsed": None if p is None else {
        "label": p.label, "schedule_kind": p.kind, "schedule_value": p.value}}


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
