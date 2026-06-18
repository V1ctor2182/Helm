"""Local storage foundation: SQLite engine + SQLAlchemy session factory.

m2 (platform-shell): the storage plumbing every feature room builds on. This
module owns engine creation, the declarative ``Base``, and a session factory;
it deliberately defines no feature business tables — those (sessions, memories,
research, projects, terminal_sessions, ...) live in their own rooms and are
single-way-door schema decisions deferred to them. Only the generic
key-value ``settings`` table ships here (see :mod:`helm.models`).
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
    """Declarative base for all Helm ORM models."""


def _enable_sqlite_pragmas(engine: Engine) -> None:
    @event.listens_for(engine, "connect")
    def _set_pragmas(dbapi_conn, _record):  # noqa: ANN001
        cur = dbapi_conn.cursor()
        # WAL: concurrent readers while the backend writes (the brain and
        # cockpit hit the DB from different tasks). foreign_keys: SQLite
        # leaves FK enforcement off by default; turn it on so relations
        # added by later rooms actually hold.
        cur.execute("PRAGMA journal_mode=WAL")
        cur.execute("PRAGMA foreign_keys=ON")
        cur.close()


def make_engine(data_dir: Path) -> Engine:
    """Create the SQLite engine at ``<data_dir>/app.db``, creating the dir."""
    data_dir.mkdir(parents=True, exist_ok=True)
    db_path = data_dir / "app.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        # The app is single-process but multi-task (async); allow the
        # connection to cross threads. Concurrency is still serialized by
        # SQLite's own locking + WAL.
        connect_args={"check_same_thread": False},
        future=True,
    )
    _enable_sqlite_pragmas(engine)
    return engine


class Database:
    """Owns the engine + session factory; lives on ``app.state.db``."""

    def __init__(self, engine: Engine) -> None:
        self.engine = engine
        self._session_factory = sessionmaker(
            bind=engine, expire_on_commit=False, future=True
        )

    @classmethod
    def from_data_dir(cls, data_dir: Path) -> "Database":
        return cls(make_engine(data_dir))

    def create_all(self) -> None:
        """Create any not-yet-existing tables.

        Imports :mod:`helm.models` first so models register on
        ``Base.metadata`` before ``create_all`` runs. ``create_all`` is the
        bootstrap path for the fresh local DB; a real migration tool (Alembic)
        is deferred until a schema actually needs to evolve.
        """
        from helm import models  # noqa: F401  (registers tables on Base)

        Base.metadata.create_all(self.engine)

    def session(self) -> Session:
        return self._session_factory()

    @contextmanager
    def session_scope(self) -> Iterator[Session]:
        """Transactional session: commit on success, roll back on error."""
        session = self.session()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()
