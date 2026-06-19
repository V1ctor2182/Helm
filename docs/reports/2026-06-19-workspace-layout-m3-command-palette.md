# workspace-layout · m3 ⌘K 命令面板

- **日期**：2026-06-19
- **Room / milestone**：workspace-layout / m3（⌘K 命令面板 + 可扩展命令 registry）

## 目标
做出"通往一切"的 ⌘K 命令面板：输入即筛选、键盘选择执行；并提供可扩展的命令 registry，让 feature Room 后续注册自己的导航/动作（及数据搜索）。

## 做了什么
- **`commands.svelte.ts`**：`CommandRegistry`（`register()` 返回反注册闭包、按 id 去重、`search()` 模糊筛选）+ `fuzzyScore`（子序列匹配，连续匹配得分更低/为 0）。单例 `commands`，import 时注册默认命令：每个 mode 一条「Go to …」(Navigate) + Toggle 上下文/终端 (View) + New tab (Workspace)。
- **`CommandPalette.svelte`**：⌘K 弹层；输入筛选、↑↓ 选择、⏎ 执行并关闭、Esc/点击遮罩关闭；按钮式遮罩（兄弟节点，避免交互嵌套）；`role=dialog`/`listbox`/`option` + `aria-selected`；打开自动聚焦、关闭重置查询。
- **`layout.svelte.ts`**：加 `paletteOpen` + open/close/toggle。
- **`Shell.svelte`**：`<svelte:window onkeydown>` 全局 ⌘K（meta|ctrl）切换面板；渲染 `<CommandPalette/>`；状态栏加 ⌘K 按钮。
- **测试**：`commands.test`（fuzzy / register 去重+反注册 / search / 默认导航切 mode）、`CommandPalette.test`（关闭不渲染 / 打开筛选 / ⏎ 执行并关闭 / Esc 关闭）。

## 决策（record_decision）
- 命令 registry 即跨 Room 扩展 seam：feature Room 经 `commands.register()` 注入命令；数据搜索（项目/文件/会话）作为后续 search provider，待数据 Room 落地（本轮 defer）。

## defer
- 数据搜索 provider（项目/文件/会话/邮件）→ 各数据 Room；命令分组分区 UI、最近/频率排序、面板持久化 → 后续；⌘1..7 模式热键 + 全局速记 → m4。

## 验证
- `svelte-check` 0 错 0 警；`vitest` **17 通过**（+10：commands 6 + palette 4）；build 成功。后端/桌面未触及。
- review（agent）：无 high/med；fuzzy 子序列/打分、两个 $effect（聚焦+重置、选择 clamp）无死循环、⌘K 处理、按钮遮罩 a11y、registry 去重/反注册/响应式、stale index 守护均确认正确。按建议把连续匹配得分改为 0（`-1`）以贴合"perfect→0"。

## 熔断状态
- 未命中。

## 下一步
- m4：全局速记（⌘N 捕获浮层 <1s）+ 键盘地图（⌘1..7 切模式、⌘\ 收起、⌘\` 终端）。
