# Room 收尾复盘 · memory-rag-skills

> 档位:🌙 放手模式。`memory-rag-skills` 全部 7 个 PRD milestone 完成,Room 收尾 → 合 main。

## Room 概览

记忆 / RAG / Skills —— Helm 的「大脑」持久层:跨会话记忆、本地文档 RAG、把这些能力经 MCP
暴露给终端 Claude Code,以及 Skills 透视。复用 Odysseus 的 SQLAlchemy/SQLite/ChromaDB/fastembed 栈。

## 7 个 milestone(全部完成)

| m | 内容 | 关键产出 | 提交 |
|---|---|---|---|
| m1 | 记忆数据模型 + CRUD + 关键词检索 | `helm/memory/`(models/service/routes),Jaccard 关键词 | `9e2839f` |
| m2 | 记忆向量检索(混合) | ChromaDB + fastembed 懒加载 + 优雅降级 + 0.7 融合 | `207c2dd` |
| m3 | 记忆 JSON 导入/导出 + 前端面板 | `/export`·`/import`,Memory.svelte 挂 memory 模式 | `0f83ba8` |
| m4 | RAG 文档索引 + 检索 API | `helm/rag/`,text/code/md + PDF/docx,helm_rag collection | `a76a4fe` |
| m5 | RAG 前端 | Rag.svelte + BrainPanel 段【记忆\|知识库】 | `e48457f` |
| m6 | MCP 能力层 server ⚠ | `helm/mcp/` stdio→REST 桥接,4 工具契约 | `5047db3` |
| m7 | Skills 透视 | `helm/skills/` 扫描+健康+启停+计数,BrainPanel【Skills】段 | `1a86de7` |

## 验证门(全绿)

- 后端 `pytest` → **102 passed, 1 skipped**(真 fastembed 测 opt-in 跳过)。
- desktop `node --check` → ok。
- 前端 `vitest` → **95 passed**;`svelte-check` → **0/0**;`build` → ok。
- 真 embedding 路径(memory + rag)本地 opt-in smoke 均验证通过(语义排序正确)。

## 决策留痕(本 Room,均 ai_proposed 待确认)

- `2cb56d3b` milestone 拆分 · `63ac6ef9` m2 向量 · `e7f4f02b` m3 导入导出 · `1e5cb361` m4 RAG ·
  m5 UI 归属(report 内) · **`e02ac069` m6 MCP 架构(高风险)** · **`ca4b5e64` MCP 工具契约 constraint(高风险)**
  · `62f29978` m7 Skills。

## backlog(留待 drain,未阻塞合并)

- `7842c722`(本 Room,medium):RAG add_source 同步索引大目录阻塞 → 后台索引。
- `4527c95c`(本 Room,low):前端 #json helper 重复 → 抽共享。
- `b005c5de`(platform-shell)· `8299f9b6`(cockpit)· `f029e4e5`(dev-infra)· `ae484ba6`(agent-orchestration)
  —— 跨 Room,各自 Room 收尾时 drain。

> 收尾 drain:本 Room 仅 2 条非 needs-human 技术 ticket,均非阻塞(medium/low),按"绝不为清债拖延合并"
> 留 backlog,不在合并前消化。

## needs-human 队列

**0 条**。整个 Room 7 个 milestone 未产生任何难撤/定方向的产品决策——全部为技术决策或可逆产品小决定,
按可逆性分级 record。高风险技术决策(m6 MCP 契约)已写满 + add_constraint + report 置顶,供 dashboard 审计。

## 合并

`feat/memory-rag-skills` → `main`(开 PR 留 GitHub 审计,等 CI 绿后合并;合并提交保留逐 milestone 历史,
符合本仓库既有 Room 合并惯例 + "单 milestone 单 commit 可整段回滚")。合后自动切下一个 Room:`agent-orchestration`。
