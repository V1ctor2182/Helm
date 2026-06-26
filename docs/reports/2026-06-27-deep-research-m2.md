# Loop Report · deep-research · m2

> 档位:🌙 放手模式。`deep-research` 第 2 个 milestone（Round 13）。

## 目标

`deep-research` / **m2 — 真实 provider 接入 + prompt 注入隔离**。给 m1 的注入式引擎接上真实的
web 搜索 / 网页抓取 / LLM,满足 constraint ad182edb(公开 web 免付费)、bd8d8f69(不可信上下文隔离)。非末个。

## 做了什么

- **`helm/research/web.py`**（新增）:`DuckDuckGoSearcher`(POST `html.duckduckgo.com/html/`,**免 API key**;
  解析 `result__a`/`result__snippet`,unwrap `uddg=` 重定向;去标签)+ `HttpFetcher`(httpx GET +
  去 script/style/标签→可读文本,**死页吞错不炸整轮**)。sync(引擎循环 sync,m3 放线程),httpx client 可注入。
- **`helm/research/llm.py`**（新增）:`ChatLLM` 复用 Helm chat-multimodel provider——sync 非流式补全,
  镜像 chat.adapters 的 anthropic(`/v1/messages`)与 openai-compat(`/chat/completions`)形状 + 鉴权头 + system 透传。
- **`helm/research/factory.py`**（新增）:`build_engine(session, box, provider_id, model)` 从 DB 取 provider +
  解密 key 装 ChatLLM,配 DDG+fetch 组装 `ResearchEngine`;search/fetch 可注入(测试免网络)。
- **prompt 注入隔离**:fetcher 返回原始文本,引擎 m1 的 `untrusted()` 包成不可信上下文喂 LLM(constraint bd8d8f69)。
- **`tests/test_research_providers.py`**（新增）:7 测——DDG 解析/limit、fetcher 去脚本+吞错、
  ChatLLM 双形状(openai/anthropic)+鉴权头+system、factory 装配+解密 key+未知 provider raise。

## 决策(record_decision)

- **decision `d51cb404`**（ai_proposed）:三真实 provider + 工厂。技术决策。
- **`[needs-human]` `3e4b06cf`**(medium):真实跑一次 Deep Research 核对 DDG 解析/LLM/报告质量(付费外部,loop 不做);
  DDG 抓取脆弱,不稳可接有 API 的搜索后端 fallback。
- 无难撤产品 OQ(引擎集成方向问题已在 m1 的 `123796b8`)。

## VibeHub / MCP 交互

**pull**:读 `helm/chat/adapters.py`(LLM 调用形状)+ `chat/service.py ProviderService`(provider+解密 key)。
**write**:
- `record_decision`（`d51cb404`,ai_proposed）。
- `create_ticket`（`3e4b06cf`,**[needs-human]** 真实研究联调,medium）。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:纯后端;本地 `pytest` 全绿。provider 测试全 httpx MockTransport,**CI 不发真实外部请求**。
- cron/loop:`2dc539c2`,Round 13。

## defer

- `[needs-human]` `3e4b06cf`:真实研究联调(付费外部)。
- start 路由 + 异步可观测运行(research 跑分钟级 + 外部)→ m3(WS + 中断/恢复)。

## 优化

- **后端**:provider 全 sync + httpx client 注入 → MockTransport 全覆盖、零成本测;fetcher 死页吞错让单页失败
  不连累整轮研究;ChatLLM 复用既有 chat provider(不重造 LLM 客户端)。
- **前端**:本轮无前端。

## 验证

- `pytest tests/test_research_providers.py` → **7 passed**。
- `pytest`（全量后端）→ **137 passed, 1 skipped**(m1 130 → +7)。
- **未发真实搜索/LLM 调用**(付费外部,放手模式硬底线);MockTransport 覆盖 DDG/fetch/LLM/factory 全路径。

## review

自审:
- DDG:uddg unwrap、limit、tag strip —— 有测试;真实 HTML 吻合度待 [needs-human]。
- fetcher:去 script/style、HTTP 错→""(不炸整轮)—— 有测试。
- ChatLLM:openai/anthropic 双形状 + 鉴权头 + system 透传 —— 有测试。
- factory:解密 key 装配、未知 provider raise —— 有测试。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。付费外部联调按放手模式就地化解([needs-human] ticket),未停 loop。

## 下一步

`deep-research` / **m3 — 研究 WS(过程可观测 + 中断/恢复)+ start 路由**(intent#2):
POST 启动研究→线程跑 `build_engine` 引擎→`on_event` 经 WS 推进度→可 stop;复用 m1 的 on_event 钩子。Room 继续。
