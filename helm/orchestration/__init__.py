"""Agent orchestration room: the glue between Helm and the terminal agent
(Claude Code).

MVP scope (decisions b199f333 / 76961005): a single external CLI agent —
Claude Code. No internal Python agent; multi-backend (Codex/Gemini/...) and
multi-agent Teams are P1.

m1 ships MCP config injection — merging Helm's MCP server into Claude Code's
config so the terminal agent can read the user's memory/RAG (the server itself
shipped in memory-rag-skills m6). The ACP driver layer + cockpit observation
land in m2–m4.
"""
