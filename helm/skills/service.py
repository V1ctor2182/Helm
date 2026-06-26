"""Skills panorama: discover skills on disk, merge in Helm-side state, expose
health + enable/disable + usage counting.

Skill discovery walks one or more roots; each immediate subdir containing a
``SKILL.md`` is a skill. Frontmatter is parsed with a tiny key:value reader
(no YAML dep — SKILL.md frontmatter is flat name/description). Health = has a
parseable name + description; a missing/blank one is surfaced as unhealthy with
a reason rather than hidden, so the panorama doubles as a lint.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from helm.skills.models import SkillState


def default_skill_roots() -> list[Path]:
    """Where to look for skills. ``HELM_SKILL_DIRS`` (os.pathsep-separated)
    overrides; otherwise the user + project Claude skill dirs."""
    env = os.getenv("HELM_SKILL_DIRS")
    if env:
        return [Path(p).expanduser() for p in env.split(os.pathsep) if p.strip()]
    return [Path.home() / ".claude" / "skills", Path.cwd() / ".claude" / "skills"]


def parse_frontmatter(text: str) -> dict[str, str]:
    """Extract flat key:value pairs from a leading ``---`` fenced block."""
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    meta: dict[str, str] = {}
    for line in text[3:end].splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip().strip("\"'")
    return meta


class SkillsService:
    def __init__(self, session: Session, roots: list[Path] | None = None) -> None:
        self.session = session
        self.roots = roots if roots is not None else default_skill_roots()

    def _state(self, name: str) -> SkillState | None:
        return self.session.get(SkillState, name)

    def discover(self) -> list[dict]:
        """All skills found on disk, merged with Helm state, sorted by name.
        Duplicate names across roots: first root wins."""
        seen: dict[str, dict] = {}
        for root in self.roots:
            if not root.is_dir():
                continue
            for child in sorted(root.iterdir()):
                if not child.is_dir():
                    continue
                skill_md = child / "SKILL.md"
                if not skill_md.is_file():
                    continue
                meta_name, info = self._read_skill(child, skill_md)
                if meta_name in seen:
                    continue
                seen[meta_name] = info
        return [seen[k] for k in sorted(seen)]

    def _read_skill(self, folder: Path, skill_md: Path) -> tuple[str, dict]:
        error = None
        try:
            meta = parse_frontmatter(skill_md.read_text(encoding="utf-8", errors="replace"))
        except OSError as exc:  # pragma: no cover - unreadable file
            meta = {}
            error = f"unreadable SKILL.md: {exc}"
        name = meta.get("name") or folder.name
        description = meta.get("description", "")
        if error is None and not description:
            error = "missing description in SKILL.md frontmatter"
        state = self._state(name)
        return name, {
            "name": name,
            "description": description,
            "path": str(folder),
            "healthy": error is None,
            "error": error,
            "enabled": state.enabled if state else True,
            "uses": state.uses if state else 0,
            "last_used": state.last_used.isoformat() if state and state.last_used else None,
        }

    def _ensure_state(self, name: str) -> SkillState:
        state = self._state(name)
        if state is None:
            state = SkillState(name=name)
            self.session.add(state)
            self.session.flush()
        return state

    def set_enabled(self, name: str, enabled: bool) -> dict:
        state = self._ensure_state(name)
        state.enabled = enabled
        self.session.flush()
        return {"name": name, "enabled": state.enabled}

    def record_use(self, name: str) -> dict:
        state = self._ensure_state(name)
        state.uses += 1
        state.last_used = datetime.now(timezone.utc)
        self.session.flush()
        return {
            "name": name,
            "uses": state.uses,
            "last_used": state.last_used.isoformat(),
        }
