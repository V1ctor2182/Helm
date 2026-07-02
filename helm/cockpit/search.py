"""⌘K file/content search (承 FanBox srv:269-392):
文件名模糊(子序列打分:连续/词首/靠前加分+目录加权+近期修改加权,walk 6 万/4s 预算);
`内容:` 全文——Spotlight mdfind 优先(覆盖 PDF/docx/OCR,毫秒级),
不可用/无命中回退 grep(≤512KB 文本、mtime 倒序、行级预览)。
"""

from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path

TEXT_EXTS = {
    "md", "markdown", "txt", "log", "json", "yaml", "yml", "toml", "csv",
    "ts", "tsx", "js", "jsx", "mjs", "py", "rs", "go", "swift", "sh", "sql",
    "html", "css", "svelte", "c", "h", "cpp", "java", "rb", "php", "lock",
}

SKIP_DIRS = {"node_modules", ".git", "dist", "build", ".venv", "__pycache__", ".next", "target"}


def fuzzy_score(query: str, target: str) -> float:
    """FanBox fuzzyScore 原样移植:子序列匹配,连续/词首/靠前加分,越短越好。"""
    q = query.lower()
    t = target.lower()
    qi = 0
    score = 0.0
    last = -2
    streak = 0
    for ti, ch in enumerate(t):
        if qi < len(q) and ch == q[qi]:
            pts = 10.0
            if ti == last + 1:
                streak += 1
                pts += streak * 8
            else:
                streak = 0
            if ti == 0 or t[ti - 1] in "/_-. ":
                pts += 15
            pts += max(0.0, 8 - ti * 0.1)
            score += pts
            last = ti
            qi += 1
    if qi < len(q):
        return -1.0
    return score - (len(t) - len(q)) * 0.2


def _walk(root: Path, limit: int, deadline: float):
    """Yield (path, name, is_dir, mtime);跳过噪声目录;限量+限时。"""
    count = 0
    stack = [root]
    while stack:
        if count >= limit or time.monotonic() > deadline:
            yield None  # truncated 哨兵
            return
        d = stack.pop()
        try:
            with os.scandir(d) as it:
                for e in it:
                    if count >= limit or time.monotonic() > deadline:
                        yield None
                        return
                    name = e.name
                    if name.startswith("."):
                        continue
                    try:
                        is_dir = e.is_dir(follow_symlinks=False)
                        mtime = e.stat(follow_symlinks=False).st_mtime
                    except OSError:
                        continue
                    count += 1
                    yield (e.path, name, is_dir, mtime)
                    if is_dir and name not in SKIP_DIRS:
                        stack.append(Path(e.path))
        except OSError:
            continue


def search_files(query: str, root_path: str, limit: int = 60000, budget_s: float = 4.0) -> dict:
    root = Path(root_path).expanduser()
    q = (query or "").strip()
    if not q or not root.is_dir():
        return {"results": [], "truncated": False}
    deadline = time.monotonic() + budget_s
    now = time.time()
    matches: list[dict] = []
    truncated = False
    for item in _walk(root, limit, deadline):
        if item is None:
            truncated = True
            break
        path, name, is_dir, mtime = item
        s = fuzzy_score(q, name)
        if s <= 0:
            continue
        # 近期修改加权(「我刚做的东西」优先浮出)+ 目录小幅加权(找项目目录最常见)
        recency = max(0.0, 20 - (now - mtime) / 86400) * 0.6
        matches.append(
            {
                "name": name,
                "path": path,
                "is_dir": is_dir,
                "mtime": mtime,
                "score": s + recency + (6 if is_dir else 0),
            }
        )
    matches.sort(key=lambda m: -m["score"])
    return {"results": matches[:80], "truncated": truncated}


def _grep(query: str, root: Path) -> dict:
    lower = query.lower()
    files: list[tuple[float, str]] = []
    truncated = False
    for item in _walk(root, 12000, time.monotonic() + 1.8):
        if item is None:
            truncated = True
            break
        path, name, is_dir, mtime = item
        if is_dir:
            continue
        ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
        if ext in TEXT_EXTS:
            try:
                if os.path.getsize(path) < 512 * 1024:
                    files.append((mtime, path))
            except OSError:
                continue
    # 按修改时间倒序读:「我最近写过那句话」的文件优先命中
    files.sort(reverse=True)
    results: list[dict] = []
    deadline = time.monotonic() + 3.5
    for _, path in files:
        if time.monotonic() > deadline or len(results) >= 50:
            truncated = True
            break
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                for i, line in enumerate(f, 1):
                    if lower in line.lower():
                        results.append({"path": path, "line": line.strip()[:200], "line_no": i})
                        break
        except OSError:
            continue
    return {"results": results, "truncated": truncated, "engine": "grep"}


def search_content(query: str, root_path: str, runner=subprocess.run) -> dict:
    """全文搜索:mdfind 优先,失败/空回退 grep。"""
    root = Path(root_path).expanduser()
    q = (query or "").strip()
    if len(q) < 2 or not root.is_dir():
        return {"results": [], "truncated": False, "engine": "none"}
    try:
        r = runner(
            ["mdfind", "-onlyin", str(root), q],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            paths = [p for p in r.stdout.splitlines() if p.strip()][:40]
            if paths:
                return {
                    "results": [{"path": p, "line": "", "line_no": 0} for p in paths],
                    "truncated": len(paths) >= 40,
                    "engine": "mdfind",
                }
    except (OSError, subprocess.TimeoutExpired):
        pass
    return _grep(q, root)
