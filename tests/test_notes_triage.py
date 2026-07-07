"""T1 分诊管线:规则判类 / 人话时间 / 地点抽取 / POST 分诊落库 / LLM 兜底改判。

设计基线 docs/design/helm-journal-kinds.html(2026-07-08 定稿):分诊类别
速记/想法/日记/任务(收藏=带链接的速记,enrich 层负责);判任务落
「待办·给自己」(kind='task' 即前端待办列);时间/地点双抽取进 meta。
"""

from __future__ import annotations

from datetime import date, datetime

from fastapi.testclient import TestClient

from helm.app import create_app
from helm.notes.triage import parse_when, parse_where, triage_note

# 2026-07-08 是周三,固定 now 让排期断言确定。
NOW = datetime(2026, 7, 8, 15, 0)


# ── 人话时间 ────────────────────────────────────────────────────────────

def test_parse_when_tomorrow_morning() -> None:
    w = parse_when("明早9点跑回归", NOW)
    assert w and w.label == "明早 09:00" and not w.recurring
    assert w.due == "2026-07-09T09:00:00"


def test_parse_when_tomorrow_evening_bare_clock_gets_pm() -> None:
    w = parse_when("明晚8点在家帮荣荣姐做龙虾", NOW)
    assert w and w.label == "明晚 20:00" and w.due == "2026-07-09T20:00:00"


def test_parse_when_tonight_default() -> None:
    w = parse_when("今晚提交报告", NOW)
    assert w and w.label == "今晚 20:00" and w.due == "2026-07-08T20:00:00"


def test_parse_when_weekday_with_pm() -> None:
    w = parse_when("周五下午3点 review notch PR", NOW)
    assert w and w.label == "周五 15:00" and w.due == "2026-07-10T15:00:00"


def test_parse_when_next_week() -> None:
    w = parse_when("下周三过方案", NOW)  # 今天周三 → 下周三 = +7 天
    assert w and w.label == "下周三 09:00" and w.due == "2026-07-15T09:00:00"


def test_parse_when_recurring_no_due() -> None:
    w = parse_when("每天早上9点汇总未读邮件", NOW)
    assert w and w.recurring and w.due is None and w.label == "每天 09:00"


def test_parse_when_deadline_today() -> None:
    w = parse_when("18点前把草稿交了", NOW)
    assert w and w.due == "2026-07-08T18:00:00" and "前" in w.label


def test_parse_when_none_when_no_time() -> None:
    assert parse_when("御树林餐厅的味道不错", NOW) is None


# ── 地点 ────────────────────────────────────────────────────────────────

def test_parse_where_stops_before_verb() -> None:
    assert parse_where("明晚8点在家帮荣荣姐做龙虾") == "家"
    assert parse_where("@公司 过一下方案") == "公司"
    assert parse_where("在图书馆见") == "图书馆"


def test_parse_where_ignores_xianzai() -> None:
    assert parse_where("现在开始专注") is None


# ── 判类(顺序:链接→任务→想法→日记→速记) ─────────────────────────────

def test_triage_task_with_double_extraction() -> None:
    v = triage_note("明晚8点在家帮荣荣姐做龙虾", NOW)
    assert v.kind == "task" and v.confident
    assert v.when == "明晚 20:00" and v.where == "家" and v.due is not None


def test_triage_idea() -> None:
    v = triage_note("要不要给 notch 加一个入场动效", NOW)
    assert v.kind == "idea" and v.confident


def test_triage_task_beats_idea() -> None:
    assert triage_note("要不要明天问一下论文作者", NOW).kind == "task"


def test_triage_journal_narrative() -> None:
    v = triage_note("今天终于把三态稿定下来了,感觉很顺", NOW)
    assert v.kind == "journal" and v.confident


def test_triage_url_is_note() -> None:
    v = triage_note("https://arxiv.org/abs/2406.01234 读一下", NOW)
    assert v.kind == "note" and v.confident


def test_triage_fallback_note_not_confident() -> None:
    v = triage_note("御树林餐厅的味道不错", NOW)
    assert v.kind == "note" and not v.confident


# ── API:POST 分诊落库 ──────────────────────────────────────────────────

