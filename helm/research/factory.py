"""Assemble a ResearchEngine wired to real providers from a configured Helm
chat provider (the LLM) + DuckDuckGo search + HTTP fetch. The m3 run route
calls this; search/fetch are overridable for tests so assembly is verifiable
without hitting the network."""

from __future__ import annotations

from collections.abc import Callable

from sqlalchemy import select
from sqlalchemy.orm import Session

from helm.chat.models import Provider
from helm.chat.service import ProviderService
from helm.crypto import SecretBox
from helm.research.engine import ResearchEngine
from helm.research.llm import ChatLLM
from helm.research.providers import Fetcher, Searcher
from helm.research.web import DuckDuckGoSearcher, HttpFetcher


def build_engine(
    session: Session,
    box: SecretBox,
    provider_id: int,
    model: str,
    *,
    on_event: Callable[[str, dict], None] | None = None,
    searcher: Searcher | None = None,
    fetcher: Fetcher | None = None,
) -> ResearchEngine:
    provider = session.scalar(select(Provider).where(Provider.id == provider_id))
    if provider is None:
        raise KeyError(f"provider {provider_id} not found")
    key = ProviderService(session, box).api_key(provider_id)
    llm = ChatLLM(provider.type, provider.base_url, model, key)
    return ResearchEngine(
        searcher or DuckDuckGoSearcher(),
        fetcher or HttpFetcher(),
        llm,
        on_event=on_event,
    )
