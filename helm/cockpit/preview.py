"""File preview backend: text content (capped), zip listing, and in-place text
writes (edit-in-preview). Binary files (images/pdf) are streamed raw via
FileResponse in the route. Local-first, no sandbox (same trust boundary as
browsing).
"""

from __future__ import annotations

import os
import tempfile
import zipfile
from pathlib import Path

# Cap text reads so a giant file can't be slurped into a preview.
MAX_TEXT_BYTES = 1_000_000
# Cap writes so a runaway payload can't fill the disk through the editor.
MAX_WRITE_BYTES = 5_000_000


class WriteConflict(Exception):
    """The file changed on disk since the editor loaded it (agent 外改)."""

    def __init__(self, mtime: float) -> None:
        super().__init__("file modified externally")
        self.mtime = mtime


def read_text(path: str) -> tuple[str, bool]:
    """Return (content, truncated). Decodes as UTF-8, replacing bad bytes so a
    mis-typed binary still degrades to mojibake rather than a 500."""
    p = Path(path).expanduser()
    if not p.is_file():
        raise FileNotFoundError(path)
    truncated = p.stat().st_size > MAX_TEXT_BYTES
    data = p.read_bytes()[:MAX_TEXT_BYTES]
    return data.decode("utf-8", errors="replace"), truncated


def write_text(path: str, content: str, expected_mtime: float | None = None) -> float:
    """Atomically write ``content`` to an existing file (tmp + fsync + rename,
    承 FanBox srv:409-433). ``expected_mtime`` 是编辑器加载时的 mtime——磁盘上
    已比它新(agent 外改)则抛 WriteConflict,把覆盖决定交还给用户。
    Returns the new mtime."""
    p = Path(path).expanduser()
    if not p.is_file():
        raise FileNotFoundError(path)
    data = content.encode("utf-8")
    if len(data) > MAX_WRITE_BYTES:
        raise ValueError("content too large")
    cur = p.stat().st_mtime
    if expected_mtime is not None and abs(cur - expected_mtime) > 1e-6:
        raise WriteConflict(cur)
    # 隐藏 tmp 名(.name.tmp.*):文件监听的噪声过滤会忽略点文件,不闪高亮
    fd, tmp = tempfile.mkstemp(dir=str(p.parent), prefix=f".{p.name}.tmp.")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, p)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return p.stat().st_mtime


def list_zip(path: str) -> list[dict]:
    p = Path(path).expanduser()
    if not p.is_file():
        raise FileNotFoundError(path)
    with zipfile.ZipFile(p) as zf:
        return [
            {"name": info.filename, "size": info.file_size}
            for info in zf.infolist()
        ]
