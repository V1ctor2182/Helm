# Loop Report · deep-research · m3

> 档位:🌙 放手模式。`deep-research` 第 3 个 milestone（Round 14）。

## 目标

`deep-research` / **m3 — 研究 WS(过程可观测 + 中断/恢复)+ start 路由**(intent#2)。把 m2 的真实引擎
接进 WS:实时进度、可 stop、可 resume。非末个。

## 做了什么

- **`helm/research/engine.py`**（改）:`run` 加 `cancel`(每轮边界 poll,True 早停返回部分报告)+
  `resume_summary`/`resume_sources`(seed 续跑)。
- **`helm/research/service.py`**（改）:`run_research` 加 `cancel` + `resume_session_id` ——
  cancel→status=stopped(留部分报告);resume 从停下会话 summary+sources 续跑(新 source 去重、rounds 累加);
  缺会话 raise。
- **`helm/research/routes.py`**（改）:`@websocket /api/research/ws` —— sync 引擎放 `asyncio.to_thread`,
  `on_event` 经 `loop.call_soon_threadsafe` 推线程安全 `asyncio.Queue`→`ws.send_json`;`receiver` 听
  `{type:'stop'}`/断连→set `threading.Event`(引擎 poll);sentinel 收尾;build_engine 失败→error。
- **`tests/test_research_ws.py`**（新增）:5 测——cancel→stopped、resume→completed+累加、缺会话 raise、
  WS 端到端(monkeypatch build_engine 用 fake-provider 引擎:进度流 + 持久化 + REST 读)、未知 provider error。

## 决策(record_decision)

- **decision `54b672aa`**（ai_proposed）:WS 线程桥 + cancel/resume。技术决策。
- 无新 `[needs-human]`(真实研究联调归 m2 的 `3e4b06cf`)。无难撤产品 OQ。

## VibeHub / MCP 交互

**pull**:复用本 Room m1/m2 context + cockpit terminal_ws 的线程↔async 桥范式(loop.call_soon_threadsafe + Queue)。
**write**:`record_decision`（`54b672aa`,ai_proposed）。无新 ticket。

## Hooks / 自动化

- `commit-sync`:本轮提交走流程。
- CI:纯后端;本地 `pytest` 全绿。WS 测试用 fake-provider 引擎,**不发真实外部调用**。
- cron/loop:`2dc539c2`,Round 14。

## defer

- WS 客户端 `{type:'stop'}` 的实时中断时序未做确定性测试(timing 依赖);cancel 机制已在 service 层测。
- 真实研究联调 → `[needs-human]` `3e4b06cf`(m2)。

## 优化

- **后端**:sync 引擎放线程不阻塞事件循环;线程安全 queue 单向推事件;resume source 去重避免重复行;
  rounds_done 累加让 stop→resume 的总轮数正确;client 断连即 cancel(不留孤儿线程跑满 max_rounds)。
- **前端**:本轮无前端(报告/进度视图 m4)。

## 验证

- `pytest tests/test_research_ws.py` → **5 passed**。
- `pytest`（全量后端）→ **142 passed, 1 skipped**(m2 137 → +5)。
- **未发真实外部调用**(放手模式硬底线);WS 用 fake-provider 引擎覆盖 spawn→进度→持久化全链路。

## review

自审:
- cancel 每轮边界 poll→stopped 保留部分报告;resume seed summary+sources 续跑+去重+累加 —— 有测试。
- WS:to_thread 跑引擎、call_soon_threadsafe 推 queue、sentinel 收尾、断连→cancel —— 端到端测。
- build_engine 失败→error 帧 —— 有测试。
- 无真 bug,无 fixup。

## 熔断状态

未命中熔断。

## 下一步

`deep-research` / **m4 — 报告前端视图**(intent#1 可视化 + constraint e3f16816「报告视图整合进驾驶舱前端」=本 Room 主要工作):
`research` 模式面板——发起研究(连 /ws 看实时进度)+ 结构化报告渲染(摘要 + 带引用 claims + 来源列表)。Room 继续。
