"""人话排期(T2,2026-07-08 稿):整句自然语言 → schedule_kind/schedule_value。

设计稿口径:排期不用 cron,用人话说——「每天早上 9 点汇总未读邮件」整句
进来,解析出排期;cron 表达式从 UI 全面退场(存储层不变,仍是 at|every|cron
三模式,见 decision 894165f7)。原句留在 task.prompt;解析出的人话标签存
schedule_value.nl,前端排期 chip 直接显示。钟点/一次性时间复用 T1 分诊的
解析(helm.notes.triage),一套人话时间两处用。
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime

from helm.notes.triage import _clock, parse_when


@dataclass
class Parsed:
    label: str   # 人话标签(「每天 09:00」),排期 chip 直接显示
    kind: str    # at | every | cron
    value: dict  # compute_next_run 吃的 value,外加 nl=label


def parse_schedule(text: str, now: datetime | None = None) -> Parsed | None:
    """人话 → 排期。解析不出返回 None(调用方 422 提示补时间),不编造。"""
    t = (text or "").strip()
    if not t:
        return None
    clock = _clock(t)

    m = re.search(r"每 ?(\d+) ?(小时|分钟)", t)
    if m:
        n = int(m.group(1))
        if n <= 0:
            return None
        label = f"每 {n} {m.group(2)}"
        secs = n * 3600 if m.group(2) == "小时" else n * 60
        return Parsed(label, "every", {"seconds": secs, "nl": label})

    def _cron(default_h: int, *, dow: str = "*", dom: str = "*",
              prefix: str, evening: bool = False) -> Parsed:
        h, mi = clock or (default_h, 0)
        if evening and h < 12:  # 「每晚8点」= 20:00
            h += 12
        label = f"{prefix} {h:02d}:{mi:02d}"
        return Parsed(label, "cron", {"expr": f"{mi} {h} {dom} * {dow}", "nl": label})

    if re.search(r"每个?工作日", t):
        return _cron(9, dow="1-5", prefix="工作日")
    m = re.search(r"每(?:周|星期)([一二三四五六日天])", t)
    if m:
        zh = m.group(1)
        dow = 0 if zh in "日天" else "一二三四五六".index(zh) + 1  # 标准 cron:0=周日
        return _cron(9, dow=str(dow), prefix=f"每周{zh}", evening="晚" in t)
    if re.search(r"每(?:周|星期)", t):  # 「每周回顾」没说哪天 → 周一(注明,可纠)
        return _cron(9, dow="1", prefix="每周一")
    if re.search(r"每晚|每天晚上", t):
        return _cron(20, prefix="每晚", evening=True)
    if re.search(r"每早|每天早上|每天|每日", t):
        return _cron(9, prefix="每天")
    m = re.search(r"每月\s*(\d{1,2})?\s*号?", t)
    if m:
        dom = int(m.group(1) or 1)
        return _cron(9, dom=str(dom), prefix=f"每月 {dom} 号")

    # 一次性:「明早 9 点」「周五下午 3 点」→ at(本地时刻转带时区 ISO)
    w = parse_when(t, now)
    if w and w.due and not w.recurring:
        aware = datetime.fromisoformat(w.due).astimezone()
        return Parsed(w.label, "at", {"at": aware.isoformat(), "nl": w.label})
    return None
