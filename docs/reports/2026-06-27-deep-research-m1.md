# Loop Report · deep-research · m1

> 档位:🌙 放手模式。新 Room `deep-research` 第 1 个 milestone（Round 12）。

## ⚠️ 本轮产生 1 条 [needs-human]

`123796b8`(high):**引擎集成方式偏离 constraint e3f16816「原样复用」**。我改为 Helm 原生循环
(复用 Odysseus prompt + 接 Helm chat provider + 注入式 provider),而非字面 vendoring 929 行 Odysseus 引擎。
理由:整包 vendoring 拖依赖树、与 Helm 架构两套、且运行即付费外部调用无法 headless 测。**已按可逆方案实现**
(换 provider/引擎即可),请你定夺是否收窄该 constraint。详见 ticket。

## 目标

`deep-research` / **m1 — 研究数据模型 + provider 接口 + 迭代引擎**(intent#1 引擎核心)。
Think→Search→Extract→Synthesize 循环,注入式 provider 使其 headless 可测,≥3 轮 + 带引用报告。非末个。

## 做了什么

新建 **`helm/research/`** 包:

- **`models.py`**（新增）:`ResearchSession`(question/status/rounds_done/report_json/error)+
  `ResearchSource`(session_id FK/url/title/snippet/round)——结构化报告存 JSON,来源存行使引用可查。
- **`providers.py`**（新增）:`SearchResult` + `Searcher`/`Fetcher`/`LLM` Protocol(注入式;真实现 m2)。
- **`engine.py`**（新增）:`ResearchEngine` —— plan→[gen_queries→search→extract→synthesize]×N→should_stop
  循环;LLM 驱动每步(prompt 移植自 Odysseus,condensed);`untrusted()` 把抓取内容包成不可信上下文
  (constraint bd8d8f69);`_extract_json` 鲁棒解析 LLM JSON;**收尾强制引用可追溯**——丢弃指向未采集 URL 的引用
  (constraint 180077c3);`on_event` 回调供 m3 观测。
- **`service.py`**（新增）:`ResearchService` —— list/get/sources + `run_research`(持久化会话→跑注入引擎→
  存报告+来源;引擎失败→status=failed 不谎报)。
- **`routes.py`**（新增）:`GET /api/research`(列表)、`GET /{id}`(报告+来源)。start 路由(真 provider)留 m2。
- **`tests/test_research.py`**（新增）:6 测——≥3 轮+引用可追溯(bogus URL 被丢)、max_rounds 封顶、
  untrusted wrap 到达 LLM、JSON 解析、持久化、失败记录、路由。

## 决策(record_decision)

- **decision `573932b0`**（ai_proposed）:MVP 拆分 + 引擎集成方式(偏离 e3f16816,理由+备选+可逆性)。
- **`[needs-human]` `123796b8`**(high):引擎集成方式偏离 recorded constraint,请你定夺(本轮唯一难撤/定方向项)。
- 其余技术决策(provider 抽象、报告结构、引用校验)放手模式自决。

## VibeHub / MCP 交互

**pull**:`get_feature_context(deep-research)` → 3 intent + 5 constraint(不可信上下文隔离 bd8d8f69、
公开 web ad182edb、**原样复用 e3f16816**、≥3 轮可追溯 180077c3);读 Odysseus `src/deep_research.py`(循环+prompt)。
**write**:
- `record_decision`（`573932b0`,ai_proposed）。
- `create_ticket`（`123796b8`,**[needs-human]** 引擎集成方式,high）。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:纯后端;本地 `pytest` 全绿。
- cron/loop:`2dc539c2`,Round 12(agent-orchestration 合 main 后首个新 Room milestone)。

## defer

- `[needs-human]` `123796b8`:引擎集成方式(偏离 constraint)。
- 真实 provider(web 搜索/抓取/LLM)+ 完整 prompt_security 隔离 → m2(含付费外部,届时再开联调 needs-human)。

## 优化

- **后端**:引擎与 provider 解耦(Protocol)→ 全循环 headless 可测、零成本;引用校验在收尾一处强制
  (脏引用进不了报告);失败不谎报 completed。
- **前端**:本轮无前端(报告视图 m4)。

## 验证

- `pytest tests/test_research.py` → **6 passed**。
- `pytest`（全量后端）→ **130 passed, 1 skipped**(agent-orch 124 → +6)。
- **未发真实 web/LLM 调用**(付费外部,放手模式硬底线);fake provider 覆盖整循环。
- 人工目视项:真实研究质量待 m2 真 provider + [needs-human] 联调。

## review

自审:
- ≥3 轮 + 引用只认采集到的 URL(bogus 丢弃)—— 有测试,贴 constraint 180077c3。
- 不可信上下文 wrap 经 system 参数到达 LLM —— 测试断言。
- 引擎失败 → 会话 failed + error,不存半成品报告冒充完成。
- 偏离 constraint 已 record + [needs-human],代码 docstring 标注。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。偏离 recorded constraint 这一"定方向"项按放手模式**就地化解**(可逆实现 + [needs-human] ticket),未停 loop。

## 下一步

`deep-research` / **m2 — 真实 provider 接入 + prompt 注入隔离**:web 搜索 + 网页抓取(httpx)+ LLM
(复用 chat providers)+ 不可信上下文隔离(constraint bd8d8f69);加 start 研究路由。⚠ 含付费外部调用,
届时开联调 [needs-human]。Room 继续。
