# cockpit · m3 原地预览

- **日期**：2026-06-19
- **Room / milestone**：cockpit / m3（原地预览：md/code/image/pdf/zip）

## 目标
选中文件即原地预览：Markdown 渲染、代码、图片、PDF、压缩包清单。

## 做了什么
- **后端 `helm/cockpit/preview.py` + routes**：`GET /api/cockpit/text`（文本内容，封顶 1MB + truncated 标志，utf-8 errors=replace）、`GET /api/cockpit/raw`（FileResponse 原始字节，供 img/iframe）、`GET /api/cockpit/zip`（zip 清单，坏 zip→400）。
- **前端 `previewKind.ts`**：ext → markdown/code/image/pdf/zip/none + `rawUrl`。
- **`PreviewPane.svelte`**：按类型渲染——md 经 `marked` + **`DOMPurify.sanitize`** 后 `{@html}`；code `<pre>`（Svelte 转义安全）；image `<img>`；pdf `<iframe>`；zip 列表。**generation token 防陈旧 fetch 覆盖新选择**。
- **`CockpitView.svelte`**：FileBrowser | PreviewPane 左右分栏；Shell cockpit 模式渲染它。
- 依赖：`marked` + `dompurify`。
- **测试**：后端 text/截断/raw 字节/zip+坏 zip；前端 previewKind 3 + PreviewPane 6（含 md 净化、image 不打 text 端点、**陈旧 fetch 不覆盖**竞态）。

## 决策（record_decision）
- Markdown 安全：marked 渲染 → DOMPurify 净化 → {@html}；叠加 platform-shell 的 CSP（img-src 'self' data: blob: 拦截远程图、script-src nonce）防御纵深。
- 语法高亮（彩色）作增强 defer；m3 代码用 `<pre>` 等宽可读。

## defer
- 语法高亮、HEIC 解码、HTML 实时双缓冲渲染（属跟随模式 m5）、大文件虚拟化。

## 验证
- 后端 `pytest` **49 通过**（+3 预览）；前端 `svelte-check` 0/0、`vitest` **58 通过**（+9）；build ok。
- review（agent）：XSS 净化顺序正确、`<pre>` 转义安全、raw FileResponse 无新穿越面/nosniff、zip 映射、image 不 fetch 均确认。修 1 med（PreviewPane 陈旧 fetch 竞态 → generation token + 回归测试）。GUI 实际渲染为人工目视。

## 熔断状态
- 未命中。

## 下一步
- m4：内嵌终端（后端 pty + WebSocket → xterm.js）。🚪 终端 WS 协议为单向门（也关系 F5），需评审/定契约。
