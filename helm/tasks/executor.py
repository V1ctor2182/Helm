"""Task executor: fire a scheduled task's prompt through the agent and collect
the result. Reuses the agent-orchestration adapter + subprocess plumbing.

⚠ The real executor makes a paid agent call (Claude Code). The scheduler drives
it only for user-created tasks at their due time; the loop never fires it. Tests
use a stub adapter (canned stream-json via a local python subprocess) or a fake
executor — no real agent.
"""

from __future__ import annotations

from typing import Protocol

from helm.orchestration.acp import AcpEventType
from helm.orchestration.adapters import get_adapter
from helm.orchestration.session import iter_process_lines


class TaskExecutor(Protocol):
    async def execute(self, prompt: str) -> tuple[str, str]:
        """Run ``prompt`` and return (status, output) — status in ok|error."""
        ...


class AgentTaskExecutor:
    """Runs the prompt via an agent backend, collecting its final result."""

    def __init__(self, agent: str = "claude-code") -> None:
        self.agent = agent

    async def execute(self, prompt: str) -> tuple[str, str]:
        adapter = get_adapter(self.agent)
        argv = adapter.command(prompt)
        texts: list[str] = []
        result: str | None = None
        is_error = False
        try:
            async for line in iter_process_lines(argv):
                for ev in adapter.parse_line(line):
                    if ev.type == AcpEventType.MESSAGE:
                        texts.append(str(ev.data.get("text", "")))
                    elif ev.type == AcpEventType.SESSION_END:
                        result = ev.data.get("result")
                        is_error = bool(ev.data.get("is_error", False))
        except FileNotFoundError:
            return "error", f"agent not found: {argv[0]}"
        output = result if result is not None else "\n".join(t for t in texts if t)
        return ("error" if is_error else "ok"), (output or "")
