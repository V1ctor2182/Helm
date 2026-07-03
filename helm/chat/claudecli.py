"""claude-cli provider(用户 2026-07-03 拍板):子进程跑本机 `claude -p`,
走用户已登录的 Claude Code 订阅——不要 API key、不按量计费。

协议:`claude -p --output-format stream-json --include-partial-messages --verbose`
按行输出 JSON;token 级增量在 type=stream_event 的 content_block_delta 里,
没开局部消息时兜底取 type=assistant 的整段文本。多轮会话把历史拼成一段
transcript(-p 是无状态单发)。cwd 固定 data_dir——别让仓库 CLAUDE.md 混进闲聊。
"""

from __future__ import annotations

import asyncio
import json
import shutil
import subprocess
from collections.abc import AsyncIterator
from pathlib import Path

_TIMEOUT_S = 300


def detect_claude() -> str | None:
    """找本机 claude 可执行文件:login shell 的 PATH(GUI 进程只有精简 PATH,
    Homebrew/nvm 里的 claude 会丢——终端那轮同款病根)。"""
    try:
        r = subprocess.run(
            ["/bin/zsh", "-l", "-c", "command -v claude"],
            capture_output=True, text=True, timeout=10,
        )
        path = r.stdout.strip().splitlines()[-1] if r.returncode == 0 and r.stdout.strip() else None
    except (OSError, subprocess.TimeoutExpired):
        path = None
    if path and Path(path).exists():
        return path
    fallback = shutil.which("claude")
    return fallback


def build_prompt(messages: list[dict], system: str | None) -> str:
    """把多轮历史拼成单发 transcript(-p 无状态)。"""
    parts: list[str] = []
    if system:
        parts.append(f"[系统指示]\n{system}")
    for m in messages:
        who = "用户" if m.get("role") == "user" else "助手"
        parts.append(f"[{who}]\n{m.get('content', '')}")
    parts.append("[助手]\n(直接以助手身份回复上面最后一条,不要复述前缀,不要使用任何工具。)")
    return "\n\n".join(parts)


def extract_text(line: str) -> str | None:
    """从 stream-json 一行里抽增量文本;非文本行返回 None(纯函数可测)。"""
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        return None
    kind = obj.get("type")
    if kind == "stream_event":
        ev = obj.get("event") or {}
        if ev.get("type") == "content_block_delta":
            delta = ev.get("delta") or {}
            if delta.get("type") == "text_delta":
                return delta.get("text")
        return None
    if kind == "assistant":
        # 兜底:没有 partial 事件时整段到达(老版本 CLI)
        blocks = ((obj.get("message") or {}).get("content")) or []
        text = "".join(b.get("text", "") for b in blocks if b.get("type") == "text")
        return text or None
    return None


async def chat_stream(
    *,
    binary: str,
    model: str,
    messages: list[dict],
    system: str | None,
    cwd: Path,
    spawn=asyncio.create_subprocess_exec,
) -> AsyncIterator[str]:
    """Yield text chunks from a one-shot `claude -p` run. `spawn` 注入可测。"""
    argv = [
        binary, "-p", build_prompt(messages, system),
        "--output-format", "stream-json",
        "--include-partial-messages",
        "--verbose",
    ]
    if model:
        argv += ["--model", model]
    proc = await spawn(
        *argv,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=str(cwd),
    )
    saw_partial = False
    full_fallback: str | None = None
    try:
        assert proc.stdout is not None
        while True:
            raw = await asyncio.wait_for(proc.stdout.readline(), timeout=_TIMEOUT_S)
            if not raw:
                break
            line = raw.decode("utf-8", "replace").strip()
            if not line:
                continue
            try:
                kind = json.loads(line).get("type")
            except json.JSONDecodeError:
                continue
            text = extract_text(line)
            if text is None:
                continue
            if kind == "stream_event":
                saw_partial = True
                yield text
            elif kind == "assistant":
                # partial 模式下 assistant 是重复的整段——只在没见过增量时兜底
                full_fallback = text
        if not saw_partial and full_fallback:
            yield full_fallback
        rc = await proc.wait()
        if rc != 0 and not saw_partial and not full_fallback:
            err = (await proc.stderr.read()).decode("utf-8", "replace").strip() if proc.stderr else ""
            raise RuntimeError(err[:300] or f"claude -p 退出码 {rc}")
    finally:
        if proc.returncode is None:
            proc.terminate()
