# workspace-layout · m5 Today 主页 + 当前项目上下文

- **日期**：2026-06-19
- **Room / milestone**：workspace-layout / m5（Today 主页骨架 + 当前项目上下文 store）

## 目标
打开 Helm 的落地页：Today 聚合"现在该看/该做的"，各模块一键进入对应 mode；并提供"当前项目"上下文 store，供 Chat/研究/agent/记录挂载。

## 做了什么
- **`project.svelte.ts`**：`ProjectStore`（`current`/`recent` + `setCurrent`/`open`(去重前插)/`setRecent` seam）。消费方读 `projects.current`；cockpit Room 填 `recent`。
- **`Today.svelte`**：Today 仪表盘——快速动作（新建 Chat / 发起研究 / 速记）+ 5 个占位模块卡（任务/日记/最近项目/agent 活动/紧急邮件），点卡进入其 mode；显示当前项目或"未选择项目"。各模块真实数据由 feature Room 填充（横切占位）。
- **`Shell.svelte`**：中央区 `mode==='today'` 渲染 `<Today/>`，否则渲染 tab 栏 + 内容（tabs 仍存于 store、非 today 模式照常显示，不违反 m2 不变量）。

## 决策（record_decision）
- 当前项目 = `projects.current` 单一上下文，消费方各 Room 读取/挂载；m5 提供 store + seam，cockpit Room 驱动选择与 recent 列表。
- Today 作为 'today' 模式的中央内容；tabs 在 today 模式不渲染但保留（m2 不变量不破）。

## defer
- 模块真实数据（任务 F6 / 项目·agent F1 / 邮件 F7）；项目持久化、项目选择器 UI；recent 由 cockpit 填充。

## 验证
- `svelte-check` 0/0；`vitest` **40 通过**（+8：project 3 + Today 5）；build ok。后端 pytest **41** / 桌面 node **11** 不受影响。
- review（agent）：无 high/med；Shell 的 {#if}/{:else}/{/if} 结构正确、tabs 不变量保持、project 响应式、Today a11y（卡片均为 button）、快速动作均确认正确。采纳 low：afterEach 补 setRecent([]) 防泄漏。

## 熔断状态
- 未命中。

## 下一步（Room 收尾）
- **workspace-layout 全部 milestone（m1–m5）完成** → 停下等人开 PR 合 main。不自动合、不跳下一个 Room。
- 合入后顺序里下一个 Room：`cockpit`（驾驶舱：文件浏览/预览 + 内嵌终端 + 实时观测 agent）。
