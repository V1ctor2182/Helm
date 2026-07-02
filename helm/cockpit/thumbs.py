"""Image thumbnail pipeline (承 FanBox srv:1174-1229, 图片先行):
sips 生成、md5(路径+mtime+尺寸) 缓存键、并发去重(per-key 锁)、
透明格式出 png 其余 jpeg、缓存总量 LRU 裁剪。macOS-first(sips 系统自带);
失败由前端回退矢量字形,不留裂图。
"""

from __future__ import annotations

import hashlib
import os
import subprocess
import threading
from pathlib import Path

IMG_EXT = {"png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "heif", "tif", "tiff"}
ALPHA_EXT = {"png", "gif", "webp"}

MAX_CACHE_BYTES = 200 * 1024 * 1024
_PRUNE_EVERY = 50

_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()
_gen_count = 0


def _lock_for(key: str) -> threading.Lock:
    with _locks_guard:
        if key not in _locks:
            # 有界:锁表跟着缓存走,粗暴清一次即可
            if len(_locks) > 512:
                _locks.clear()
            _locks[key] = threading.Lock()
        return _locks[key]


def cache_dir_for(data_dir: Path) -> Path:
    return Path(data_dir) / "thumbs"


def prune_cache(cache_dir: Path, max_bytes: int = MAX_CACHE_BYTES) -> None:
    """总体积超限时从最旧开始删(同一文件每改一次就多一个键,不清会无限涨)。"""
    try:
        stats = []
        for f in cache_dir.iterdir():
            try:
                st = f.stat()
                if f.is_file():
                    stats.append((st.st_mtime, st.st_size, f))
            except OSError:
                continue
        total = sum(s[1] for s in stats)
        if total <= max_bytes:
            return
        stats.sort()  # 最旧的先删
        for _, size, f in stats:
            if total <= max_bytes:
                break
            try:
                f.unlink()
                total -= size
            except OSError:
                continue
    except OSError:
        pass


def ensure_thumb(
    path: str,
    size: int,
    cache_dir: Path,
    runner=subprocess.run,
) -> tuple[Path, str]:
    """Return (cache_file, mime). Generates via sips on miss; cached by
    md5(path:mtime:size) so an edited image gets a fresh key."""
    global _gen_count
    p = Path(path).expanduser()
    if not p.is_file():
        raise FileNotFoundError(path)
    ext = p.suffix.lower().lstrip(".")
    if ext not in IMG_EXT:
        raise ValueError("not an image")
    s = min(1600, max(48, size))
    st = p.stat()
    key = hashlib.md5(f"{p}:{st.st_mtime}:{s}".encode()).hexdigest()
    jpeg = ext not in ALPHA_EXT
    out = cache_dir / f"{key}.{'jpg' if jpeg else 'png'}"
    mime = "image/jpeg" if jpeg else "image/png"
    if out.exists():
        return out, mime
    cache_dir.mkdir(parents=True, exist_ok=True)
    with _lock_for(key):
        if out.exists():  # 并发去重:等锁期间别人已生成
            return out, mime
        tmp = cache_dir / f"{key}.tmp{os.getpid()}"
        r = runner(
            [
                "sips",
                "-s", "format", "jpeg" if jpeg else "png",
                "-Z", str(s),
                str(p),
                "--out", str(tmp),
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
        if r.returncode != 0 or not tmp.exists():
            try:
                tmp.unlink()
            except OSError:
                pass
            raise RuntimeError((r.stderr or "sips failed").strip())
        os.replace(tmp, out)
        _gen_count += 1
        if _gen_count % _PRUNE_EVERY == 0:
            prune_cache(cache_dir)
    return out, mime
