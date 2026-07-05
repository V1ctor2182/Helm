"""Today 右柱「世界输入」的新闻源(A×C v3 定稿,2026-07-05):
Hacker News 官方 Firebase API——免费、无 key、无条款问题。top 3 条,
进程内 10 分钟缓存;断网/超时安静返回空数组(简报柱显示占位,绝不炸页)。
"""

from __future__ import annotations

import asyncio
import time

import httpx
from fastapi import APIRouter

router = APIRouter(prefix="/api", tags=["briefing"])

_HN = "https://hacker-news.firebaseio.com/v0"
_CACHE_TTL_S = 600
_cache: dict = {"at": 0.0, "items": []}
_lock = asyncio.Lock()


def _ago(unix: int | None, now: float) -> str:
    if not unix:
        return ""
    m = int((now - unix) / 60)
    if m < 60:
        return f"{max(1, m)} 分钟前"
    if m < 60 * 24:
        return f"{m // 60} 小时前"
    return f"{m // (60 * 24)} 天前"


async def fetch_top(client: httpx.AsyncClient, limit: int = 3) -> list[dict]:
    ids = (await client.get(f"{_HN}/topstories.json", timeout=6)).json()[: limit * 2]
    now = time.time()
    items: list[dict] = []
    for sid in ids:
        try:
            it = (await client.get(f"{_HN}/item/{sid}.json", timeout=6)).json() or {}
        except httpx.HTTPError:
            continue
        title = it.get("title")
        if not title:
            continue
        items.append(
            {
                "title": title,
                "source": "Hacker News",
                "url": it.get("url") or f"https://news.ycombinator.com/item?id={sid}",
                "ago": _ago(it.get("time"), now),
            }
        )
        if len(items) >= limit:
            break
    return items


def _make_client() -> httpx.AsyncClient:  # 测试 monkeypatch 这里注入假 transport
    return httpx.AsyncClient()


@router.get("/briefing")
async def briefing() -> dict:
    """世界输入简报。缓存 10 分钟;失败安静降级为空。"""
    now = time.monotonic()
    if _cache["items"] and now - _cache["at"] < _CACHE_TTL_S:
        return {"items": _cache["items"]}
    async with _lock:
        if _cache["items"] and time.monotonic() - _cache["at"] < _CACHE_TTL_S:
            return {"items": _cache["items"]}
        client = _make_client()
        try:
            items = await fetch_top(client)
            _cache["items"] = items
            _cache["at"] = time.monotonic()
        except (httpx.HTTPError, ValueError, KeyError):
            items = _cache["items"]  # 旧缓存兜底,再没有就是空
        finally:
            await client.aclose()
    return {"items": items}


def reset_cache_for_tests() -> None:
    _cache["at"] = 0.0
    _cache["items"] = []
