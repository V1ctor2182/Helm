"""速记 AI 管线(2026-07-06 用户拍板):链接 parse + AI 优化。

用户随手丢进来的东西(YouTube / 论文 / 网站 / UI·UX 灵感链接 / 纯文本),
发送后在后台跑一遍 enrichment,结果落 ``notes.meta_json``,记录页据此
渲染预览卡(标题/摘要/缩略图/来源)。三层,逐层优雅降级:

1. 抓取层(无 key,全标准姿势):
   - YouTube → oEmbed(官方端点,免鉴权):标题/作者/封面
   - arXiv   → export API(Atom):标题/摘要/作者
   - 其余    → 页面 OpenGraph/<title> 元数据(截 512KB,8s 超时)
2. LLM 层(走全局 AI provider,见 helm.ai):分类 + 2-3 句中文摘要 + 标签;
   纯文本则轻整理(标题 + 标签 + 时间/地点线索)。没配 provider → 跳过。
3. 全失败 → meta 里至少落 {type, url},卡片仍能显示链接。
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from datetime import datetime as _dt
from html import unescape
from typing import Any

import httpx

log = logging.getLogger(__name__)

# 只吃 URL 合法 ASCII 字符——中文紧跟在链接后(如「…01234,读一下」)不会被吞进来。
URL_RE = re.compile(r"https?://[A-Za-z0-9\-._~:/?#@!$&'()*+,;=%\[\]]+", re.IGNORECASE)
_FETCH_LIMIT = 512 * 1024
_TIMEOUT = 8.0
_UA = {"User-Agent": "Mozilla/5.0 (Macintosh) HelmNotes/0.1 (+local)"}


def first_url(text: str) -> str | None:
    m = URL_RE.search(text or "")
    return m.group(0).rstrip(".,;:!?、。") if m else None


def all_urls(text: str, limit: int = 5) -> list[str]:
    """一段话里的全部链接(K3 多链接解析),去重保序,上限防滥用。"""
    seen: list[str] = []
    for m in URL_RE.finditer(text or ""):
        u = m.group(0).rstrip(".,;:!?、。")
        if u not in seen:
            seen.append(u)
        if len(seen) >= limit:
            break
    return seen


def _meta_tag(html: str, prop: str) -> str | None:
    # property/name 两种写法、属性顺序两种排列都接住(正则够用,不引解析器)。
    for pat in (
        rf'<meta[^>]+(?:property|name)=["\']{re.escape(prop)}["\'][^>]+content=["\']([^"\']*)["\']',
        rf'<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']{re.escape(prop)}["\']',
    ):
        m = re.search(pat, html, re.IGNORECASE)
        if m and m.group(1).strip():
            return unescape(m.group(1).strip())
    return None


async def _fetch_text(client: httpx.AsyncClient, url: str, **kw: Any) -> str:
    async with client.stream("GET", url, timeout=_TIMEOUT, headers=_UA,
                             follow_redirects=True, **kw) as r:
        r.raise_for_status()
        buf: list[bytes] = []
        size = 0
        async for chunk in r.aiter_bytes():
            buf.append(chunk)
            size += len(chunk)
            if size >= _FETCH_LIMIT:
                break
        return b"".join(buf).decode(r.encoding or "utf-8", errors="replace")


async def fetch_link_meta(url: str, client: httpx.AsyncClient | None = None) -> dict:
    """抓取层:按域名路由到 oEmbed / arXiv / OpenGraph,失败返回最小 meta。"""
    own = client is None
    client = client or httpx.AsyncClient()
    meta: dict[str, Any] = {"url": url}
    try:
        host = httpx.URL(url).host or ""
        if "youtube.com" in host or "youtu.be" in host:
            r = await client.get(
                "https://www.youtube.com/oembed",
                params={"url": url, "format": "json"},
                timeout=_TIMEOUT, headers=_UA)
            r.raise_for_status()
            d = r.json()
            meta.update(type="youtube", title=d.get("title"),
                        site=d.get("author_name"), image=d.get("thumbnail_url"))
        elif "arxiv.org" in host:
            m = re.search(r"(\d{4}\.\d{4,5})(v\d+)?", url)
            if m:
                r = await client.get(
                    "https://export.arxiv.org/api/query",
                    params={"id_list": m.group(1)}, timeout=_TIMEOUT, headers=_UA)
                r.raise_for_status()
                # feed 级 <title> 是查询描述("ArXiv Query: …")——只看 <entry> 内。
                xml = r.text.split("<entry", 1)[-1]
                title = re.search(r"<title>\s*([^<]+?)\s*</title>", xml)
                summ = re.search(r"<summary>\s*([\s\S]*?)</summary>", xml)
                meta.update(
                    type="paper", site="arXiv",
                    title=unescape(title.group(1).strip()) if title else None,
                    abstract=re.sub(r"\s+", " ", unescape(summ.group(1))).strip()[:2000] if summ else None)
        if "type" not in meta:
            html_text = await _fetch_text(client, url)
            title = (_meta_tag(html_text, "og:title")
                     or (lambda m: unescape(m.group(1).strip()) if m else None)(
                         re.search(r"<title[^>]*>([^<]+)</title>", html_text, re.IGNORECASE)))
            meta.update(
                type="article",
                title=title,
                summary_raw=_meta_tag(html_text, "og:description")
                or _meta_tag(html_text, "description"),
                image=_meta_tag(html_text, "og:image"),
                site=_meta_tag(html_text, "og:site_name") or host)
    except Exception as exc:  # 抓不到就抓不到,卡片仍显示裸链接
        log.info("link meta fetch failed for %s: %s", url, exc)
        meta.setdefault("type", "article")
    finally:
        if own:
            await client.aclose()
    return meta


_LINK_SYSTEM = (
    "你是 Helm 的收藏解析器。根据给出的链接元数据(可能不全)输出 JSON:"
    '{"type":"youtube|paper|article|inspiration","summary":"2-3 句中文,讲清这是什么、为什么值得看",'
    '"tags":["≤3个中文短标签"],"topic":"2-6字的主题集合名(如 Transformer 学习/设计灵感),不确定给 null"}。'
    "UI/UX/设计/作品集类判为 inspiration。只输出 JSON。"
)
_TEXT_SYSTEM = (
    "你是 Helm 的速记整理器。把用户随手记的一条整理成 JSON:"
    '{"title":"≤12字标题","tags":["≤3个中文短标签"],"when":"文中提到的时间线索,无则null",'
    '"where":"文中提到的地点线索,无则null",'
    '"topic":"2-6字的主题集合名(把相关记录归到同一集合,如 Transformer 学习),不确定给 null",'
    '"kind":"note|idea|task|journal 之一——task=要做的事(常带时间),idea=点子/假设,'
    'journal=当天叙事,其余 note"}。'
    "不改写原文,只输出 JSON。"
)


def _parse_llm_json(raw: str) -> dict:
    m = re.search(r"\{[\s\S]*\}", raw)
    if not m:
        return {}
    try:
        d = json.loads(m.group(0))
        return d if isinstance(d, dict) else {}
    except json.JSONDecodeError:
        return {}


async def enrich_note(db: Any, box: Any, note_id: int, cwd: Any = None) -> None:
    """后台任务入口:抓取 + LLM,结果写回 notes.meta_json。

    ``db``/``box`` 由路由自 ``app.state`` 捕获传入(请求返回后独立开 session);
    任何一步失败都降级,绝不让速记丢失。
    """
    from helm.ai import llm_once, pick_provider  # 延迟导入避环
    from helm.notes.models import Note

    def _write(meta: dict[str, Any], new_kind: str | None = None) -> None:
        clean = {k: v for k, v in meta.items() if k not in ("summary_raw", "abstract") and v}
        if not clean:
            return
        with db.session_scope() as s:
            n = s.get(Note, note_id)
            if n is None:
                return
            n.meta_json = json.dumps(clean, ensure_ascii=False)
            if not n.title and clean.get("title"):
                n.title = str(clean["title"])[:200]
            # T1 LLM 兜底改判:只从未定态(note)升格——用户 enrich 期间手动
            # 改过类(PATCH)就不覆盖。
            if new_kind and n.kind == "note":
                n.kind = new_kind
                if new_kind == "journal" and n.journal_date is None:
                    n.journal_date = (n.created_at or _dt.now()).date()
            s.commit()

    # 请求事务 commit(依赖 teardown)与 background 的先后顺序不做假设——
    # note 还看不见就短重试等它落库(实测有时 background 先于 teardown 跑)。
    content = ""
    kind = ""
    meta0: dict[str, Any] = {}  # T1 分诊的规则种子(when/where/due/triage),合并不覆盖
    for _ in range(10):
        with db.session_scope() as session:
            note = session.get(Note, note_id)
            if note is not None:
                content = note.content or ""
                kind = note.kind
                try:
                    meta0 = json.loads(note.meta_json) if note.meta_json else {}
                except json.JSONDecodeError:
                    meta0 = {}
                break
        await asyncio.sleep(0.3)
    else:
        return
    if kind == "journal":  # 日记不动(用户:除日记外)
        return
    urls = all_urls(content)
    url = urls[0] if urls else None
    meta: dict[str, Any] = {}
    new_kind: str | None = None

    # 第一段:抓取层立刻落库——卡片先有标题/封面,LLM 再慢也不拖累展示。
    # K3 多链接:每个 URL 各抓一份,links=全部;顶层字段=第一个(向后兼容 notch/旧前端)。
    if urls:
        links: list[dict[str, Any]] = []
        for u in urls:
            lm = await fetch_link_meta(u)
            if lm.get("summary_raw") and "summary" not in lm:
                lm["summary"] = lm["summary_raw"]
            if lm.get("abstract") and "summary" not in lm:
                lm["summary"] = lm["abstract"][:300]
            links.append({k: v for k, v in lm.items() if k in ("url", "type", "title", "summary", "image", "site") and v})
        meta = {**meta0, **links[0]}
        if len(links) > 1:
            meta["links"] = links
        _write(meta)

    # 第二段:LLM 补分类/摘要/标签(90s 超时,失败保留第一段)。
    with db.session_scope() as session:
        provider = pick_provider(session, box)
        if provider is None:
            return
        try:
            if url:
                user = f"链接: {url}\n元数据: {json.dumps(meta, ensure_ascii=False)}\n用户原话: {content}"
                d = _parse_llm_json(await asyncio.wait_for(llm_once(
                    session, box, provider, system=_LINK_SYSTEM, user=user, cwd=cwd), 90))
                if d.get("type") in {"youtube", "paper", "article", "inspiration"}:
                    meta["type"] = d["type"]
                if d.get("summary"):
                    meta["summary"] = str(d["summary"])[:600]
                if isinstance(d.get("tags"), list):
                    meta["tags"] = [str(t)[:24] for t in d["tags"][:3]]
                if d.get("topic"):
                    meta["topic"] = str(d["topic"])[:24]
            else:
                d = _parse_llm_json(await asyncio.wait_for(llm_once(
                    session, box, provider, system=_TEXT_SYSTEM, user=content, cwd=cwd), 90))
                if d:
                    meta = {**meta0, "type": "text"}
                    # 规则种子(when/where)优先——确定性抽取不被 LLM 覆盖,只补空。
                    for k in ("title", "when", "where"):
                        if d.get(k) and not meta.get(k):
                            meta[k] = str(d[k])[:120]
                    if isinstance(d.get("tags"), list):
                        meta["tags"] = [str(t)[:24] for t in d["tags"][:3]]
                    if d.get("topic"):
                        meta["topic"] = str(d["topic"])[:24]
                    # T1 LLM 兜底改判:仅当规则分诊拿不准(confident=False)。
                    lk = str(d.get("kind") or "")
                    if ((meta0.get("triage") or {}).get("confident") is False
                            and lk in ("idea", "task", "journal")):
                        new_kind = lk
                        meta["triage"] = {"by": "llm", "confident": True}
        except Exception as exc:  # LLM 失败/超时 → 保留第一段结果
            log.info("llm enrich failed for note %s: %s", note_id, exc)
            return
    _write(meta, new_kind)
