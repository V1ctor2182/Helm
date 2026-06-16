# F3 · Deep Research

> 来源：Odysseus（`src/deep_research.py`，IterResearch 风格）｜优先级：**P1**｜里程碑：M4
> 上级：[PRD 主文档](../00-PRD-Master.md)

复用 Odysseus 的自主迭代式深度研究引擎（Python 原样保留）：一个由 LLM 驱动的 **Think → Search → Extract → Synthesize** 循环，产出带引用的可视化报告。

---

## 1. 目标
- 输入一个研究问题 → 自动多步搜索、阅读、抽取、综合 → 输出**结构化、带引用、可视化**的报告。
- 全程 **LLM 自主决策**：搜什么、哪些相关、还缺什么、何时停止（区别于「搜索框 + 一次性摘要」）。
- 结论/片段可直接喂给驾驶舱里的 agent 或写入项目。

## 2. 非目标
- 不做付费学术库爬取；首版基于公开 web 搜索 + 网页抓取。

---

## 3. 引擎设计（移植自 IterResearch）

迭代循环（每轮由 LLM 决策驱动）：
1. **Think / Plan**：基于当前已知与缺口，规划下一步要查什么。
2. **Search**：调用 web 搜索（可插拔 provider）。
3. **Extract**：抓取候选网页，抽取与目标相关的内容（目标导向抽取，过滤低质）。
4. **Synthesize / Reflect**：更新结论，判断是否信息充分；不足则回到 1，足够则收尾。
5. **Report**：生成最终报告（分节、引用来源、可视化）。

关键模块（复用 Odysseus 现有实现，原样保留）：
- `current_date_context()`：给规划/查询 LLM 注入真实当前日期，避免用训练截止年份。
- 目标导向抽取器（`goal_based_extractor`）。
- 低质过滤、去思维链（`strip_thinking` / `is_low_quality`）。
- **prompt 安全**：把抓取到的网页内容作为「不可信上下文」隔离（`prompt_security` / `untrusted_context_message`），防 prompt 注入。

## 4. 依赖能力
- **Web 搜索**：可插拔（沿用 Helm 的搜索配置）。
- **网页抓取/正文提取**：HTML → 正文（Readability 类库）。
- **LLM**：复用 F2 的 ChatRouter / provider。
- **持久化**：研究过程与报告存 SQLite（`research_runs`）。

## 5. 报告与可视化
- 分节结构 + 内联引用（来源可点开）。
- 可视化报告视图（中央区渲染）；可导出 Markdown/HTML。
- 过程可观测：展示每轮搜了什么、读了哪些源、为何继续/停止（沿用 Odysseus "multi-step runs that gather, read, synthesize" 的展示）。

## 6. 数据模型（关联 F0）
- `research_runs(id, query, status, model, started_at, finished_at, report_json)`
- `research_steps(id, run_id, round, action, query, sources_json, notes, ts)`
- `research_sources(id, run_id, url, title, extracted_text, score)`

## 7. 用户故事
- 作为用户，我输入一个问题就能得到一份多源、带引用、能展开看过程的报告。
- 作为用户，我能把报告里的某段结论直接发给终端里的 agent 去落地实现。
- 作为用户，我能看到引擎为什么决定继续搜或停止。

## 8. 验收标准
- [ ] 一次研究能自动完成 ≥3 轮迭代并产出带引用报告。
- [ ] 报告每条关键结论可追溯到具体来源 URL。
- [ ] 抓取的网页内容被作为不可信上下文处理（注入测试不改变 agent 行为）。
- [ ] 研究过程可中断、可恢复查看历史。

## 9. 依赖与风险
- 依赖 F2（LLM）、搜索/抓取能力、F0（存储）。
- **低风险**：引擎是 Odysseus 既有 Python 代码，后端选 Python 后**原样复用、无需移植**——这正是「以 Odysseus 为底座」的最大红利。主要工作仅是把报告视图整合进新驾驶舱前端。
