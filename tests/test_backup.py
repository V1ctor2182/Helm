"""m7: data export/import — archive shape, service round-trip, REST round-trip,
and the key-stays-home secret semantics."""

import io
import json
import zipfile

import pytest
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.backup import export_archive, import_archive
from helm.config import HelmConfig
from helm.crypto import DecryptionError, SecretBox
from helm.db import Database
from helm.models import Secret, Setting


def test_export_archive_shape(config, tmp_path):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    dest = tmp_path / "b.zip"
    export_archive(db, dest)

    with zipfile.ZipFile(dest) as zf:
        names = set(zf.namelist())
        assert {"manifest.json", "app.db"} <= names
        manifest = json.loads(zf.read("manifest.json"))
        assert manifest["format"] == "helm-backup"
        assert manifest["format_version"] == 1


def test_service_round_trip_restores_settings_and_secret_ciphertext(config, tmp_path):
    # source db with a setting + an (encrypted) secret
    src = Database.from_data_dir(config.data_dir)
    src.create_all()
    box = SecretBox.from_data_dir(config.data_dir)
    with src.session_scope() as s:
        s.add(Setting(key="theme", value="dark"))
        s.add(Secret(key="openai", value=box.encrypt("sk-secret")))

    archive = tmp_path / "b.zip"
    export_archive(src, archive)

    # restore into a fresh db in a different dir (→ different .app_key)
    dst = Database.from_data_dir(tmp_path / "dst")
    dst.create_all()
    counts = import_archive(dst, archive)
    assert counts == {"settings": 1, "secrets": 1}

    with dst.session_scope() as s:
        assert s.get(Setting, "theme").value == "dark"
        cipher = s.get(Secret, "openai").value
    assert cipher.startswith("enc:")
    # decryptable with the ORIGINAL key, not the destination's new key
    assert box.decrypt(cipher) == "sk-secret"
    with pytest.raises(DecryptionError):
        SecretBox.from_data_dir(tmp_path / "dst").decrypt(cipher)


def test_rest_export_import_round_trip(config, tmp_path):
    a = TestClient(create_app(config))
    a.put("/api/settings/theme", json={"value": "dark"})
    blob = a.get("/api/data/export").content

    with zipfile.ZipFile(io.BytesIO(blob)) as zf:
        assert "app.db" in zf.namelist()

    # fresh app, import the archive, setting comes back
    b_cfg = HelmConfig(data_dir=tmp_path / "appB")
    b = TestClient(create_app(b_cfg))
    assert b.get("/api/settings/theme").status_code == 404
    resp = b.post(
        "/api/data/import",
        files={"file": ("helm-backup.zip", blob, "application/zip")},
    )
    assert resp.status_code == 200
    assert resp.json()["imported"]["settings"] >= 1
    assert b.get("/api/settings/theme").json()["value"] == "dark"


def test_import_rejects_valid_zip_missing_tables(config, tmp_path):
    # A structurally-valid backup whose app.db lacks the expected tables must
    # be a clean 400, not a 500.
    import sqlite3

    empty_db = tmp_path / "empty.db"
    sqlite3.connect(empty_db).close()
    bad = tmp_path / "bad.zip"
    with zipfile.ZipFile(bad, "w") as zf:
        zf.writestr("manifest.json", json.dumps({"format": "helm-backup"}))
        zf.write(empty_db, "app.db")

    c = TestClient(create_app(config))
    resp = c.post(
        "/api/data/import",
        files={"file": ("bad.zip", bad.read_bytes(), "application/zip")},
    )
    assert resp.status_code == 400


def test_import_rejects_garbage(config):
    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    c = TestClient(create_app(config))
    resp = c.post(
        "/api/data/import",
        files={"file": ("x.zip", b"not a zip", "application/zip")},
    )
    assert resp.status_code == 400
