"""Injectable providers the research engine drives. Real implementations (web
search, page fetch, LLM via Helm's chat providers) land in m2; the engine and
its tests only depend on these Protocols, so the loop is verifiable with fakes
(no network/LLM/cost)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass
class SearchResult:
    url: str
    title: str = ""
    snippet: str = ""


class Searcher(Protocol):
    def search(self, query: str, limit: int = 5) -> list[SearchResult]: ...


class Fetcher(Protocol):
    def fetch(self, url: str) -> str:
        """Return the readable text of a page (raw, UNTRUSTED — the engine wraps
        it as untrusted context before handing it to the LLM, constraint
        bd8d8f69)."""
        ...


class LLM(Protocol):
    def complete(self, prompt: str, system: str | None = None) -> str: ...
