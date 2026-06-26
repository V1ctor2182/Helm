# Room 收尾复盘 · deep-research

> 档位:🌙 放手模式。`deep-research` 5 个 MVP milestone 完成,Room 收尾 → 合 main。

## Room 概览

Deep Research:输入研究问题 → 引擎多轮 Think→Search→Extract→Synthesize → 产出带引用结构化报告,
过程可观测/可中断/可恢复,报告可喂驾驶舱 agent 或写项目。复用 Odysseus 循环设计 + prompt + Helm chat provider 层。

## 5 个 milestone(全部完成)

| m | 内容 | 关键产出 | 提交 |
|---|---|---|---|
| m1 | 迭代引擎 + 数据模型 | `helm/research/engine.py`(注入式 provider,≥3 轮,引用可追溯)+ Session/Source 表 | `966ea89` |
| m2 | 真实 provider + 注入隔离 | DDG 搜索 + httpx 抓取 + ChatLLM(复用 chat)+ untrusted 隔离 | `95fbd7e` |
| m3 | 研究 WS(可观测/中断/恢复) | `/api/research/ws` 线程跑引擎 + 线程安全 queue 推进度 + cancel/resume | `dbc4f34` |
| m4 | 报告前端视图 | `research` 模式面板(发起 + 实时进度 + 带 [n] 引用报告) | `ac47fd1` |
| m5 | 报告喂 agent / 写项目 | 导出到记忆(agent 经 MCP 读)/ 写项目 Markdown(拒覆盖) | `149b4f6` |

## 验证门(全绿)

- 后端 `pytest` → **147 passed, 1 skipped**。
- desktop `node --check` → ok。
- 前端 `vitest` → **116 passed**;`svelte-check` → **0/0**;`build` → ok。
- **全程零真实外部调用**(搜索/LLM 付费外部,放手模式硬底线):引擎/provider/WS 全用 fake + httpx MockTransport 覆盖。

## 决策留痕(本 Room,均 ai_proposed 待确认)

- `573932b0` 引擎集成(偏离 e3f16816)· `d51cb404` m2 provider · `54b672aa` m3 WS · `db18b595` m4 视图 · `70daee8a` m5 导出。

## needs-human 队列(本 Room 2 条)

- **`123796b8`（high）**:引擎集成方式偏离 constraint e3f16816「原样复用」—— 我用 Helm 原生循环+复用 prompt,
  请你定夺是否收窄该 constraint(可逆,已实现)。
- **`3e4b06cf`（medium）**:真实跑一次 Deep Research 核对 DDG 解析/LLM/报告质量(付费外部,loop 未跑);DDG 抓取脆弱可接 API fallback。

> 这 2 条都是 loop 碰到「偏离约束的方向问题」与「付费外部调用」时,按放手模式留给你的——非难撤产品决策本身,而是 loop 能力外/需你拍板的事。

## backlog(非阻塞)

本 Room 无非 needs-human 技术 ticket;跨 Room backlog 各自 Room 收尾时 drain。

## 合并

`feat/deep-research` → `main`(PR + CI 绿 + 合并提交保留逐 milestone 历史)。合后自动切下一个 Room:`journal-notes-tasks`。
