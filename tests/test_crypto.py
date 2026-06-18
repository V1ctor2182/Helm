"""m3: Fernet secret encryption — round-trip, idempotency, key-file perms,
graceful degradation on a wrong key."""

import os
import stat

import pytest

from helm.crypto import DecryptionError, SecretBox


def test_round_trip(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    token = box.encrypt("sk-secret-123")
    assert token.startswith("enc:")
    assert "sk-secret-123" not in token
    assert box.decrypt(token) == "sk-secret-123"


def test_encrypt_is_idempotent(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    once = box.encrypt("v")
    twice = box.encrypt(once)
    assert once == twice


def test_empty_passthrough(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    assert box.encrypt("") == ""
    assert box.decrypt("") == ""


def test_plaintext_decrypt_passthrough(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    assert box.decrypt("not-encrypted") == "not-encrypted"


def test_key_file_is_0600(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    box.encrypt("x")  # triggers key creation
    mode = stat.S_IMODE(os.stat(tmp_path / ".app_key").st_mode)
    assert mode == 0o600


def test_wrong_key_raises(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    token = box.encrypt("secret")

    # New box with a different key dir — can't decrypt the old token, and it
    # must fail loudly rather than silently return "".
    other = SecretBox.from_data_dir(tmp_path / "other")
    with pytest.raises(DecryptionError):
        other.decrypt(token)


def test_is_encrypted(tmp_path):
    box = SecretBox.from_data_dir(tmp_path)
    assert SecretBox.is_encrypted(box.encrypt("a")) is True
    assert SecretBox.is_encrypted("plain") is False
    assert SecretBox.is_encrypted("") is False
