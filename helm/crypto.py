"""Fernet symmetric encryption for secrets at rest.

Ported from Odysseus's ``secret_storage`` (recorded decision: reuse the
file-based Fernet approach as the base; layering the macOS Keychain is a
deferred enhancement). The key lives at ``<data_dir>/.app_key``, mode 0o600,
generated on first use; the data dir is gitignored so the key never ships.

Threat model: protects against DB-file exfiltration (stolen backup, leaked
copy). Does NOT protect against process compromise — anyone who can read this
process's memory or the key file gets plaintext.

Encrypted values carry an ``enc:`` prefix so encryption is idempotent
(re-encrypting a ciphertext is a no-op) and plaintext/ciphertext can coexist
during a migration (decrypting a plaintext value returns it unchanged).
"""

from __future__ import annotations

import logging
import os
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger(__name__)

_PREFIX = "enc:"


class DecryptionError(Exception):
    """A stored ciphertext could not be decrypted — wrong/rotated key or a
    corrupt token. Raised loudly (rather than silently returning "") so a lost
    ``.app_key`` surfaces instead of every secret reading back as unconfigured,
    which would invite a user to overwrite still-recoverable credentials."""


class SecretBox:
    """Encrypt/decrypt strings with a Fernet key backed by a key file."""

    def __init__(self, key_path: Path) -> None:
        self._key_path = Path(key_path)
        self._fernet: Fernet | None = None

    @classmethod
    def from_data_dir(cls, data_dir: Path) -> "SecretBox":
        return cls(Path(data_dir) / ".app_key")

    def _load_or_create_key(self) -> bytes:
        if self._key_path.exists():
            return self._key_path.read_bytes()
        self._key_path.parent.mkdir(parents=True, exist_ok=True)
        key = Fernet.generate_key()
        # Create with 0o600 atomically (O_CREAT|O_EXCL) so the key is never
        # briefly world-readable and two racing processes can't both write it.
        try:
            fd = os.open(self._key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            # Lost the race; another process just created it.
            return self._key_path.read_bytes()
        with os.fdopen(fd, "wb") as fh:  # buffered write handles short writes
            fh.write(key)
        logger.info("Generated new app key at %s", self._key_path)
        return key

    def _get_fernet(self) -> Fernet:
        if self._fernet is None:
            self._fernet = Fernet(self._load_or_create_key())
        return self._fernet

    def encrypt(self, plaintext: str) -> str:
        """Encrypt a string. Empty input and already-encrypted values pass
        through unchanged (idempotent)."""
        if not plaintext:
            return plaintext or ""
        if plaintext.startswith(_PREFIX):
            return plaintext
        token = self._get_fernet().encrypt(plaintext.encode("utf-8")).decode("ascii")
        return _PREFIX + token

    def decrypt(self, value: str) -> str:
        """Decrypt an ``enc:``-prefixed value. Empty input and plaintext (no
        prefix) pass through unchanged. Raises :class:`DecryptionError` on a
        wrong/rotated key or corrupt token — callers decide whether to surface
        or degrade, but the failure is never silently swallowed here."""
        if not value:
            return value or ""
        if not value.startswith(_PREFIX):
            return value
        try:
            return (
                self._get_fernet()
                .decrypt(value[len(_PREFIX) :].encode("ascii"))
                .decode("utf-8")
            )
        except InvalidToken as exc:
            logger.error("Failed to decrypt secret — wrong key or corrupt token")
            raise DecryptionError(
                "could not decrypt stored secret (wrong key or corrupt token)"
            ) from exc

    @staticmethod
    def is_encrypted(value: str) -> bool:
        return bool(value) and value.startswith(_PREFIX)
