"""ACP-style structured events — the protocol surface the cockpit observes.

Not the full ACP JSON-RPC spec (decision bf5dc16b says "ACP *style*"): a minimal,
extensible event vocabulary that any backend adapter normalizes its native
output into, so the cockpit renders tool calls / plans / messages uniformly and
new backends only need a parser (no upper-layer changes).
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum


class AcpEventType(str, Enum):
    STATUS = "status"  # session lifecycle / init (model, tools, cwd)
    MESSAGE = "message"  # streamed assistant/user text
    TOOL_CALL = "tool_call"  # the agent invoked a tool
    TOOL_RESULT = "tool_result"  # a tool returned
    PLAN = "plan"  # a plan/todo update (backends that emit one)
    PERMISSION_REQUEST = "permission_request"  # blocked, awaiting user approval
    RATE_LIMIT = "rate_limit"  # backend reported rate-limit / credit status
    SESSION_END = "session_end"  # run finished (success/error)
    ERROR = "error"  # adapter/transport error


class RunStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    WAITING_PERMISSION = "waiting_permission"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class AcpEvent:
    """One normalized event. ``data`` carries type-specific fields; kept as a
    plain dict so it serializes straight to the WS/JSON without per-type schemas."""

    type: AcpEventType
    session_id: str | None
    data: dict = field(default_factory=dict)
    ts: float = field(default_factory=time.time)

    def to_dict(self) -> dict:
        return {
            "type": self.type.value,
            "session_id": self.session_id,
            "data": self.data,
            "ts": self.ts,
        }
