"""MCP capability layer (memory-rag-skills m6).

Exposes the user's Helm memory + RAG to the terminal agent (Claude Code) as an
MCP server. The server is a STATELESS bridge: it talks to the running Helm
backend over its local REST API rather than opening the SQLite DB / Chroma
store directly, so the app and the agent never contend for those stores (the
backend stays the single owner). See :mod:`helm.mcp.server`.
"""
