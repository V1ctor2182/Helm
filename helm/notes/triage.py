"""速记分诊(T1,2026-07-08 设计定稿 helm-journal-kinds.html):规则判类 + 时间/地点双抽取。

规则先行(零延迟,与前端 CaptureDock/设计稿 demo 同一套口径),拿不准的
(confident=False)由 enrich 的 LLM 兜底改判。判出「任务」以 kind='task'
落库,直接进任务区「待办·给自己」列;抽取结果进 meta:
  when  人话时间标签(回执/待办 chip 直接显示,如「明晚 20:00」)
  where 地点(如「家」)
  due   可解析的绝对时刻,本地时间 ISO(前端 24h 临近橙 chip 判定用)
人话解析同时是 T2 人话排期的地基(recurring 结果给 agent 定时任务用)。
"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta

_NUMS = {"一": 1, "两": 2, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6,
         "七": 7, "八": 8, "九": 9, "十": 10, "十一": 11, "十二": 12}
_WEEKDAYS = {"一": 0, "二": 1, "三": 2, "四": 3, "五": 4, "六": 5, "日": 6, "天": 6}

# 「下午3点」「9点半」「18:30」「九点」——上/下午修饰 + 数字/中文钟点。
_CLOCK_RE = re.compile(
    r"(上午|早上|下午|晚上|中午)?\s*(\d{1,2}|[一二三四五六七八九十两]{1,2})\s*[点::](半|\d{1,2})?"
)
_RECUR_RE = re.compile(r"每天|每周[一二三四五六日天]?|每月|每 ?(\d+) ?(小时|分钟)")


def _num(s: str) -> int | None:
    if s.isdigit():
        return int(s)
    return _NUMS.get(s)


def _clock(text: str) -> tuple[int, int] | None:
    """文本里的第一个钟点 → (hour, minute),带上/下午修正;没有则 None。"""
    m = _CLOCK_RE.search(text)
    if not m:
        return None
    h = _num(m.group(2))
    if h is None or h > 24:
        return None
    ampm, mins = m.group(1), m.group(3)
    minute = 30 if mins == "半" else int(mins) if mins and mins.isdigit() else 0
    if ampm in ("下午", "晚上") and h < 12:
        h += 12
    if ampm == "中午" and h < 11:
        h += 12
    return (h % 24, minute % 60)


@dataclass
class When:
    label: str          # 人话标签,回执/待办 chip 直接显示
    due: str | None     # 本地时间 ISO;recurring/解析不出绝对时刻则 None
    recurring: bool = False


def parse_when(text: str, now: datetime | None = None) -> When | None:
    """人话时间 → 结构化。规则集覆盖设计稿口径(明早/明晚/今晚/明后天/
    周X/X点前/每天…);解析不出返回 None,绝不编造。"""
    now = now or datetime.now()
    clock = _clock(text)

    m = _RECUR_RE.search(text)
    if m:
        label = m.group(0).replace(" ", "")
        if clock:
            label += f" {clock[0]:02d}:{clock[1]:02d}"
        return When(label=label, due=None, recurring=True)

    def _at(day_offset: int, default: tuple[int, int], prefix: str,
            evening: bool = False) -> When:
        h, mi = clock or default
        if evening and h < 12:  # 「明晚8点」= 20:00,裸钟点补晚上语境
            h += 12
        due = (now + timedelta(days=day_offset)).replace(
            hour=h, minute=mi, second=0, microsecond=0)
        return When(label=f"{prefix} {h:02d}:{mi:02d}", due=due.isoformat())

    if re.search(r"明早|明天早上", text):
        return _at(1, (9, 0), "明早")
    if re.search(r"明晚|明天晚上", text):
        return _at(1, (20, 0), "明晚", evening=True)
    if "今晚" in text:
        return _at(0, (20, 0), "今晚", evening=True)
    if "后天" in text:
        return _at(2, (9, 0), "后天")
    if "明天" in text:
        return _at(1, (9, 0), "明天")

    m = re.search(r"(下周|下个?星期|周|星期)([一二三四五六日天])", text)
    if m and m.group(2) in _WEEKDAYS:
        wd = _WEEKDAYS[m.group(2)]
        offset = (wd - now.weekday()) % 7 or 7
        nxt = m.group(1).startswith("下")
        if nxt and offset < 7:
            offset += 7
        h, mi = clock or (9, 0)
        due = (now + timedelta(days=offset)).replace(
            hour=h, minute=mi, second=0, microsecond=0)
        return When(label=f"{'下周' if nxt else '周'}{m.group(2)} {h:02d}:{mi:02d}",
                    due=due.isoformat())

    if clock:
        h, mi = clock
        due = now.replace(hour=h, minute=mi, second=0, microsecond=0)
        day = "今天"
        if due <= now:
            due += timedelta(days=1)
            day = "明天"
        before = "前" if re.search(r"[点半分\d]\s*前", text) else ""
        return When(label=f"{day} {h:02d}:{mi:02d}{' 前' if before else ''}",
                    due=due.isoformat())
    return None


# 「在家」「@公司」「在图书馆见」;现/正/存/实在 不算地点。懒匹配 + 边界
# 前瞻(标点/句尾/常见动词),抽不出边界就放弃——宁缺毋滥,不吞动词。
_WHERE_RE = re.compile(
    r"(?:(?<![现正存实])在|@)([^\s,,。;;!!??点]{1,6}?)"
    r"(?=[\s,,。;;!!??]|$|[帮给把做开写跑买见和跟去拿交发回吃约])"
)


def parse_where(text: str) -> str | None:
    m = _WHERE_RE.search(text)
    return m.group(1) if m else None


# 判类触发词——与前端 CaptureDock(K7)/设计稿 demo 同一套,后端为准。
_TASKISH = re.compile(
    r"明早|明晚|今晚|明天|后天|下周|点前|之前完成|每天|每周|每月|提醒|记得|别忘|截止|deadline",
    re.IGNORECASE)
_IDEAISH = re.compile(r"也许|或许|说不定|要不要|想到|点子|灵感|如果.+就|可以试试")
_DIARYISH = re.compile(r"今天|终于|感觉|开心|难受|累|复盘|想了想|反思")
_URLISH = re.compile(r"https?://", re.IGNORECASE)


@dataclass
class Verdict:
    kind: str            # note|idea|journal|task(ask 不落 notes,由前端分流)
    when: str | None     # 人话时间标签
    where: str | None
    due: str | None      # 本地 ISO
    recurring: bool
    confident: bool      # False=规则兜不住,enrich LLM 可改判

    def public(self) -> dict:
        return asdict(self)


def triage_note(content: str, now: datetime | None = None) -> Verdict:
    """分诊一条速记。顺序与设计稿 demo 一致:链接→任务→想法→日记→速记。"""
    t = (content or "").strip()
    when = parse_when(t, now)
    where = parse_where(t)
    w_label = when.label if when else None
    w_due = when.due if when else None
    w_rec = when.recurring if when else False

    if _URLISH.search(t):
        return Verdict("note", w_label, where, w_due, w_rec, True)
    if _TASKISH.search(t):
        return Verdict("task", w_label, where, w_due, w_rec, True)
    if _IDEAISH.search(t):
        return Verdict("idea", w_label, where, w_due, w_rec, True)
    if len(t) > 14 and _DIARYISH.search(t):
        return Verdict("journal", w_label, where, w_due, w_rec, True)
    return Verdict("note", w_label, where, w_due, w_rec, False)
