# Helm 主工作台 对齐 Loop · 处理流水

> 每把 `helm-pro.html`(锁定设计稿/只读)+ `DESIGN.md`(token/规则)的一块对齐进 Svelte 前端,loop 在这里追加一条。格式见 `helm-loop-procedure.md` 附录 C。
> 设计稿只读、不改。**阶段 1**(前端保真):改 `frontend/src/`,硬门 `npm run build`+`check`+`test`。**阶段 2**(后端接入+暴露给 notch):把 mock 换真数据、做 notch 共用契约,硬门追加 `pytest`(改后端)/ `cd notch && swift build && swift test`(改 notch 契约)。视觉门:browse 靶图对比(dark+light),真数据不许破版。
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

## 2026-07-02 01:52 · design-09-command-palette（夜间模式）
- 对齐: 命令面板 ⌘K token 化（次级表面·全局入口）
- 设计基线: DESIGN.md 双主题 token + helm-pro.html `.setdlg` 模态观感（只读对照，未改）
- Svelte 改动: `lib/CommandPalette.svelte`（仅 <style>）——overlay 模糊背景、palette 暗面板走 token、input/row/选中/group token 化
- 取舍: 逻辑/结构/role/文案全不动（测试无损）；各模式视图（Chat/Research 等）helm-pro 未画、归各自 Room，不在本 loop 靶内，故转做全局 overlay
- VibeHub: record_decision「命令面板 ⌘K token 化」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 开面板，暗面板+模糊背景+accent 选中+mono group 与暗壳一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:48 · design-08-orage-chrome（夜间模式）· 阶段1 核心八块收官
- 对齐: ORAGE chrome（阶段1 第8块）——点阵底纹 + 散落准星 fiducial + 坐标 chip + 强弱切
- 设计基线: helm-pro.html `.app::before` 点阵 / `.fidmark` / `.coord` / `.weak` / DESIGN.md「ORAGE Chrome 词汇 + 强度可切」（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte`（.center 点阵背景层 + .chrome overlay 准星/坐标，弱默认强可切）；`lib/layout.svelte.ts`（+chromeStrong/toggleChrome）；状态栏加「◇ chrome」切
- 取舍: 点阵做成 background 层避 z-index 坑；弱默认（f1/f2）符合「日常偏弱」，强模式（.strong）显 f3/f4；强度切暂在状态栏，未来挪设置（TODO）
- VibeHub: record_decision「ORAGE chrome + 阶段1 收官」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 弱默认点阵+坐标+准星到位，整体=helm-pro A+ORAGE
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜里程碑：阶段1 Shell/Today 核心八块全对齐｜剩余（loop 可续）：各模式视图/命令面板/速记/设置 modal 上妆；之后阶段2 接后端+notch｜❓需确认: 无

## 2026-07-02 01:44 · design-07-statusbar-hud（夜间模式）
- 对齐: 状态栏 CLI 面包屑 HUD 补全（阶段1 第7块）
- 设计基线: helm-pro.html `.sbar`（seg 分段 / NEXT / 001/009 / tok / RAG）/ DESIGN.md「三招牌·遥测状态栏」（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte` statusbar——加 CLAUDE·tok 14.2k、60ms·RAG idle、NEXT + 001/009（tabular）、path 段高亮；保留 toggle 与 backendStatus
- 取舍: tok/latency/NEXT/001/009 mock（真实遥测阶段2 接流）；保留 toggle 按钮与 backendStatus（App.test 依赖）
- VibeHub: record_decision「状态栏 CLI 面包屑 HUD」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 面包屑 HUD 与 helm-pro 一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:41 · design-06-context-telemetry（夜间模式）
- 对齐: context 遥测面板（阶段1 第6块）——当前项目 + Today 导航 + 会话遥测块 + 坐标 chip + LOCAL 角标
- 设计基线: helm-pro.html `.ctx`(cproj/slab/nrow/telem/coord/cornertag) / DESIGN.md「ORAGE Chrome 词汇·会话遥测块」（只读对照，未改）
- Svelte 改动: 新增 `lib/ContextPanel.svelte`（当前项目+Today 导航+SESSION/MODEL/TOKENS 遥测+坐标 chip+LOCAL 角标，走 token，mock）；`lib/Shell.svelte` 用 ContextPanel 替换旧占位、删 MODES/modeLabel 与无用 .ctx-* 样式
- 取舍: 旧「打开 Tab」占位无测试依赖，安全移除；遥测/导航计数 mock（真实值阶段2 接 orchestration/session 流，保持版式）
- VibeHub: record_decision「context 遥测面板」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（243 文件）/ test 146 通过；视觉：dev 5174 dark 与 helm-pro context 一致
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜里程碑：外壳+Rail+Today+context 全齐，整体达 helm-pro 观感｜❓需确认: 无

