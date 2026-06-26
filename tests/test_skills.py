"""m7 (skills): skill discovery + health + enable/disable + usage counting."""

from pathlib import Path

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.db import Database
from helm.skills.service import SkillsService, parse_frontmatter


def _make_skill(root: Path, name: str, description: str | None = "desc") -> None:
    d = root / name
    d.mkdir(parents=True)
    fm = f"---\nname: {name}\n"
    if description is not None:
        fm += f"description: {description}\n"
    fm += "---\n\nbody\n"
    (d / "SKILL.md").write_text(fm, encoding="utf-8")


def test_parse_frontmatter():
    meta = parse_frontmatter('---\nname: foo\ndescription: "does a thing"\n---\nbody')
    assert meta == {"name": "foo", "description": "does a thing"}
    assert parse_frontmatter("no frontmatter here") == {}


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_discover_health_and_defaults(config, tmp_path):
    _make_skill(tmp_path, "alpha", "alpha skill")
    _make_skill(tmp_path, "broken", description=None)  # no description → unhealthy
    (tmp_path / "not-a-skill").mkdir()  # no SKILL.md → ignored

    db = _db(config)
    with db.session_scope() as s:
        skills = SkillsService(s, roots=[tmp_path]).discover()
    by_name = {sk["name"]: sk for sk in skills}
    assert set(by_name) == {"alpha", "broken"}
    assert by_name["alpha"]["healthy"] is True
    assert by_name["alpha"]["enabled"] is True and by_name["alpha"]["uses"] == 0
    assert by_name["broken"]["healthy"] is False
    assert "description" in by_name["broken"]["error"]


def test_enable_and_use_persist(config, tmp_path):
    _make_skill(tmp_path, "alpha", "alpha skill")
    db = _db(config)
    with db.session_scope() as s:
        svc = SkillsService(s, roots=[tmp_path])
        svc.set_enabled("alpha", False)
        svc.record_use("alpha")
        svc.record_use("alpha")
    with db.session_scope() as s:
        sk = {x["name"]: x for x in SkillsService(s, roots=[tmp_path]).discover()}["alpha"]
    assert sk["enabled"] is False
    assert sk["uses"] == 2
    assert sk["last_used"] is not None


def test_skills_routes(config, tmp_path, monkeypatch):
    _make_skill(tmp_path, "alpha", "alpha skill")
    _make_skill(tmp_path, "broken", description=None)
    monkeypatch.setenv("HELM_SKILL_DIRS", str(tmp_path))
    c = TestClient(create_app(config))

    listing = c.get("/api/skills").json()
    assert listing["total"] == 2
    assert listing["healthy"] == 1 and listing["unhealthy"] == 1

    assert c.post("/api/skills/alpha/enabled", json={"enabled": False}).json()["enabled"] is False
    used = c.post("/api/skills/alpha/used").json()
    assert used["uses"] == 1

    after = {s["name"]: s for s in c.get("/api/skills").json()["skills"]}["alpha"]
    assert after["enabled"] is False and after["uses"] == 1
