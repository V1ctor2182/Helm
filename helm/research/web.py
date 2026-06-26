"""Real web providers for the research engine: public web search (DuckDuckGo
HTML endpoint — no API key, constraint ad182edb) + page fetch→readable text.

Sync (the engine loop is sync; m3 runs it in a thread). httpx client is
injectable so tests drive them with a MockTransport — no real network/cost. The
fetched text is returned RAW; the engine wraps it as untrusted context
(constraint bd8d8f69) before it reaches the LLM.
"""

from __future__ import annotations

import re
import urllib.parse

import httpx

from helm.research.providers import SearchResult

_UA = "Mozilla/5.0 (Helm Research)"
_DDG_URL = "https://html.duckduckgo.com/html/"

# DDG result anchors: <a ... class="result__a" href="...">Title</a>
_RESULT_A = re.compile(
    r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)</a>', re.DOTALL
)
_SNIPPET = re.compile(
    r'class="result__snippet"[^>]*>(.*?)</a>', re.DOTALL
)
_TAGS = re.compile(r"<[^>]+>")
_WS = re.compile(r"\s+")


def _strip_tags(html: str) -> str:
    return _WS.sub(" ", _TAGS.sub(" ", html)).strip()


def _real_url(href: str) -> str:
    """DDG wraps targets as //duckduckgo.com/l/?uddg=<encoded>. Unwrap to the
    real destination; pass through plain hrefs."""
    if "uddg=" in href:
        q = urllib.parse.urlparse(href if "//" in href else "https:" + href).query
        params = urllib.parse.parse_qs(q)
        if params.get("uddg"):
            return params["uddg"][0]
    return href


class DuckDuckGoSearcher:
    def __init__(self, client: httpx.Client | None = None) -> None:
        self._client = client
        self._owned = client is None

    def search(self, query: str, limit: int = 5) -> list[SearchResult]:
        client = self._client or httpx.Client(timeout=15.0, headers={"User-Agent": _UA})
        try:
            resp = client.post(_DDG_URL, data={"q": query})
            resp.raise_for_status()
            return self._parse(resp.text, limit)
        finally:
            if self._owned:
                client.close()

    @staticmethod
    def _parse(html: str, limit: int) -> list[SearchResult]:
        anchors = _RESULT_A.findall(html)
        snippets = _SNIPPET.findall(html)
        out: list[SearchResult] = []
        for i, (href, title) in enumerate(anchors[:limit]):
            url = _real_url(href)
            if not url.startswith("http"):
                continue
            snippet = _strip_tags(snippets[i]) if i < len(snippets) else ""
            out.append(SearchResult(url=url, title=_strip_tags(title), snippet=snippet))
        return out


class HttpFetcher:
    def __init__(self, client: httpx.Client | None = None, max_chars: int = 20000) -> None:
        self._client = client
        self._owned = client is None
        self.max_chars = max_chars

    def fetch(self, url: str) -> str:
        client = self._client or httpx.Client(
            timeout=20.0, headers={"User-Agent": _UA}, follow_redirects=True
        )
        try:
            resp = client.get(url)
            resp.raise_for_status()
            return self._readable(resp.text)[: self.max_chars]
        except httpx.HTTPError:
            return ""  # a dead/blocked page must not kill the whole research run
        finally:
            if self._owned:
                client.close()

    @staticmethod
    def _readable(html: str) -> str:
        # Drop script/style/noscript wholesale, then strip remaining tags.
        html = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", html, flags=re.DOTALL | re.IGNORECASE)
        return _strip_tags(html)