## 2026-07-02 01:37 · design-05-today-readout（夜间模式）
- 对齐: Today 无卡片仪表读数（阶段1 第5块）——任务/日记/agent 框选视口/项目/邮件/快速动作
- 设计基线: helm-pro.html `.rd`(rdrow/gut/task/jr/framed/agl/projline/mailn/qa) / DESIGN.md「三招牌动作·无卡片 Today」（只读对照，未改）
- Svelte 改动: `lib/Today.svelte`（重写为读数：左槽 mono + 发丝行 + 各节 mock + 框选视口 L 角 + ✻ 旋转/caret 闪烁 + 快速动作 wired）；`lib/Today.test.ts`（更新到新读数断言，修 helm 文本重复→用 /feat\/notch/ 唯一定位）
- 取舍: 清掉旧卡片+emoji（🔍📝）；数据用设计稿同款 mock（真实数据阶段2 接 /api 保持版式）；旧 Today.test 的线框断言作废，改断言新读数行为
- VibeHub: record_decision「Today 无卡片仪表读数」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 146 通过；视觉：dev 5174 dark+light 与 helm-pro 读数基本一致（当天 accent 青）
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:33 · design-04-filament-rail（夜间模式）
- 对齐: 细丝 Rail（阶段1 第4块）——1px accent 活线 + 锚点滑移 + agent 脉冲 + emoji→单色 SVG
- 设计基线: helm-pro.html `.rail`(fil/anchor/pulse/ric/logo) / DESIGN.md「三招牌动作·细丝 Rail」（只读对照，未改）
- Svelte 改动: `lib/Rail.svelte`（重写）——ICONS 单色 SVG 映射（{@html}）、HELM logo、fil/anchor/pulse、$effect 读激活按钮 offset 让锚点滑移对齐、34px ric 走 token
- 取舍: 落实禁 emoji（不再用 MODES.icon 的 emoji，Rail 自带 SVG 映射）；锚点用 offsetTop 计算而非死值（settings 底部自动跟到）；pulse 常驻 mock（真实 agent 流阶段2）；rail 无 mail（MODES 已禁 mail，按路由 truth）。当天 accent=青 #34D6C0 证明每日变色生效
- VibeHub: record_decision「细丝 Rail」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 147 通过；视觉：dev 5174 dark，logo/锚点/图标/细丝都对，emoji 全清
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:27 · design-03-shell-chrome（夜间模式）
- 对齐: 外壳 Shell chrome（阶段1 第3块）——titlebar + token 网格 + CLI 面包屑状态栏
- 设计基线: helm-pro.html `.app` 网格 + titlebar + `.sbar` / DESIGN.md「Spacing 骨架 / Layout」（只读对照，未改）
- Svelte 改动: `lib/Shell.svelte`（chrome 重构，功能逻辑不动）——titlebar（交通灯+HELM+路径+meta）、grid 加 title 行+列走骨架变量、context/center/terminal/tabbar 全改 token、statusbar 重做 CLI 面包屑 HUD（live accent 点+mono 分段+toggle 分段）
- 取舍: 保留 mode 路由/tabs/收起/palette/capture 不破；Rail 内部与 Today 内容仍旧浅样式透出=预期（各自块在后）；terminal 未做 40px edge（TODO）。视觉门 dev 端口 5174（5173 被他项目 Euka 占，后续截图用 5174）
- VibeHub: record_decision「外壳 Shell chrome」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 147 通过；视觉：dev 5174 截图 dark 纯黑 chrome + 纸白双主题都对（titlebar/context/statusbar/canvas 正确，Rail/Today 待其块）
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:24 · design-02-theme-store（夜间模式）
- 对齐: 主题/accent 系统（阶段1 第2块）——dark/light/跟随系统 + 每日 accent + 对比压暗
- 设计基线: helm-pro.html 的 theme 切换/darken()/palette + DESIGN.md「Themes / Color 每日变色」（只读对照，未改）
- Svelte 改动: 新增 `lib/theme.svelte.ts`（runes 单例 theme：mode/accent、apply→<html> data-theme+--acc/--acc-ink、dailyAccent/darken、init 监听系统翻转、jsdom 守卫）；`main.ts` mount 前 theme.init()；新增 `lib/theme.test.ts`（+3 测）
- 取舍: 每日 accent 走 palette[dayIndex%10]（当天稳定午夜轮换）；darken 复刻 helm-pro r*.5 g*.5 b*.42；system 模式移除 data-theme 交给 @media。视觉门本块仍有限（组件未消费，仅 body 变暗），下块外壳起对比。TODO: MODES emoji 图标留给 Rail 块换 SVG
- VibeHub: record_decision「主题/accent 系统 theme store」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（242 文件）/ test 147 通过（+3）；视觉：待下块外壳组件消费后 dark/light 对比
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无

## 2026-07-02 01:20 · design-01-tokens（夜间模式）
- 对齐: 设计 token 系统（阶段1 第1块）——把 helm-pro.html/DESIGN.md 的 token 落进全局 CSS
- 设计基线: helm-pro.html `:root`+`[data-theme]` 双主题 / DESIGN.md「Themes / Typography / Spacing / Motion」（只读对照，未改）
- Svelte 改动: `frontend/src/app.css`（重写）——字体硬切变量、招牌缓动+时长档、骨架尺寸、双主题 token（暗默认+暖纸白，@media prefers-color-scheme 实现默认跟随系统）、语义色配给、accent 默认留给 theme store 覆写、body/selection/scrollbar 走 token、reduced-motion
- 取舍: 纯 token 块，尚无组件消费 → 视觉门本块暂无可比（下一块起对比）。accent 每日推导+压暗留给下一块 theme store。light token 在 @media 与 [data-theme=light] 各写一份（避免 CSS 变量间接引用的复杂度）。禁 emoji 保持。
- VibeHub: record_decision「app.css 双主题 token 落地」→ (F8, ai_proposed)；add_constraint/add_question：无
- 验证: npm build ✓ / check 0 错 0 警（240 文件）/ test 144 通过；视觉：本块纯 token 无可比，待下块组件消费后 dark/light 对比
- 状态: ✅ 夜间自 commit（feat/design-shell-today）｜❓需确认: 无
