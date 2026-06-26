"""m6 (mcp): the MCP capability layer exposing memory/RAG to the terminal agent.

The HelmClient is driven over a TestClient (in-process, no socket) so the tool
surface is verified headless. We assert both the OUTWARD CONTRACT (tool names +
schemas — these are stable) and that each tool round-trips through the backend.
"""

import httpx
import pytest
from fastapi.testclient import TestClient

from helm.app import create_app
from helm.mcp.client import HelmClient
from helm.mcp.server import build_server

EXPECTED_TOOLS = {
    "helm_memory_search",
    "helm_memory_add",
    "helm_memory_list",
    "helm_rag_search",
}


def _client(config) -> HelmClient:
    return HelmClient(client=TestClient(create_app(config)))


def test_client_memory_roundtrip(config):
    api = _client(config)
    created = api.memory_add("user prefers tabs over spaces", "preference")
    assert created["id"] >= 1
    listed = api.memory_list()
    assert any(m["text"].startswith("user prefers tabs") for m in listed)
    hits = api.memory_search("tabs", limit=5)
    assert any("tabs" in h["text"] for h in hits)
    # category filter passes through
    assert api.memory_list(category="fact") == [
        m for m in listed if m["category"] == "fact"
    ]


def test_client_rag_search_empty_without_vectors(config):
    # conftest disables vectors → rag search returns [] (not an error)
    api = _client(config)
    assert api.rag_search("anything") == []


@pytest.mark.anyio
async def test_mcp_tool_contract(config):
    """The four tool names + their parameter schemas are the stable contract."""
    mcp = build_server(_client(config))
    tools = {t.name: t for t in await mcp.list_tools()}
    assert set(tools) == EXPECTED_TOOLS

    search = tools["helm_memory_search"]
    props = search.inputSchema["properties"]
    assert "query" in props and "limit" in props
    assert search.inputSchema["required"] == ["query"]

    add = tools["helm_memory_add"]
    assert "text" in add.inputSchema["properties"]
    assert add.inputSchema["required"] == ["text"]


@pytest.mark.anyio
async def test_mcp_tools_execute(config):
    mcp = build_server(_client(config))
    await mcp.call_tool("helm_memory_add", {"text": "loves dark mode", "category": "preference"})

    result = await mcp.call_tool("helm_memory_search", {"query": "dark mode"})
    text = _text_of(result)
    assert "dark mode" in text

    empty = await mcp.call_tool("helm_rag_search", {"query": "nothing indexed"})
    assert "No relevant document snippets" in _text_of(empty)


@pytest.mark.anyio
async def test_tool_reports_backend_unreachable():
    """A dead backend yields a readable message, not an opaque MCP crash."""
    bad = HelmClient(base_url="http://127.0.0.1:1")  # closed port
    out = _text_of(await build_server(bad).call_tool("helm_memory_list", {}))
    assert "unreachable" in out.lower()


def _text_of(result) -> str:
    """Extract concatenated text from a FastMCP call_tool result (shape varies
    by version: (content, ...) tuple or a result with .content)."""
    content = result[0] if isinstance(result, tuple) else getattr(result, "content", result)
    if isinstance(content, list):
        return "\n".join(getattr(c, "text", str(c)) for c in content)
    return getattr(content, "text", str(content))
