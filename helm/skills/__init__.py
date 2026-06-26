"""Skills room: a panorama over the machine's agent skills (memory-rag-skills
intent#4) — list installed Claude Code skills, their health, enable/disable
state, and usage counts.

Skill *metadata* (name/description) is read fresh from disk each request
(``<root>/<name>/SKILL.md`` frontmatter); only *mutable* state — enabled flag +
usage counter — is persisted in SQLite, so editing a SKILL.md never needs a
Helm-side sync and the registry never goes stale (pattern from Odysseus
services/memory/skills.py: counters in a sidecar, not in the SKILL.md).
"""
