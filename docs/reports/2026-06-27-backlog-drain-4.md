# Loop Report · B 轨收尾 · drain #4

> 档位:🌙 放手模式。A 轨已全部合 main。Round 30,B 轨第 4 条 drain。

## 目标

drain `7842c722`[perf]:RAG `add_source` 同步索引大目录会阻塞请求 → 改后台索引 + 状态反馈。

## 做了什么

- **`helm/rag/service.py`**（改）:拆 `register_source`(建行 status=`indexing`,不索引)+ `index_source`(by id,跑 `_index`)
  + `add_source`(register+index 同步,直接调用 / 旧测试用)。
- **`helm/rag/routes.py`**（改）:`POST /sources` —— 在**自有 `session_scope` 立即提交** register(行持久化)→
  `background.add_task(_index_in_background)`(用 `app.state.db` 开新 session 索引)→ **立即返回 status=indexing**。
  索引在响应发出后后台跑,status→indexed/error;前端轮询 `/sources` 看状态(`Rag.svelte` 状态徽章已渲染,无需改前端)。
- **`tests/test_rag.py`**（改）:路由测试改为 POST→status=indexing,GET→indexed(TestClient 跑 bg task)。

## review(抓真 bug)

- 初版 register 用请求的 `db_session` 依赖,其 commit 时序晚于 background task → bg 用新 session 读不到未提交的行,
  index_source 找不到→不索引→status 卡在 `indexing`。
- **修复:register 用独立 `session_scope` 立即提交**,bg 新 session 必能见到行。复跑 8 测全过。
- 这是 review/验证门该抓的:跨 session + background task 的提交时序坑。

## 决策(record_decision)

- **decision `0c3ac7c2`**（ai_proposed）:RAG 后台索引;ticket `7842c722` 消化。

## 范围

- 消化「后台索引不阻塞」。「进度反馈」做到 indexing→indexed 状态轮询;逐文件增量 chunk_count 更细粒度留 follow-up。
- `reindex` 仍同步(ticket 限 add_source)。

## 验证

- `pytest tests/test_rag.py` → **8 passed**;`pytest`（全量后端）→ **185 passed, 1 skipped**(无回归)。

## 熔断状态

未命中熔断。一次测试失败(session 提交时序)首次即修复。

## 下一步

剩余可 drain 的自消化技术 ticket 不多了(`f029e4e5` httpx2 风险高、`b005c5de` 打包评估需真实 PyInstaller、
`ae484ba6` Skills 集成需 agent 集成 —— 后两者偏 needs-human/需真实环境)。接近「只剩 needs-human + 需真实环境」的停止点。
