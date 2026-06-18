"""m2 storage foundation: engine creation, schema bootstrap, and a real
write/read round-trip through the settings table."""

from sqlalchemy import inspect, select

from helm.app import create_app
from helm.db import Database
from helm.models import Setting


def test_app_db_file_created(config):
    create_app(config)
    assert (config.data_dir / "app.db").exists()


def test_settings_table_created(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    tables = inspect(db.engine).get_table_names()
    assert "settings" in tables


def test_setting_round_trip(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()

    with db.session_scope() as session:
        session.add(Setting(key="theme", value="dark"))

    with db.session_scope() as session:
        row = session.get(Setting, "theme")
        assert row is not None
        assert row.value == "dark"
        assert row.updated_at is not None


def test_session_scope_rolls_back_on_error(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()

    class Boom(Exception):
        pass

    try:
        with db.session_scope() as session:
            session.add(Setting(key="k", value="v"))
            raise Boom
    except Boom:
        pass

    with db.session_scope() as session:
        assert session.execute(select(Setting)).first() is None


def test_wal_journal_mode_enabled(config):
    db = Database.from_data_dir(config.data_dir)
    with db.engine.connect() as conn:
        mode = conn.exec_driver_sql("PRAGMA journal_mode").scalar()
    assert mode.lower() == "wal"
