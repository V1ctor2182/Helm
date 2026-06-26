"""Live ACP session: launch the agent subprocess and surface its stdout as
lines for the run driver to parse into ACP events.

Kept tiny + transport-agnostic: ``iter_process_lines`` is the only OS-touching
piece (async subprocess → decoded lines), so the WS route and tests can drive
the same plumbing with a real `claude` or a canned-output stub. The raw-pty
terminal (cockpit) stays as the fallback path — this is the *structured* lane.
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator


async def iter_process_lines(
    argv: list[str], cwd: str | None = None
) -> AsyncIterator[str]:
    """Spawn ``argv`` and yield its stdout line by line (stderr merged in), as
    decoded text. Raises FileNotFoundError if the binary is missing (caller
    turns that into a run failure). Always reaps the process on exit."""
    proc = await asyncio.create_subprocess_exec(
        *argv,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    try:
        assert proc.stdout is not None
        while True:
            raw = await proc.stdout.readline()
            if not raw:
                break
            yield raw.decode("utf-8", "replace")
    finally:
        if proc.returncode is None:
            try:
                proc.terminate()
            except ProcessLookupError:  # pragma: no cover - already gone
                pass
        await proc.wait()
