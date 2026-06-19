"""GitService: HEAD-vs-working content for a file (feeds Monaco's DiffEditor)
and repo status. Shells out to `git -C` with argv lists (no shell string).
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from helm.cockpit.preview import MAX_TEXT_BYTES


class NotInRepo(Exception):
    pass


def _git(repo: str, *args: str) -> tuple[int, str]:
    proc = subprocess.run(
        ["git", "-C", repo, *args],
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout


def repo_root(path: str) -> str | None:
    start = path if os.path.isdir(path) else os.path.dirname(path) or "."
    rc, out = _git(start, "rev-parse", "--show-toplevel")
    return out.strip() if rc == 0 and out.strip() else None


def file_diff(path: str) -> dict:
    """HEAD vs working-tree content + status for a single file."""
    p = Path(path)
    root = repo_root(str(p))
    if root is None:
        raise NotInRepo(path)
    rel = os.path.relpath(str(p), root)

    # Cap both sides like the preview pane so a huge file can't be slurped.
    rc, head = _git(root, "show", f"HEAD:{rel}")
    head_content = (head if rc == 0 else "")[:MAX_TEXT_BYTES]  # untracked → ""

    working = (
        p.read_bytes()[:MAX_TEXT_BYTES].decode("utf-8", "replace")
        if p.is_file()
        else ""
    )

    _, st = _git(root, "status", "--porcelain", "--", rel)
    code = st[:2].strip() if st else ""
    if code == "??":
        status = "untracked"
    elif code:
        status = "modified"
    elif not p.is_file():
        status = "deleted"
    else:
        status = "unchanged"

    return {
        "repo_root": root,
        "rel_path": rel,
        "head": head_content,
        "working": working,
        "status": status,
    }


def status(repo_dir: str) -> list[dict]:
    """Porcelain status for the repo containing repo_dir (changed files)."""
    root = repo_root(repo_dir)
    if root is None:
        return []
    _, out = _git(root, "status", "--porcelain")
    entries: list[dict] = []
    for line in out.splitlines():
        if not line.strip():
            continue
        code, rel = line[:2].strip(), line[3:]
        entries.append({"path": os.path.join(root, rel), "status": code})
    return entries
