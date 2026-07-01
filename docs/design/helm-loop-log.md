# Helm 主工作台 对齐 Loop · 处理流水

> 每把 `helm-pro.html`(锁定设计稿/只读)+ `DESIGN.md`(token/规则)的一块对齐进 Svelte 前端,loop 在这里追加一条。格式见 `helm-loop-procedure.md` 附录 C。
> 设计稿只读、不改。**阶段 1**(前端保真):改 `frontend/src/`,硬门 `npm run build`+`check`+`test`。**阶段 2**(后端接入+暴露给 notch):把 mock 换真数据、做 notch 共用契约,硬门追加 `pytest`(改后端)/ `cd notch && swift build && swift test`(改 notch 契约)。视觉门:browse 靶图对比(dark+light),真数据不许破版。
> 最新在最上面。

<!-- 新条目追加到这条注释下面 -->

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
