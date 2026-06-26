"""Helm MCP server — exposes the user's memory + RAG to the terminal agent.

⚠️ This is an OUTWARD CONTRACT (constraint: MCP tool signatures the terminal
Claude Code depends on). The four tool names + their parameters below are
STABLE — renaming or repurposing them breaks every agent config that wired them
in. New capabilities should be ADDED as new tools, not by changing these.

Tools (all read/append the single-user local brain via the backend REST API):
  - helm_memory_search(query, limit)   semantic+keyword recall
  - helm_memory_add(text, category)    append a memory
  - helm_memory_list(category)         browse memories
  - helm_rag_search(query, limit)      retrieve from indexed documents

Run as a stdio server (how Claude Code launches it): ``python -m helm.mcp``
or the ``helm-mcp`` console script. .mcp.json example::

    { "mcpServers": { "helm": { "command": "helm-mcp" } } }
"""

from __future__ import annotations

from collections.abc import Callable

import httpx
from mcp.server.fastmcp import FastMCP

from helm.mcp.client import HelmClient

INSTRUCTIONS = (
    "Access the user's Helm brain. Search or add personal memories (facts, "
    "preferences, decisions) and retrieve snippets from the user's indexed "
    "documents. Prefer recalling memory before answering questions about the user."
)


def _safe(fn: Callable[[], str]) -> str:
    """Turn transport failures into a readable tool result instead of an opaque
    MCP error — the agent should learn 'the app isn't running', not just fail."""
    try:
        return fn()
    except httpx.HTTPError as exc:
        return f"Helm backend unreachable ({exc}). Is the Helm app running?"


def build_server(client: HelmClient | None = None) -> FastMCP:
    mcp = FastMCP("helm", instructions=INSTRUCTIONS)
    api = client or HelmClient()

    @mcp.tool()
    def helm_memory_search(query: str, limit: int = 5) -> str:
        """Search the user's saved memories (facts/preferences/decisions) by
        keyword + meaning. Use this to recall what you know about the user."""
        def run() -> str:
            results = api.memory_search(query, limit)
            if not results:
                return "No matching memories."
            return "\n".join(
                f"- [{m['category']}] {m['text']} (score {m['score']})"
                for m in results
            )

        return _safe(run)

    @mcp.tool()
    def helm_memory_add(text: str, category: str = "fact") -> str:
        """Save a new memory for the user. category is one of: fact, preference,
        decision (defaults to fact)."""
        def run() -> str:
            m = api.memory_add(text, category)
            return f"Saved memory #{m['id']} [{m['category']}]: {m['text']}"

        return _safe(run)

    @mcp.tool()
    def helm_memory_list(category: str | None = None) -> str:
        """List the user's memories, optionally filtered by category
        (fact/preference/decision)."""
        def run() -> str:
            memories = api.memory_list(category)
            if not memories:
                return "No memories yet."
            return "\n".join(
                f"- #{m['id']} [{m['category']}] {m['text']}" for m in memories
            )

        return _safe(run)

    @mcp.tool()
    def helm_rag_search(query: str, limit: int = 5) -> str:
        """Retrieve relevant snippets from the user's indexed documents (their
        knowledge base). Returns the source path + snippet for each hit."""
        def run() -> str:
            hits = api.rag_search(query, limit)
            if not hits:
                return "No relevant document snippets (is a source indexed?)."
            return "\n\n".join(
                f"[{h['path']}] (score {h['score']})\n{h['text']}" for h in hits
            )

        return _safe(run)

    @mcp.tool()
    def helm_email_unread(limit: int = 20) -> str:
        """List the user's unread emails (id, sender, subject) — so the agent can
        triage or summarize the user's inbox (email-calendar email_server)."""
        def run() -> str:
            emails = api.email_unread(limit)
            if not emails:
                return "No unread emails."
            return "\n".join(
                f"#{e['id']} [{e['from_addr']}] {e['subject']}" for e in emails
            )

        return _safe(run)

    @mcp.tool()
    def helm_email_read(email_id: int) -> str:
        """Read one email's full body by id (from helm_email_unread). Returns
        sender + subject + body."""
        def run() -> str:
            e = api.email_read(email_id)
            return f"From: {e.get('from_addr')}\nSubject: {e.get('subject')}\n\n{e.get('body', '')}"

        return _safe(run)

    return mcp


def main() -> None:  # pragma: no cover - stdio entrypoint
    build_server().run(transport="stdio")
