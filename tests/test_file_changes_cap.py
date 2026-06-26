"""B 轨 drain 5582cd77: file_changes table is capped (bounded growth)."""

from helm.cockpit.service import record_change, file_change_count
from helm.db import Database


def _db(config) -> Database:
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    return db


def test_record_change_caps_table(config):
    db = _db(config)
    cap = 50
    with db.session_scope() as s:
        # write well past the cap with a tiny cap + prune cadence via the helper
        for i in range(260):
            record_change(s, f"/f/{i}.py", "modified", cap=cap)
    with db.session_scope() as s:
        n = file_change_count(s)
        # amortized prune (every 200 inserts) keeps it within cap + one prune window
        assert n <= cap + 200
        assert n < 260  # actually pruned, not unbounded


def test_record_change_returns_row(config):
    db = _db(config)
    with db.session_scope() as s:
        c = record_change(s, "/a.py", "created")
        assert c.id >= 1 and c.path == "/a.py" and c.change_kind == "created"
