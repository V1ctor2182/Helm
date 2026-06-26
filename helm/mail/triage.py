"""AI email triage (intent#1: 紧急度 / 摘要 / 标签 / 垃圾识别 / 回复草稿).
Pure given an LLM — the route wires a chat provider; tests inject a fake."""

from __future__ import annotations

from helm.research.engine import _extract_json  # shared robust JSON extractor

TRIAGE_PROMPT = """你是邮件助理,对下面这封邮件做分诊。判断:
- urgency: high | medium | low(需要尽快处理的程度)
- is_spam: true | false(是否垃圾/推广)
- summary: 一句话中文摘要
- labels: 0-3 个简短标签(如 工作/账单/通知/个人)
- draft: 一段简短得体的中文回复草稿;若是垃圾或纯通知无需回复,给空字符串

邮件:
发件人: {from_addr}
主题: {subject}
正文:
{body}

只输出 JSON,形如:
{{"urgency":"medium","is_spam":false,"summary":"...","labels":["工作"],"draft":"..."}}"""

_URGENCY = {"high", "medium", "low"}


def triage_email(email, llm) -> dict:
    """Return a normalized triage dict — always valid, even if the LLM returns
    junk (defaults to a safe low-urgency, non-spam, no-draft result)."""
    raw = llm.complete(
        TRIAGE_PROMPT.format(
            from_addr=email.from_addr,
            subject=email.subject,
            body=(email.body or "")[:4000],
        )
    )
    out = _extract_json(raw)
    data = out if isinstance(out, dict) else {}
    urgency = str(data.get("urgency", "low")).lower()
    labels = data.get("labels")
    return {
        "urgency": urgency if urgency in _URGENCY else "low",
        "is_spam": bool(data.get("is_spam", False)),
        "summary": str(data.get("summary", "")).strip(),
        "labels": [str(x) for x in labels][:3] if isinstance(labels, list) else [],
        "draft": str(data.get("draft", "")).strip(),
    }
