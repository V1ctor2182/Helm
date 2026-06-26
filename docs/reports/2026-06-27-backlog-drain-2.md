# Loop Report · B 轨收尾 · drain #2

> 档位:🌙 放手模式。A 轨已全部合 main。Round 28,B 轨第 2 条 drain。

## 目标

清自消化技术 backlog。本轮:
1. **调查 `8299f9b6`[perf] Monaco 代码分割** → 发现**已解决**(诚实不造假活)。
2. **drain `5582cd77` file_changes 无界增长** → 加表上限。

## 做了什么

### 1. Monaco ticket 8299f9b6 —— 调查后关闭(已解决)

PreviewPane 早已用 `{#await import('./DiffView.svelte')}` 懒加载,Monaco(editor.api2 3.6MB)已是**按需独立 chunk**,
不在初始 bundle(index 仅 538KB)。vite >500KB 警告只是对懒 chunk 的提示,非初始加载问题。**无需改动 → 关 issue #14**。
(放手模式诚实交付:不为清债造一个 no-op 改动。)

### 2. file_changes 表加上限(5582cd77)

- **`helm/cockpit/service.py`**（改）:`record_change(session, path, kind, cap=5000)` —— 插入 + **摊还 prune**
  (每 200 条插入触发一次按 id 阈值 `DELETE id <= max_id-cap`),把 append-only 的 file_changes 封顶在 ~cap+200。
  +`file_change_count`。
- **`helm/cockpit/routes.py`**（改）:watch WS 写入点改用 `record_change`(替原裸 `FileChange` add);清理未用 import。
- **`tests/test_file_changes_cap.py`**（新增）:2(260 插入→pruned 到 ~110、record_change 返回行)。

**范围**:消化「无界增长」(明确 bounded 修复)。ticket 另一半「节流/批处理 per-event sync 写入」是更大的 WS 写循环
debounce 改造,留作 follow-up(已有 `NOTE(perf follow-up)` 注释文档化)——不在本次,避免 drain 变无底洞。

## 决策(record_decision)

- **decision `8d4dc5d7`**（ai_proposed）:file_changes cap;ticket `5582cd77` 部分消化、`8299f9b6` 调查后关闭。

## 验证

- `pytest`（全量后端）→ **185 passed, 1 skipped**(drain #1 后 183 → +2 cap 测);cockpit 既有 15 测无回归。
- cap 行为:260 插入(cap=50)→ 摊还 prune 到 ~110(< 260,确实在剪)。

## 熔断状态

未命中熔断。

## 下一步

继续 B 轨 drain(`7842c722` RAG 后台索引、`f029e4e5` httpx2、`f4987eed` tool_call↔FileChange、`b005c5de` 打包体积评估…),
直到只剩 `[needs-human]`。本轮合这条。
