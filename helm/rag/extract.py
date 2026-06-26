"""Document text extraction + chunking for RAG indexing.

Text/code/Markdown are read directly (no deps). PDF (pypdf) and .docx
(python-docx) degrade gracefully — if the lib is missing or the file is
unparseable, extraction returns None and the indexer skips that file rather
than failing the whole source.
"""

from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# Plain-text / code / markup read as UTF-8 (errors replaced).
TEXT_EXTS = {
    ".txt", ".md", ".markdown", ".rst",
    ".py", ".js", ".ts", ".tsx", ".jsx", ".svelte", ".vue",
    ".json", ".yaml", ".yml", ".toml", ".ini", ".cfg",
    ".html", ".htm", ".css", ".scss",
    ".csv", ".tsv", ".log", ".xml",
    ".sh", ".bash", ".zsh",
    ".go", ".rs", ".java", ".c", ".h", ".cpp", ".hpp",
    ".rb", ".php", ".sql", ".lua", ".kt", ".swift",
}
PDF_EXTS = {".pdf"}
DOCX_EXTS = {".docx"}
SUPPORTED_EXTS = TEXT_EXTS | PDF_EXTS | DOCX_EXTS

# Skip these dirs when walking a source directory (noise / huge / vendored).
SKIP_DIRS = {
    ".git", "node_modules", ".venv", "venv", "__pycache__", ".mypy_cache",
    ".pytest_cache", "dist", "build", ".next", "out", ".svelte-kit",
}


def is_supported(path: Path) -> bool:
    return path.suffix.lower() in SUPPORTED_EXTS


def extract_text(path: Path) -> str | None:
    """Best-effort plain text for a file, or None if unsupported/unreadable."""
    ext = path.suffix.lower()
    if ext in TEXT_EXTS:
        try:
            return path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            logger.warning("read failed %s: %s", path, exc)
            return None
    if ext in PDF_EXTS:
        return _extract_pdf(path)
    if ext in DOCX_EXTS:
        return _extract_docx(path)
    return None


def _extract_pdf(path: Path) -> str | None:
    try:
        from pypdf import PdfReader
    except ImportError:
        logger.warning("pypdf not installed; skipping PDF %s", path)
        return None
    try:
        reader = PdfReader(str(path))
        return "\n".join((page.extract_text() or "") for page in reader.pages)
    except Exception as exc:  # pragma: no cover - corrupt-file path
        logger.warning("PDF extract failed %s: %s", path, exc)
        return None


def _extract_docx(path: Path) -> str | None:
    try:
        from docx import Document
    except ImportError:
        logger.warning("python-docx not installed; skipping %s", path)
        return None
    try:
        doc = Document(str(path))
        return "\n".join(p.text for p in doc.paragraphs)
    except Exception as exc:  # pragma: no cover - corrupt-file path
        logger.warning("docx extract failed %s: %s", path, exc)
        return None


def iter_files(root: Path):
    """Yield supported files under ``root`` (a file yields just itself),
    skipping noise directories."""
    if root.is_file():
        if is_supported(root):
            yield root
        return
    for p in sorted(root.rglob("*")):
        if p.is_dir():
            continue
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        if is_supported(p):
            yield p


def chunk_text(text: str, size: int = 1000, overlap: int = 150) -> list[str]:
    """Split text into ~``size``-char chunks with ``overlap``, preferring to
    break on a newline in the back half of each window so chunks fall on
    natural boundaries."""
    text = text.strip()
    if not text:
        return []
    if overlap >= size:  # guard against a non-advancing window
        overlap = size // 4
    chunks: list[str] = []
    start = 0
    n = len(text)
    while start < n:
        end = min(start + size, n)
        if end < n:
            nl = text.rfind("\n", start + size // 2, end)
            if nl != -1:
                end = nl
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end >= n:
            break
        start = max(end - overlap, start + 1)
    return chunks
