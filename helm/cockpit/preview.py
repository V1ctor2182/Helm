"""File preview backend: text content (capped), zip listing. Binary files
(images/pdf) are streamed raw via FileResponse in the route. Local-first, no
sandbox (same trust boundary as browsing).
"""

from __future__ import annotations

import zipfile
from pathlib import Path

# Cap text reads so a giant file can't be slurped into a preview.
MAX_TEXT_BYTES = 1_000_000


def read_text(path: str) -> tuple[str, bool]:
    """Return (content, truncated). Decodes as UTF-8, replacing bad bytes so a
    mis-typed binary still degrades to mojibake rather than a 500."""
    p = Path(path).expanduser()
    if not p.is_file():
        raise FileNotFoundError(path)
    truncated = p.stat().st_size > MAX_TEXT_BYTES
    data = p.read_bytes()[:MAX_TEXT_BYTES]
    return data.decode("utf-8", errors="replace"), truncated


def list_zip(path: str) -> list[dict]:
    p = Path(path).expanduser()
    if not p.is_file():
        raise FileNotFoundError(path)
    with zipfile.ZipFile(p) as zf:
        return [
            {"name": info.filename, "size": info.file_size}
            for info in zf.infolist()
        ]
