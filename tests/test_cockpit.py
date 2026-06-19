"""m1 (cockpit): FileService dir listing + badge detection, and the project
registry REST."""

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.cockpit.service import detect_badges, list_dir


def test_detect_badges(tmp_path):
    (tmp_path / "package.json").write_text("{}")
    (tmp_path / "pyproject.toml").write_text("")
    assert set(detect_badges(tmp_path)) == {"node", "py"}
    assert detect_badges(tmp_path / "nope") == []  # missing dir → no markers


def test_list_dir_sorts_dirs_first(tmp_path):
    (tmp_path / "b.txt").write_text("x")
    (tmp_path / "Adir").mkdir()
    (tmp_path / "a.md").write_text("# hi")
    names = [e.name for e in list_dir(str(tmp_path))]
    assert names == ["Adir", "a.md", "b.txt"]  # dirs first, then alpha
    md = next(e for e in list_dir(str(tmp_path)) if e.name == "a.md")
    assert md.is_dir is False and md.ext == "md"


def test_list_dir_rejects_non_dir(tmp_path):
    f = tmp_path / "f.txt"
    f.write_text("x")
    import pytest

    with pytest.raises(NotADirectoryError):
        list_dir(str(f))


def test_browse_endpoint(config, tmp_path):
    # Browse a dedicated dir (the app's data dir lives elsewhere under tmp_path).
    proj = tmp_path / "proj"
    proj.mkdir()
    (proj / "sub").mkdir()
    c = TestClient(create_app(config))
    resp = c.get("/api/cockpit/files", params={"path": str(proj)})
    assert resp.status_code == 200
    assert resp.json()["entries"][0]["name"] == "sub"

    assert c.get("/api/cockpit/files", params={"path": str(proj / "x")}).status_code == 404


def test_file_text_and_truncation(config, tmp_path):
    f = tmp_path / "a.py"
    f.write_text("print(1)\n")
    c = TestClient(create_app(config))
    body = c.get("/api/cockpit/text", params={"path": str(f)}).json()
    assert body["content"] == "print(1)\n"
    assert body["truncated"] is False
    # directory / missing → 404
    assert c.get("/api/cockpit/text", params={"path": str(tmp_path)}).status_code == 404


def test_file_raw_serves_bytes(config, tmp_path):
    img = tmp_path / "x.bin"
    img.write_bytes(b"\x00\x01\x02hello")
    c = TestClient(create_app(config))
    resp = c.get("/api/cockpit/raw", params={"path": str(img)})
    assert resp.status_code == 200
    assert resp.content == b"\x00\x01\x02hello"
    assert c.get("/api/cockpit/raw", params={"path": str(tmp_path / "no")}).status_code == 404


def test_zip_listing(config, tmp_path):
    import zipfile

    z = tmp_path / "a.zip"
    with zipfile.ZipFile(z, "w") as zf:
        zf.writestr("inner.txt", "hi")
    not_zip = tmp_path / "b.zip"
    not_zip.write_text("not a zip")
    c = TestClient(create_app(config))
    entries = c.get("/api/cockpit/zip", params={"path": str(z)}).json()["entries"]
    assert entries[0]["name"] == "inner.txt"
    assert c.get("/api/cockpit/zip", params={"path": str(not_zip)}).status_code == 400


def test_open_and_list_projects(config, tmp_path):
    (tmp_path / "go.mod").write_text("module x")
    c = TestClient(create_app(config))

    opened = c.post("/api/cockpit/projects", json={"path": str(tmp_path)})
    assert opened.status_code == 200
    body = opened.json()
    assert body["name"] == tmp_path.name
    assert "go" in body["badges"]
    assert body["last_opened"] is not None

    listed = c.get("/api/cockpit/projects").json()["projects"]
    assert len(listed) == 1
    assert listed[0]["path"] == str(tmp_path)
