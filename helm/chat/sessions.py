"""Chat session + message persistence (drives streaming chat + restore)."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.chat.models import ChatSession, Message


class ChatService:
    def __init__(self, session: Session) -> None:
        self._s = session

    def create_session(
        self,
        provider_id: int,
        model: str,
        system_prompt: str | None = None,
        title: str | None = None,
        project_path: str | None = None,
    ) -> ChatSession:
        row = ChatSession(
            provider_id=provider_id,
            model=model,
            system_prompt=system_prompt,
            title=title,
            project_path=project_path,
        )
        self._s.add(row)
        self._s.flush()
        return row

    def list_sessions(self) -> list[ChatSession]:
        return list(
            self._s.execute(
                select(ChatSession).order_by(ChatSession.created_at.desc())
            ).scalars()
        )

    def get_session(self, session_id: int) -> ChatSession | None:
        return self._s.get(ChatSession, session_id)

    def messages(self, session_id: int) -> list[Message]:
        return list(
            self._s.execute(
                select(Message).where(Message.session_id == session_id).order_by(Message.id)
            ).scalars()
        )

    def add_message(self, session_id: int, role: str, content: str) -> Message:
        row = Message(session_id=session_id, role=role, content=content)
        self._s.add(row)
        self._s.flush()
        return row

    def delete_session(self, session_id: int) -> bool:
        """Delete a session and its messages. Returns False if it doesn't exist."""
        row = self._s.get(ChatSession, session_id)
        if row is None:
            return False
        for m in self.messages(session_id):
            self._s.delete(m)
        # 没有 ORM relationship 帮忙排序,先 flush 子行再删父行,否则 FK 崩。
        self._s.flush()
        self._s.delete(row)
        self._s.flush()
        return True


def session_public(s: ChatSession) -> dict:
    return {
        "id": s.id,
        "kind": s.kind,
        "title": s.title,
        "project_path": s.project_path,
        "provider_id": s.provider_id,
        "model": s.model,
        "system_prompt": s.system_prompt,
    }


def message_public(m: Message) -> dict:
    return {"id": m.id, "role": m.role, "content": m.content}
