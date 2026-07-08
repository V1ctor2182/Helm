# 主 app NOMI loop · 批次 3 终报(2026-07-08)

分支 `feat/nomi-kinds` · 设计基线 `docs/design/helm-journal-kinds.html`(只读)· 全部块绿门通过,PR 留用户合。

## 交付(5 块 5 commits)

| 块 | commit | 内容 |
|---|---|---|
| T1 后端分诊管线 | de9d806 | triage.py 规则判类+时间/地点双抽取;KINDS 收编 task/idea;POST triage:true+回执块;enrich LLM 兜底改判(confident=False 才升格);meta 合并不覆盖 |
| T2 人话排期 | ef5e76a | tasks/nl.py 整句→schedule;POST /api/tasks {prompt} 即可;/parse 实时徽章;派发条三模式表单退场;人话 chip(schedule_value.nl);cron 表达式退出 UI |
| T3 前端对齐 kinds 稿 | 1bd9e8b | 捕获坞自动挡走后端分诊+回执 toast(chips+改类回流);速记墙想法徽章/任务回执卡(橙左沿+已入待办→);待办两层任务行(24h 橙 chip/hover 操作/临近在上) |
| T4 日记每天一篇 | 28eef3f | 天内段落升序拼一篇(纸页/PageDetail 单源);Today 卡全文预览+N 段+续写→;修 today() UTC 凌晨错天 |
| T5 跨线契约通知 | ba620d7 | 契约单入 nomi-notch/backlog.md(全部只加不减) |

## 顺手修掉的现网活 bug(3 个)
1. 捕获坞「任务·给自己」kind:task 落库 422(KINDS 未收编)——T1 修+回归守卫。
2. 捕获坞/notch「交给 agent」只发 {prompt} 被 422(TaskBody 必填过严)——T2 修。
3. 「今天的页」凌晨 0-8 点错一天(toISOString=UTC)——T4 修。

## 绿门终态
pytest **254** passed(批次 +37)· 前端 build ✓ · svelte-check 0/0 · vitest **219** passed(批次 +12)· e2e 真通道验证(分诊/排期/回执全链路,试发数据已删)· 截图 shots/t2-*.png t3-*.png t4-*.png。

## 留给用户拍板的 Q(全部不阻塞,已按默认走并注明)
- **K6** 待办完成历史要不要 done 列(现:完成即清);拍板后做 [T3+] 已完成分区沉底。
- **Q-T2** 没说时间的 agent 任务:现 422 提示补时间;要不要改「立即执行一次」。
- **R01×2 / R08** 每日 accent、深色稿、note_links 表(批次 2 遗留)。

## 已知待修(下批次候选)
- **[T2+]** next_run 时区显示漂移(9 点显示 17:00,K6 期既有):后端统一存 UTC 或前端识别 naive=本地。
- **[T1+]** 分诊「记住纠正」个性化。
- **R07** Research/Settings 精修(批次 2 遗留 P2)。
- notch 线:接分诊回执 UI + journalToday 改吃 journal_date(通知单已入其 backlog)。

## 运行状态
后端已重启(8769,新契约已上线);前端 dist 已重建;VibeHub 已录 T1/T2 契约决策(待 dashboard 确认)。
