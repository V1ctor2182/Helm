"""Scheduled-task ORM (decision 894165f7): a task + its run history.

`schedule_kind` ∈ at|every|cron with `schedule_value_json` carrying the params
(at→{"at":iso}, every→{"seconds":N}, cron→{"expr":"..."}). `next_run` is the
precomputed fire time the scheduler polls. Runs land in `task_runs` so the
intent's "结果写入 task_runs" holds."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class ScheduledTask(Base):
    __tablename__ = "scheduled_tasks"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    schedule_kind: Mapped[str] = mapped_column(String(8), nullable=False)  # at|every|cron
    schedule_value_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    # how the fired agent runs: reuse one conversation, or a fresh one each time.
    execution_mode: Mapped[str] = mapped_column(
        String(20), nullable=False, default="new_conversation"
    )
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    next_run: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    last_status: Mapped[str | None] = mapped_column(String(16), nullable=True)
    run_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # if this task was spawned from a quick note (intent#1 note→task).
    linked_note_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class TaskRun(Base):
    __tablename__ = "task_runs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    task_id: Mapped[int] = mapped_column(
        ForeignKey("scheduled_tasks.id"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(String(16), nullable=False)  # ok|error|skipped
    output: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
