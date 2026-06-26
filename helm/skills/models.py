"""Skills ORM: only the mutable per-skill state (enabled flag + usage counter).
Skill metadata lives on disk in SKILL.md and is never persisted here, so the
registry can't drift from the files."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from helm.db import Base


class SkillState(Base):
    """Helm-side state for a skill, keyed by skill name. A row only exists once
    a skill has been toggled or used; absent row ⇒ defaults (enabled, 0 uses)."""

    __tablename__ = "skill_states"

    name: Mapped[str] = mapped_column(String(200), primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    uses: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_used: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"SkillState(name={self.name!r}, enabled={self.enabled!r})"
