# workspace-layout · m4 全局速记 + 键盘地图

- **日期**：2026-06-19
- **Room / milestone**：workspace-layout / m4（全局速记 ⌘N + 键盘地图）

## 目标
零摩擦捕获：任意界面 ⌘N <1s 弹出速记输入，记完即走；并落实 F8 §7 键盘地图。

## 做了什么
- **`keymap.ts`**：纯函数 `applyShortcut(e, layout)`（可单测）。⌘K 面板 · ⌘N 速记 · ⌘\ 上下文 · ⌘\` 终端 · ⌘1..8 按 Rail 顺序切模式；要求 ⌘/Ctrl 且 **非 Alt**（AltGr 在部分欧洲键位报 ctrlKey，避免劫持 AltGr 字符）。⌘P（项目切换）defer。
- **`capture.svelte.ts`**：`CaptureStore`（in-memory `items` + `submit` trim/去空 + `setPersister` 持久化 seam）。durable 持久化是 F6 的活（横切 seam，非 stub）。
- **`QuickCapture.svelte`**：⌘N 弹层（textarea）；⏎ 保存、⇧⏎ 换行、Esc 关闭；按钮式遮罩；保存按钮空文本禁用；打开自动聚焦。
- **`layout.svelte.ts`**：加 `captureOpen` + open/close。
- **`Shell.svelte`**：`onGlobalKey` 改用 `applyShortcut`；渲染 `<QuickCapture/>`；状态栏加 ⌘N 速记按钮。
- **测试**：keymap（各快捷键 + 非修饰键忽略 + ⌘9 越界 + ctrl 兜底 + **Alt 不触发**）、capture（trim/空/顺序/persister seam）、QuickCapture（关闭不渲染 / ⏎ 保存并关 / Esc 不保存）。

## 决策（record_decision）
- 速记持久化走 `capture.setPersister()` seam → F6 接后端；m4 仅内存（横切骨架，捕获 UX 端到端可用）。
- 键盘修饰键策略：⌘|Ctrl 且非 Alt（防 AltGr 误触，review med 建议）。

## defer
- durable 持久化 / 转任务·记忆·日记 → F6（记录 Room）；⌘P 项目切换 → cockpit Room（暂无项目）。persister 错误/回滚契约由 F6 定义。

## 验证
- `svelte-check` 0/0；`vitest` **32 通过**（+15：keymap 7 + capture 4 + QuickCapture 3 + AltGr 1）；build ok。后端/桌面未触及。
- review（agent）：无 high；采纳 med（加 `!altKey` 防 AltGr 误触）；其余 low（覆盖层下切模式无害幂等、persister 错误路径属 F6、backdrop tab-stop）记录不阻塞。
- 一处 vitest 时序假象（captureOpen 在 await 后一个 microtask 翻转）→ 测试改用 vi.waitFor 修好。

## 熔断状态
- 未命中。

## 下一步
- m5：Today 主页骨架 + 当前项目上下文 store（各模块占位 + 一键进入对应 mode）。dev-infra... workspace-layout 最后一个 milestone，完成后收尾开 PR。
