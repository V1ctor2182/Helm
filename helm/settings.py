"""Settings and secrets services — typed access over the storage tables.

``SettingsService`` is plain key-value config (theme, data prefs, ...).
``SecretStore`` is the encrypted-at-rest store for credentials: it encrypts on
write and only ever persists ciphertext, so the ``secrets`` table can never
hold a plaintext key.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.crypto import SecretBox
from helm.models import Secret, Setting


class SettingsService:
    """Plaintext application settings, backed by the ``settings`` table."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get(self, key: str, default: str | None = None) -> str | None:
        row = self._session.get(Setting, key)
        return row.value if row is not None else default

    def set(self, key: str, value: str) -> None:
        row = self._session.get(Setting, key)
        if row is None:
            self._session.add(Setting(key=key, value=value))
        else:
            row.value = value

    def all(self) -> dict[str, str]:
        rows = self._session.execute(select(Setting)).scalars().all()
        return {row.key: row.value for row in rows}

    def delete(self, key: str) -> bool:
        row = self._session.get(Setting, key)
        if row is None:
            return False
        self._session.delete(row)
        return True


class SecretStore:
    """Encrypted credential store. Plaintext goes in via :meth:`set`, ciphertext
    is what lives in the DB, and :meth:`get` is the only way back to plaintext —
    deliberately not exposed over the network (see routes)."""

    def __init__(self, session: Session, box: SecretBox) -> None:
        self._session = session
        self._box = box

    def set(self, key: str, plaintext: str) -> None:
        ciphertext = self._box.encrypt(plaintext)
        row = self._session.get(Secret, key)
        if row is None:
            self._session.add(Secret(key=key, value=ciphertext))
        else:
            row.value = ciphertext

    def get(self, key: str) -> str | None:
        row = self._session.get(Secret, key)
        return self._box.decrypt(row.value) if row is not None else None

    def keys(self) -> list[str]:
        rows = self._session.execute(select(Secret.key)).scalars().all()
        return sorted(rows)

    def delete(self, key: str) -> bool:
        row = self._session.get(Secret, key)
        if row is None:
            return False
        self._session.delete(row)
        return True
