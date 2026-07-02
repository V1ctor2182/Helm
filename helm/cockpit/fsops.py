"""File operations for the cockpit browser (承 FanBox srv:436-480):
mkdir / new file / rename / move-to-trash. macOS trash goes through Finder
AppleScript with the path passed via argv (never spliced into the script
literal — quotes in filenames must not break or inject). Local-first, same
trust boundary as browsing.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

_INVALID = re.compile(r"[/\\\0]")

# 路径走 argv;POSIX file 必须 as alias 强转,否则 Finder 报 -1728(承 FanBox)
_TRASH_ARGS = [
    "-e", "on run argv",
    "-e", 'tell application "Finder" to delete (POSIX file (item 1 of argv) as alias)',
    "-e", "end run",
]


def valid_name(name: str) -> bool:
    n = (name or "").strip()
    return 0 < len(n) <= 255 and not _INVALID.search(n) and n not in (".", "..")


def _target(dir_path: str, name: str) -> Path:
    d = Path(dir_path).expanduser()
    if not d.is_dir():
        raise FileNotFoundError(dir_path)
    if not valid_name(name):
        raise ValueError("名称不合法")
    t = d / name.strip()
    if t.exists():
        raise FileExistsError(str(t))
    return t


def make_dir(dir_path: str, name: str) -> str:
    t = _target(dir_path, name)
    t.mkdir()
    return str(t)


def make_file(dir_path: str, name: str) -> str:
    t = _target(dir_path, name)
    t.touch()
    return str(t)


def rename_path(path: str, new_name: str) -> str:
    src = Path(path).expanduser()
    if not src.exists():
        raise FileNotFoundError(path)
    if not valid_name(new_name):
        raise ValueError("名称不合法")
    dst = src.parent / new_name.strip()
    if dst.exists():
        raise FileExistsError(str(dst))
    src.rename(dst)
    return str(dst)


def move_to_trash(path: str, runner=subprocess.run) -> None:
    """Move to the system Trash (recoverable — never unlink). macOS first;
    other platforms refuse rather than hard-delete."""
    p = Path(path).expanduser()
    if not p.exists():
        raise FileNotFoundError(path)
    if sys.platform != "darwin":
        raise RuntimeError("废纸篓删除目前仅支持 macOS")
    try:
        r = runner(
            ["osascript", *_TRASH_ARGS, str(p)],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            "Finder 响应超时——首次使用需在弹出的授权框里允许 Helm 控制 Finder,再试一次"
        ) from None
    if r.returncode != 0:
        msg = (r.stderr or "osascript failed").strip()
        # Finder 自动化未授权(-1743/-600)给人话(承 FanBox)
        if re.search(r"-1743|-600|not allowed|authoriz", msg, re.I):
            raise PermissionError(
                "需在「系统设置 → 隐私与安全性 → 自动化」里允许 Helm 控制 Finder"
            )
        raise RuntimeError(msg)
