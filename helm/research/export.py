"""Render a research report to Markdown for export (→ project file) and a
compact memory string (→ the brain, so the terminal agent reads it via MCP).
Both keep citations traceable to source URLs (constraint 180077c3)."""

from __future__ import annotations


def report_to_markdown(report: dict) -> str:
    sources = report.get("sources") or []
    url_idx = {s.get("url"): i + 1 for i, s in enumerate(sources)}

    lines = [f"# {report.get('question', 'Research')}", "", report.get("summary", ""), ""]

    claims = report.get("claims") or []
    if claims:
        lines.append("## 关键结论")
        lines.append("")
        for c in claims:
            cites = "".join(f"[{url_idx.get(u, '?')}]" for u in c.get("sources", []))
            lines.append(f"- {c.get('text', '')} {cites}".rstrip())
        lines.append("")

    if sources:
        lines.append("## 来源")
        lines.append("")
        for i, s in enumerate(sources):
            label = s.get("title") or s.get("url")
            lines.append(f"{i + 1}. [{label}]({s.get('url')})")
        lines.append("")

    lines.append(f"*迭代 {report.get('rounds', 0)} 轮*")
    return "\n".join(lines)


def report_to_memory_text(question: str, report: dict) -> str:
    """A one-paragraph memory the agent can recall: question + summary."""
    summary = (report.get("summary") or "").strip()
    return f"研究「{question}」的结论:{summary}"
