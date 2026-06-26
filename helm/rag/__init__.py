"""RAG room: index local document directories so Chat / Research / agents can
retrieve from the user's own knowledge (intent 77b01ac2).

m4 ships the backend — source registration, text extraction (text/code/Markdown
+ PDF/docx), chunking, ChromaDB indexing (reusing the m2 embedder), and a
retrieval API. The UI lands in m5, the MCP surface in m6.
"""
