# cockpit · m2 文件浏览前端

- **日期**：2026-06-19
- **Room / milestone**：cockpit / m2（文件浏览前端：Svelte 移植 FanBox）

## 目标
把 FanBox 文件卡片/实体图标/项目徽章移植为 Svelte，连上 m1 后端；⌘K 可搜到项目。

## 做了什么
- **`cockpit/fileIcons.ts`**：实体图标+强色映射（PDF 红、JS 黄、MD 蓝、图片绿、视频紫、压缩橙…），框架无关工具（移植 FanBox 精华）。
- **`cockpit/cockpit.svelte.ts`**：`CockpitStore`（cwd/entries/projects/selected/error；browse(encodeURIComponent)/loadProjects/openProject/select；错误处理）。**loadProjects 把每个项目注册进 ⌘K 命令面板**（用 m3 命令 registry seam，按 id 去重）。
- **`cockpit/FileBrowser.svelte`**：无 cwd 时显示"打开文件夹"输入 + 最近项目卡（带徽章）；有 cwd 时文件卡网格（图标+名+大小，点目录进入/点文件选中）+ 上一级。卡片均为可聚焦 button。
- **`Shell.svelte`**：cockpit 模式中央区渲染 `<FileBrowser/>`。
- **测试**：fileIcons 3 + cockpit 4（browse/错误/项目注册进 palette/select）+ FileBrowser 2（输入+最近项目 / 文件条目）。

## 决策（record_decision）
- ⌘K 项目搜索经 `commands.register()` 注入（cockpit.project.<path> 命令，去重）——落实 m3 的跨 Room 命令 seam；`内容:` 全文搜索待后端（defer）。
- 文件浏览前端为 cockpit 模式中央内容；预览（m3）后续在中央/Tab 接入。

## defer
- 文件预览 m3 / 终端 m4 / 监听·跟随·高亮 m5 / git diff m6；缩略图、内容搜索、>1000 项虚拟化（性能）→ 后续。

## 验证
- `svelte-check` 0/0；`vitest` **49 通过**（+9）；build ok。后端 cockpit REST 由 m1 pytest 覆盖；store 测试 stub fetch 打同样契约。GUI 实际浏览为人工目视。
- review（agent）：m2 范围内 clean，无 high/med；browse 错误处理/encodeURIComponent、项目命令去重不泄漏、parentOf 边界（/、尾斜杠、顶层）、{@const} 位置、单例测试隔离、路径安全均确认。修 1 low（loadProjects 加 try/catch 防 onMount 未处理拒绝）。

## 熔断状态
- 未命中。

## 下一步
- m3：原地预览（md/code/image/pdf/zip，中央 Tab；移植 FanBox 预览渲染逻辑）。