def test_post_triage_task_lands_in_todo(config) -> None:
    c = TestClient(create_app(config))
    r = c.post("/api/notes", json={
        "content": "明晚8点在家帮荣荣姐做龙虾", "source": "capture", "triage": True})
    assert r.status_code == 200
    n = r.json()
    assert n["kind"] == "task"                       # 待办·给自己 = notes kind:task
    assert n["triage"]["kind"] == "task"             # 结构化回执
    assert n["meta"]["when"] == "明晚 20:00" and n["meta"]["where"] == "家"
    assert n["meta"]["due"].startswith("20")
    assert n["meta"]["triage"] == {"by": "rule", "confident": True}
    todos = c.get("/api/notes", params={"kind": "task"}).json()["notes"]
    assert [t["id"] for t in todos] == [n["id"]]


def test_post_triage_journal_gets_today(config) -> None:
    c = TestClient(create_app(config))
    n = c.post("/api/notes", json={
        "content": "今天终于把三态稿定下来了,感觉很顺", "triage": True}).json()
    assert n["kind"] == "journal"
    assert n["journal_date"] == date.today().isoformat()


def test_post_triage_uncertain_marked_for_llm(config) -> None:
    c = TestClient(create_app(config))
    n = c.post("/api/notes", json={"content": "御树林餐厅的味道不错", "triage": True}).json()
    assert n["kind"] == "note"
    assert n["meta"]["triage"] == {"by": "rule", "confident": False}


def test_post_task_and_idea_kinds_accepted(config) -> None:
    """422 回归守卫:捕获坞/notch「给自己的任务」直接落 kind:task;想法同理。"""
    c = TestClient(create_app(config))
    assert c.post("/api/notes", json={"content": "回复邮件", "kind": "task"}).status_code == 200
    assert c.post("/api/notes", json={"content": "一个点子", "kind": "idea"}).status_code == 200


def test_patch_reclass_flows_back(config) -> None:
    """回执「改」:PATCH kind 纠正分诊结果。"""
    c = TestClient(create_app(config))
    n = c.post("/api/notes", json={"content": "明天整理桌面", "triage": True}).json()
    assert n["kind"] == "task"
    assert c.patch(f"/api/notes/{n['id']}", json={"kind": "note"}).json()["kind"] == "note"


# ── enrich LLM 兜底改判 ─────────────────────────────────────────────────

def test_enrich_llm_fallback_upgrades_kind(config, monkeypatch) -> None:
    """规则拿不准(confident=False)→ enrich 的 LLM 判 idea,kind 升格,
    规则种子保留;by 记 llm。"""
    import helm.ai as ai_mod

    monkeypatch.setattr(ai_mod, "pick_provider", lambda s, b: object())

    async def fake_llm(session, box, provider, system, user, cwd=None):
        return '{"title":"餐厅点子","kind":"idea","tags":["吃"],"where":"御树林"}'

    monkeypatch.setattr(ai_mod, "llm_once", fake_llm)
    c = TestClient(create_app(config))
    n = c.post("/api/notes", json={"content": "御树林餐厅的味道不错", "triage": True}).json()
    got = c.get(f"/api/notes").json()["notes"]
    cur = next(x for x in got if x["id"] == n["id"])
    assert cur["kind"] == "idea"
    assert cur["meta"]["triage"] == {"by": "llm", "confident": True}
    assert cur["meta"]["where"] == "御树林"


def test_enrich_llm_does_not_override_confident_rule(config, monkeypatch) -> None:
    """规则已确定(task)→ LLM 无权改判;种子 when/where 不被覆盖。"""
    import helm.ai as ai_mod

    monkeypatch.setattr(ai_mod, "pick_provider", lambda s, b: object())

    async def fake_llm(session, box, provider, system, user, cwd=None):
        return '{"kind":"journal","when":"LLM 的时间","title":"T"}'

    monkeypatch.setattr(ai_mod, "llm_once", fake_llm)
    c = TestClient(create_app(config))
    n = c.post("/api/notes", json={
        "content": "明晚8点在家帮荣荣姐做龙虾", "triage": True}).json()
    got = c.get("/api/notes", params={"kind": "task"}).json()["notes"]
    cur = next(x for x in got if x["id"] == n["id"])
    assert cur["kind"] == "task"                     # 没被 LLM 拽走
    assert cur["meta"]["when"] == "明晚 20:00"        # 规则种子优先
    assert cur["meta"]["triage"] == {"by": "rule", "confident": True}
