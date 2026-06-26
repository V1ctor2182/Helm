"""m1 (agent-orchestration): Claude Code MCP config injection (merge + backup)."""

import json
import sys
from pathlib import Path

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.orchestration import mcp_config


def test_server_spec_uses_current_interpreter():
    spec = mcp_config.helm_server_spec()
    assert spec == {"command": sys.executable, "args": ["-m", "helm.mcp"]}


def test_inject_merges_and_preserves_existing(tmp_path):
    cfg = tmp_path / ".mcp.json"
    cfg.write_text(
        json.dumps({"mcpServers": {"vibehub": {"type": "http", "url": "x"}}, "other": 1}),
        encoding="utf-8",
    )
    res = mcp_config.inject(cfg)
    assert res["injected"] is True
    assert res["backup"] == str(cfg) + mcp_config.BACKUP_SUFFIX

    data = json.loads(cfg.read_text())
    assert "vibehub" in data["mcpServers"]  # existing server preserved
    assert data["mcpServers"]["helm"]["args"] == ["-m", "helm.mcp"]
    assert data["other"] == 1  # unrelated keys preserved

    # backup holds the pre-injection original (no helm entry)
    backup = json.loads(Path(res["backup"]).read_text())
    assert "helm" not in backup["mcpServers"]


def test_inject_into_missing_file_creates_it(tmp_path):
    cfg = tmp_path / "nested" / ".mcp.json"
    res = mcp_config.inject(cfg)
    assert res["injected"] is True
    assert res["backup"] is None  # nothing to back up
    assert json.loads(cfg.read_text())["mcpServers"]["helm"]["command"] == sys.executable


def test_disable_removes_only_helm_entry(tmp_path):
    cfg = tmp_path / ".mcp.json"
    mcp_config.inject(cfg)  # add helm
    cfg_data = json.loads(cfg.read_text())
    cfg_data["mcpServers"]["keepme"] = {"command": "x"}
    cfg.write_text(json.dumps(cfg_data), encoding="utf-8")

    res = mcp_config.inject(cfg, enabled=False)
    assert res["injected"] is False
    data = json.loads(cfg.read_text())
    assert "helm" not in data["mcpServers"]
    assert "keepme" in data["mcpServers"]  # other servers untouched


def test_backup_taken_once_not_clobbered(tmp_path):
    cfg = tmp_path / ".mcp.json"
    cfg.write_text(json.dumps({"mcpServers": {"orig": {"command": "o"}}}), encoding="utf-8")
    mcp_config.inject(cfg)  # first: makes backup
    mcp_config.inject(cfg, enabled=False)  # second: must NOT overwrite backup
    backup = json.loads((Path(str(cfg) + mcp_config.BACKUP_SUFFIX)).read_text())
    assert backup["mcpServers"] == {"orig": {"command": "o"}}  # still the original


def test_status_reports_injection_state(tmp_path):
    cfg = tmp_path / ".mcp.json"
    assert mcp_config.status(cfg)["injected"] is False
    assert mcp_config.status(cfg)["exists"] is False
    mcp_config.inject(cfg)
    st = mcp_config.status(cfg)
    assert st["injected"] is True and st["exists"] is True


def test_malformed_config_refused_not_clobbered(tmp_path):
    cfg = tmp_path / ".mcp.json"
    cfg.write_text("{ not valid json", encoding="utf-8")
    st = mcp_config.status(cfg)
    assert st["injected"] is False and st["error"] is not None
    # inject must raise and leave the file untouched
    import pytest

    with pytest.raises(ValueError):
        mcp_config.inject(cfg)
    assert cfg.read_text() == "{ not valid json"


def test_orchestration_routes(config, tmp_path):
    cfg = tmp_path / ".mcp.json"
    c = TestClient(create_app(config))
    # status (empty)
    assert c.get("/api/orchestration/mcp", params={"config_path": str(cfg)}).json()["injected"] is False
    # inject
    r = c.post("/api/orchestration/mcp", json={"config_path": str(cfg), "enabled": True})
    assert r.status_code == 200 and r.json()["injected"] is True
    assert json.loads(cfg.read_text())["mcpServers"]["helm"]
    # malformed → 400
    cfg.write_text("nope", encoding="utf-8")
    assert c.post("/api/orchestration/mcp", json={"config_path": str(cfg)}).status_code == 400
