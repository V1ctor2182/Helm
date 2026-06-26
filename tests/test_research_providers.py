"""m2 (deep-research): real web/LLM providers, driven by httpx MockTransport —
no real search/fetch/LLM call (those are paid/external; live verify is manual)."""

import httpx

from helm.research.llm import ChatLLM
from helm.research.web import DuckDuckGoSearcher, HttpFetcher

# A realistic slice of DuckDuckGo's HTML result markup.
DDG_HTML = """
<div class="result">
  <a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fa&amp;rut=x">First <b>Result</b></a>
  <a class="result__snippet" href="x">A snippet about <b>the</b> first result.</a>
</div>
<div class="result">
  <a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fb">Second Result</a>
  <a class="result__snippet" href="y">Second snippet.</a>
</div>
"""


def _client(handler) -> httpx.Client:
    return httpx.Client(transport=httpx.MockTransport(handler))


def test_ddg_searcher_parses_results():
    def handler(req: httpx.Request) -> httpx.Response:
        assert req.url.host == "html.duckduckgo.com"
        assert b"q=" in req.content  # query posted as form data
        return httpx.Response(200, text=DDG_HTML)

    results = DuckDuckGoSearcher(client=_client(handler)).search("some query", limit=5)
    assert [r.url for r in results] == ["https://example.com/a", "https://example.org/b"]
    assert results[0].title == "First Result"  # tags stripped
    assert "first result" in results[0].snippet


def test_ddg_searcher_respects_limit():
    def handler(req):
        return httpx.Response(200, text=DDG_HTML)

    assert len(DuckDuckGoSearcher(client=_client(handler)).search("q", limit=1)) == 1


def test_http_fetcher_strips_scripts_and_tags():
    page = "<html><head><style>.x{}</style></head><body><script>evil()</script><p>Hello <b>world</b></p></body></html>"

    def handler(req):
        return httpx.Response(200, text=page)

    text = HttpFetcher(client=_client(handler)).fetch("https://x.com")
    assert "Hello world" in text
    assert "evil()" not in text and ".x{}" not in text


def test_http_fetcher_swallows_errors():
    def handler(req):
        return httpx.Response(500)

    assert HttpFetcher(client=_client(handler)).fetch("https://x.com") == ""


def test_chat_llm_openai_shape():
    seen = {}

    def handler(req: httpx.Request) -> httpx.Response:
        seen["url"] = str(req.url)
        seen["auth"] = req.headers.get("authorization")
        import json as _j
        seen["body"] = _j.loads(req.content)
        return httpx.Response(200, json={"choices": [{"message": {"content": "the answer"}}]})

    llm = ChatLLM("openai", "https://api.openai.com/v1", "gpt-4o", "sk-KEY", client=_client(handler))
    out = llm.complete("a prompt", system="sys instructions")
    assert out == "the answer"
    assert seen["url"].endswith("/chat/completions")
    assert seen["auth"] == "Bearer sk-KEY"
    assert seen["body"]["messages"][0] == {"role": "system", "content": "sys instructions"}


def test_build_engine_wires_provider_llm(config):
    import pytest
    from helm.chat.service import ProviderService
    from helm.crypto import SecretBox
    from helm.db import Database
    from helm.research.factory import build_engine
    from helm.research.engine import ResearchEngine
    from helm.research.llm import ChatLLM

    db = Database.from_data_dir(config.data_dir)
    db.create_all()
    box = SecretBox.from_data_dir(config.data_dir)
    with db.session_scope() as s:
        p = ProviderService(s, box).create(
            type="openai", name="O", base_url="https://api.openai.com/v1",
            api_key="sk-SECRET", models=["gpt-4o"],
        )
        pid = p.id
    with db.session_scope() as s:
        # inject fakes for search/fetch so no real network even if run
        eng = build_engine(s, box, pid, "gpt-4o", searcher=object(), fetcher=object())
        assert isinstance(eng, ResearchEngine)
        assert isinstance(eng.llm, ChatLLM)
        assert eng.llm.model == "gpt-4o" and eng.llm.api_key == "sk-SECRET"
    with db.session_scope() as s:
        with pytest.raises(KeyError):
            build_engine(s, box, 9999, "m")


def test_chat_llm_anthropic_shape():
    seen = {}

    def handler(req: httpx.Request) -> httpx.Response:
        seen["url"] = str(req.url)
        seen["key"] = req.headers.get("x-api-key")
        import json as _j
        seen["body"] = _j.loads(req.content)
        return httpx.Response(200, json={"content": [{"type": "text", "text": "claude says hi"}]})

    llm = ChatLLM("anthropic", "https://api.anthropic.com", "claude-opus-4-8", "sk-ant", client=_client(handler))
    out = llm.complete("q", system="untrusted wrap")
    assert out == "claude says hi"
    assert seen["url"].endswith("/v1/messages")
    assert seen["key"] == "sk-ant"
    assert seen["body"]["system"] == "untrusted wrap"
