"""Agent backend adapters: native CLI output → ACP events + how to launch.

The abstraction is multi-backend by design (decision 76961005), but MVP ships
ONE parser — Claude Code. Adding Codex/Gemini/... later = a new Adapter
subclass registered below; nothing upstream changes.
"""

from __future__ import annotations

import json
from abc import ABC, abstractmethod

from helm.orchestration.acp import AcpEvent, AcpEventType


class AgentAdapter(ABC):
    """Normalizes one backend. Stateless: ``parse_line`` maps a single line of
    native stdout to zero or more ACP events (one line can carry several, e.g.
    an assistant turn with text + a tool call)."""

    name: str

    @abstractmethod
    def command(self, prompt: str, cwd: str | None = None) -> list[str]:
        """argv to launch the agent for ``prompt`` (run in ``cwd``)."""

    @abstractmethod
    def parse_line(self, raw: str) -> list[AcpEvent]:
        """Parse one line of native stdout into ACP events ([] if irrelevant)."""


def _flatten_text(content) -> str:
    """tool_result/content may be a string or a list of content blocks."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            b.get("text", "") if isinstance(b, dict) else str(b) for b in content
        )
    return "" if content is None else str(content)


class ClaudeCodeAdapter(AgentAdapter):
    """Parses Claude Code's ``--output-format stream-json`` NDJSON.

    Events seen: ``system/init`` (model+tools+cwd), ``assistant`` (text +
    tool_use blocks), ``user`` (tool_result blocks), ``result`` (final)."""

    name = "claude-code"

    def command(self, prompt: str, cwd: str | None = None) -> list[str]:
        return [
            "claude",
            "-p",
            prompt,
            "--output-format",
            "stream-json",
            "--verbose",
        ]

    def parse_line(self, raw: str) -> list[AcpEvent]:
        line = raw.strip()
        if not line:
            return []
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            return []  # non-JSON verbose noise — ignore
        if not isinstance(obj, dict):
            return []

        kind = obj.get("type")
        sid = obj.get("session_id")
        events: list[AcpEvent] = []

        if kind == "system" and obj.get("subtype") == "init":
            events.append(
                AcpEvent(
                    AcpEventType.STATUS,
                    sid,
                    {
                        "phase": "init",
                        "model": obj.get("model"),
                        "tools": obj.get("tools"),
                        "cwd": obj.get("cwd"),
                    },
                )
            )
        elif kind == "assistant":
            for block in obj.get("message", {}).get("content", []):
                bt = block.get("type")
                if bt == "text" and block.get("text"):
                    events.append(
                        AcpEvent(
                            AcpEventType.MESSAGE,
                            sid,
                            {"role": "assistant", "text": block["text"]},
                        )
                    )
                elif bt == "tool_use":
                    events.append(
                        AcpEvent(
                            AcpEventType.TOOL_CALL,
                            sid,
                            {
                                "id": block.get("id"),
                                "name": block.get("name"),
                                "input": block.get("input"),
                            },
                        )
                    )
        elif kind == "user":
            for block in obj.get("message", {}).get("content", []):
                if block.get("type") == "tool_result":
                    events.append(
                        AcpEvent(
                            AcpEventType.TOOL_RESULT,
                            sid,
                            {
                                "tool_use_id": block.get("tool_use_id"),
                                "content": _flatten_text(block.get("content")),
                                "is_error": block.get("is_error", False),
                            },
                        )
                    )
        elif kind == "result":
            events.append(
                AcpEvent(
                    AcpEventType.SESSION_END,
                    sid,
                    {
                        "is_error": obj.get("is_error", False),
                        "result": obj.get("result"),
                        "cost_usd": obj.get("total_cost_usd"),
                    },
                )
            )
        return events


# Registry: backend name → adapter. New backends register here.
_ADAPTERS: dict[str, AgentAdapter] = {a.name: a for a in (ClaudeCodeAdapter(),)}


def get_adapter(name: str) -> AgentAdapter:
    if name not in _ADAPTERS:
        raise KeyError(f"no agent adapter for {name!r} (have {sorted(_ADAPTERS)})")
    return _ADAPTERS[name]


def available_adapters() -> list[str]:
    return sorted(_ADAPTERS)
