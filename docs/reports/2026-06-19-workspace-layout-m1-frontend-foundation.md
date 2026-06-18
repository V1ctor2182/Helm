# workspace-layout · m1 前端地基（脚手架 + 后端托管 + Electron 接入）

- **日期**：2026-06-19
- **Room / milestone**：workspace-layout / m1（前端脚手架 + 后端托管 + Electron 接入）

## 目标
端到端打通"Svelte 应用在外壳里渲染"：建立 Vite+Svelte5+TS 前端，后端静态托管其构建产物，Electron dev 连 Vite HMR / prod 连后端。后续 m2–m5 的布局/面板/⌘K 都建在此地基上。

## 做了什么
- **`frontend/`**：Vite + Svelte 5 + TS（官方模板）；最小 `App.svelte`（显示 Helm + 拉 `/healthz` 证明前后端联通）；清理脚手架 demo（Counter/logo/demo CSS）。
- **后端托管**：`helm/app.py` 在 routers 之后 `app.mount("/", StaticFiles(frontend/dist, html=True))`——构建产物存在则托管、否则回退占位 boot 页；`_frontend_dist()`（默认 `<repo>/frontend/dist`，`HELM_FRONTEND_DIST` 可覆盖，供打包）。挂载在最后，`/healthz`、`/api/*` 不被遮蔽。
- **Electron**：`backend.js` 加 `appUrl()`（dev=Vite 5173 / prod=后端）；`main.js` 用 `appUrl()` 加载、`will-navigate` 放行 Vite 源；健康检查仍打后端（Vite 代理 /api、/healthz）。
- **CI**：`.github/workflows/ci.yml` 加 `frontend` job（npm ci + vitest + build）。
- **测试**：前端 vitest（标题渲染 + /healthz 状态）；后端 `tests/test_frontend.py`（构建产物托管 / 未构建回退 boot 页 / 静态挂载不遮蔽 API）；桌面 appUrl 测试。

## 决策（record_decision）
- 前端地基定稿（单向门，用户拍板）：frontend/ = Vite+Svelte5+TS，FastAPI 静态托管，Electron dev 连 Vite HMR / prod 连后端；跨 Room 扩展走 registry。

## defer
- 打包把 frontend/dist 纳入 sidecar 托管 → m6 packaging 复验（`HELM_FRONTEND_DIST` 已预留）。
- SPA deep-link fallback、真正三栏布局/⌘K/Today → m2–m5。

## 验证
- 前端 `npm run build` 成功 + vitest 2 通过；后端 `pytest` **41 通过**；桌面 `node --test` **11 通过**。
- 端到端实跑：后端起在 :8780，`GET /` 返回**构建后的** Svelte index（`<title>Helm</title>` + hash JS 资产），资产 200 且 MIME=text/javascript，`/healthz` 未被静态挂载遮蔽。
- review（general-purpose agent）：m1 范围内 clean，无 high/med（StaticFiles 防穿越、挂载顺序、CSP/X-Frame 不干扰 Electron 顶层加载均确认）。GUI 开窗为人工目视。

## 熔断状态
- 未命中。（vitest 初次因 Svelte5 server-build 解析失败，加 `svelteTesting()` 插件一次修好，非反复失败。）

## 下一步
- m2：三栏外壳布局（Rail + 可收起面板 + Tab 化中央区 + 沉浸模式，切模式不丢 Tab）。
