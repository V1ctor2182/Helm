"""AI journal summary (intent#2: 「今日小结」/ 周月回顾). Pure given an LLM —
the route wires a real chat provider; tests inject a fake."""

from __future__ import annotations

SUMMARY_PROMPT = """为下面这一天的日记条目写一段简洁的「今日小结」(2-4 句,中文),\
提炼当天要点、进展与情绪基调,不要逐条复述。

日记条目:
{entries}

只输出小结正文,不要前缀。"""


def summarize_journal(entries: list[str], llm) -> str:
    """Summarize a day's journal entries via the LLM. Empty when no entries."""
    cleaned = [e.strip() for e in entries if e and e.strip()]
    if not cleaned:
        return ""
    body = "\n---\n".join(cleaned)
    return llm.complete(SUMMARY_PROMPT.format(entries=body)).strip()
