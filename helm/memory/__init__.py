"""Memory room: persistent cross-session memory (facts, preferences, decisions).

m1 ships the SQLite-backed store with CRUD + keyword recall. Vector / hybrid
search (ChromaDB + fastembed) lands in m2, JSON import/export + UI in m3, and
the MCP capability surface in m6. Storage reuses the platform-shell SQLAlchemy
stack (constraint 8ace2b3a: reuse Odysseus's SQLAlchemy/SQLite/ChromaDB).
"""
