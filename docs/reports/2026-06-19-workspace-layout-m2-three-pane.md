# workspace-layout · m2 三栏外壳布局

- **日期**：2026-06-19
- **Room / milestone**：workspace-layout / m2（三栏布局：Rail + 可收起面板 + Tab 化中央区 + 沉浸模式）

## 目标
搭出工作台外壳骨架：左侧模式栏 Rail、可收起的上下文/终端面板、Tab 化中央工作区、沉浸模式；切模式不丢 Tab。各模式内容为占位，由后续 feature Room 填充。

## 做了什么
- **`src/lib/layout.svelte.ts`**：Svelte 5 runes 布局 store（`LayoutStore` 类 + 单例 `layout`）。`mode`/`contextCollapsed`/`terminalCollapsed`/`tabs`/`activeTabId`；`immersive`、`activeTab` getter；`setMode`/`toggleContext`/`toggleTerminal`/`openTab`/`closeTab`/`selectTab`。`MODES` 八个模式（Today/Chat/Research/Memory/Journal/Mail/Cockpit/Settings）。
- **`Rail.svelte`**：竖排模式图标，点击切模式，高亮 active。
- **`Shell.svelte`**：CSS grid 三栏（Rail | 上下文 | 中央 Tab 区 | 终端）+ 底部状态栏（收起按钮 + 后端状态）。上下文/终端可收起；两者皆收 = 沉浸。
- **`App.svelte`**：渲染 Shell，保留 /healthz 探活（显示在状态栏）。
- **测试**：`layout.test.ts`（默认值 / setMode / **切模式保留 Tab** / openTab+closeTab 活动回退 / immersive）；`App.test.ts` 改为断言 Rail 模式按钮 + 后端状态。

## 决策（record_decision）
- 关键不变量（约束 d55f8ece）：Tab 存于 store、与 mode 解耦——`setMode` 只改 `mode`，从不动 `tabs`，故切模式不丢 Tab（有测试守护）。
- 各模式内容为占位，后续 feature Room 经扩展 seam 注入（registry 在 m3 引入）。

## defer
- ⌘K 命令面板 → m3；全局速记 + 键盘地图（⌘1..7/⌘\）→ m4；Today 主页 → m5；布局持久化（刷新保留）→ 暂不做。

## 验证
- `svelte-check` 0 错 0 警；`vitest` **7 通过**（App 2 + layout 5）；前端 build 成功；后端 pytest **41**、桌面 node **11** 不受影响。
- review（agent）：runes/响应式/不变量均确认正确；修了 2 处 a11y（`aria-current` 字符串 "false" → `'page'`/省略；tab 加 `aria-selected`+`aria-controls`，内容区 `role=tabpanel`+`tabindex`，section→div 消除 svelte-check 警告）。
- 渲染为 JS，UI 实际呈现由 vitest 组件测试覆盖；GUI 目视留待人工。

## 熔断状态
- 未命中。

## 下一步
- m3：⌘K 命令面板（可扩展命令 registry：导航 + 动作；feature Room 后续注册）。
