# Design System — Helm

> 主工作台（Shell + Today 起步）的设计真相源。所有视觉/UI 决策以本文件为准；
> 偏离需用户明确批准。notch 伴侣 app 的设计源 `notch/docs/helm-notch-pro.html`
> 是本系统的母体，二者共享同一美学 DNA。

## Product Context
- **是什么**：本地优先的个人 AI workspace 桌面 app（macOS/Apple Silicon 首发，Svelte Web 前端打包成桌面壳）。
- **一窗掌全局**：左手掌舵本地项目与编程 agent（Cockpit + 内嵌终端），右手是会研究/有记忆/调任意模型的大脑（Chat/Research/Memory）。同一窗口，同一套代码。
- **给谁**：自己日常用的掌舵者；键盘优先、零配置、私密。
- **品类同侪**：Linear / Raycast / Warp / Zed（近黑、单色、键盘优先、列表密度）——识字于此，但要有自己的脸。

## Memorable Thing（北极星）
**一窗掌全局 — 左手 agent，右手大脑，掌控感 > 装饰。**
黑色座舱玻璃罩，静默仪表；唯一"活着"的是那根琥珀细丝——你的这一天、agent 的心跳都走在这一根线上。密度与掌控感胜过为美而美。

## Aesthetic Direction
- **方向**：Industrial / Utilitarian × Surveillance-Brutalist Cockpit（精密驾驶舱 + 监控台/技术粗野）。
- **参考皮**：ORAGE（`docs/design/` 参考图）——界面即仪器：点阵底纹、角标 fiducial、遥测文字当 chrome、框选视口（frame 非 card）、CLI 面包屑。
- **装饰级别**：intentional。装饰=仪表信息本身（坐标/遥测/基准点），不是纹理堆砌。
- **Mood**：坐进一台已经预热、待命的高端机器。冷静、精密、可信；克制读作自信，不是空。
- **禁 emoji**：图标一律单色 SVG 或等宽字形。
- **设计稿**：
  - `docs/design/helm-pro.html` — **⭐ SOURCE OF TRUTH（唯一定稿）**：A + ORAGE，黑/白主题实时切 + 每日色 + chrome 强弱 + 内嵌设计 token 参考。进 Svelte 以此 + 本 DESIGN.md 为准，**不改本文件、改代码**（同 notch loop）。
  - `docs/design/helm-cockpit-orage-themes.html` — 双主题上下对照版（helm-pro 的前身，存档）。
  - `docs/design/helm-shell-all-variants.html` — A–G 七变体合并对比页（判断用，存档）。
  - `docs/design/helm-shell-today-variants.html` — 探索期 A/B/C 三变体，存档。
  - `docs/design/helm-shell-explore-2.html` — 探索批次 2（D 交易台 / E 战术 HUD / F 器械面板 / G 克制 / H 磷光 CRT），存档。
- **落地 loop**（照 notch 打法把设计稿逐块做进 Svelte，只读设计稿、改代码）：
  - `docs/design/helm-loop-procedure.md` — 流程（依赖顺序 / 硬门 / 视觉门 / VibeHub / 映射表 / log 格式）。
  - `docs/design/helm-loop-prompt.md` — 启动命令（默认逐块停 / 守候 /loop / 夜间模式）。
  - `docs/design/helm-loop-log.md` — 每轮流水。

## 三个招牌动作（Signature Moves）
1. **细丝 Rail（Filament Rail）**：Rail 内缘一根 1px 竖向 accent「活线」，全 app 唯一连续的 accent 元素。激活 section 锚定一段 ~38px accent（滑移切换，`.42s` 招牌缓动）；agent 干活时一个 2px 光点从 Cockpit 图标沿线向上脉冲（`.7s`）——余光可感，无需 toast/badge。图标永远单色，只有细丝是 accent。
2. **无卡片 Today（Instrument Readout）**：Today 是单列仪表读数，不是仪表盘。左槽 mono 时间戳/section tag + 发丝横线拉出「账本边距」，零阴影零圆角零填充卡片。密度靠排版和线，不靠容器。
3. **遥测状态栏 / CLI 面包屑（HUD）**：底部 26px mono 条 = 分段面包屑 `● ~/helm  ⎇ feat/notch ↑2  CLAUDE · tok 14.2k  60ms · RAG idle … NEXT 001/009`，tabular-nums 不抖，最左一个 accent 点 = agent 活着。

## ORAGE Chrome 词汇（组件语汇）
- **点阵底纹**：`radial-gradient(var(--grid) 1px, transparent 1px)` 22px 网格，极低透明。
- **角标 fiducial**：框选视口用 1px 发丝描边 + accent L 角（左上/右下，`::before/::after`）。散落十字准星 `+` 用 `--t4`。
- **坐标 chip**：mono 9px `X:0512PX Y:0267PX`，chrome 底 + 发丝边，浮在面板角。
- **会话遥测块**：上下文面板底部 mono 9px `SESSION / MODEL / TOKENS / AGENTS / RAG / UPTIME`（对应参考图 VIDEO ID 元数据块）。
- **框选视口（framed viewport）**：Agent 输出 / 项目预览等「活」的东西用 frame + 角标，不是填充 card。
- **强度可切**：散落准星 + 坐标 chip 的密度可切（`强 ⇄ 弱`）。**日常默认偏弱**（保留遥测块 + 框选视口 + 面包屑，弱化散落准星）；展示可拉满。

## Themes（双主题 · 默认跟随系统）
两套主题共享布局/密度/chrome/组件，只换 token。accent 在浅底上按 notch 对比度规则自动压暗（原色 → ×~0.5 直到对比 ≥ 3.2:1）。

### Dark（`t-dark` · ORAGE-native · 座舱夜航）
| token | 值 | 用途 |
|---|---|---|
| `--bg` | `#000000` | 画布 |
| `--chrome` | `#0a0a0c` | 标题栏/状态栏 |
| `--panel` | `#08080a` | 上下文/侧面板 |
| `--t1 / t2 / t3 / t4` | `#fff` / `rgba(255,255,255,.82)` / `.52` / `.32` | 文字四档（正文≤.82，纯白只给全场唯一最重要活跃元素） |
| `--line / --hair` | `rgba(255,255,255,.14)` / `.07` | 框线 / 发丝分隔 |
| `--tile` | `#101012` | 极少数需要面的地方 |
| `--acc / --acc-ink` | `#FFC53D` / `#FFC53D` | accent 填充 / accent 文字·线 |
| `--grid` | `rgba(255,255,255,.035)` | 点阵 |

### Light（`t-light` · 暖纸白 · 纸面仪表）
| token | 值 | 用途 |
|---|---|---|
| `--bg` | `#efece3` | 暖 off-white 纸底 |
| `--chrome` | `#e7e3d8` | 标题栏/状态栏 |
| `--panel` | `#eae6dc` | 上下文/侧面板 |
| `--t1 / t2 / t3 / t4` | `#17140d` / `rgba(23,20,13,.74)` / `.52` / `.34` | 墨字四档 |
| `--line / --hair` | `rgba(23,20,13,.20)` / `.10` | 框线 / 发丝 |
| `--tile` | `#e4dfd2` | 面 |
| `--acc / --acc-ink` | `#FFC53D` / `#8A6410` | accent 填充仍亮，文字·线用压暗深琥珀 |
| `--grid` | `rgba(23,20,13,.05)` | 点阵 |
| 语义色（压暗版） | 绿 `#2a8f43` · 橙 `#b56b00` · 红 `#c2331f` | 浅底对比安全 |

## Typography
- **硬切规则**：`SF Pro`（`-apple-system` 栈）= 人说的话（日记/chat/邮件正文）；`ui-monospace`（SF Mono）= 机器说的/量的话（标签/时间戳/计数/路径/状态栏/section tag/遥测/agent 活动）。**mono = 仪表，sans = 人**。
- **Display/标题**：`TODAY` 等仪表标题用 mono 24px/800/字距 1px（粗野 mono 观感）；人性化大标题（如问候）可用 SF Pro 28-38px/800/字距 -.02em。
- **Section 标签**：mono 9px/700/字距 1px/大写/`--t4`。
- **正文**：SF Pro 13px。**数据/计数一律 tabular-nums**（`font-variant-numeric:tabular-nums`）永不抖动。
- **加载**：系统字体，无需 CDN（`-apple-system` + `ui-monospace`）。
- **Scale（px）**：9(标签/遥测) · 10(chip/次mono) · 11(状态栏/gutter) · 12-13(正文) · 24(仪表标题) · 28-38(人性大标题)。

## Color
- **Approach**：restrained（单一 accent + 中性 + 配给语义色）。
- **Accent**：`#FFC53D` 琥珀金；**只给「活的/当下的/你的」**（细丝、状态栏 live 点、Today 日期、活跃态、框选视口 L 角、checkbox 完成、主 CTA 边）。绝不做装饰性大面积填充。
- **每日变色（daily accent shift）**：单一 `--accent` 变量，每天从 palette 取一色；**克制=醒目**，只有上面那几处跟着变，其余全程单色。当天稳定、午夜变。浅主题下自动压暗。
  - Palette（承 notch）：`#FB9E66 #FF6F61 #FFC53D #B6E84F #34D6C0 #4FD6E8 #5EA0FF #7C9CFF #B98CFF #FF6FA5`
  - 对比规则（承 notch）：浅底 accent ×0.55 循环压暗直到对比 ≥ 3.2:1。
- **语义色（配给制，只在语义处点一下）**：成功/在线 `#34C759` · 警告/未读 `#FF9F0A` · 紧急 `#FF453A` · 信息 `#0A84FF` · 青 `#34D6C0` · 紫 `#7B61FF`。浅主题用压暗版。

## Spacing
- **Base**：8px 网格但收紧（密度是重点）。
- **固定骨架尺寸**：Rail 58px · Context 250px · Terminal 220px(可拖/可收) · Statusbar 26px · Titlebar 32px。笃定尺寸，不做流体稀汤。
- **账本左槽**：Today 读数左 gutter 60px 放 mono 时间戳/section tag。
- **分隔**：一切靠发丝线（`--hair` 1px），从不用重于此的分割线或盒子（除框选视口的显式 frame）。

## Layout
- **Approach**：grid-disciplined（严格网格 + 框选视口）。
- **Shell 网格**：`58px 250px 1fr [terminal]` × `32px 1fr 26px`（rail｜context｜center｜(terminal)｜statusbar），承 F8 IA。
- **中央工作区**：Tab 化；Today = 单列账本读数。
- **Border radius**：**默认无圆角**（粗野/仪表）。仅极少数元素（项目色块/头像）用 3-6px。图标按钮 8px。**禁止对一切元素统一大圆角**。

## Motion
- **Approach**：intentional，动效只为语义（滑/充能/脉冲——机器的动词，不弹跳不装饰）。
- **Easing**：全程一条招牌缓动 `cubic-bezier(.32,.72,0,1)`（气动感、快出慢稳）。
- **Duration**：micro(hover/focus) 120ms · 面板/Tab 220ms · 细丝滑移 420ms · 每日点火 600ms · agent 脉冲 700ms。
- **每日点火**：当天首次打开，Today 日期 + 细丝锚点从 0 升到满（~600ms 一次），此后 hue 全程保持不动（座舱=稳定=可信）。
- **`prefers-reduced-motion`**：杀脉冲与点火，保留瞬时 accent 态变化（语义不靠动作也在）。

## Anti-slop（禁止）
- 紫/violet 渐变做 accent；玻璃拟态滥用；一切居中 + 均匀间距；一切统一大圆角；渐变按钮做主 CTA；三列图标圆圈特性网格；`system-ui` 当展示/正文主字（除本系统明确的 mono/sans 硬切）；"Built for X / Designed for Y" 营销腔。
- 每日/跨轮避免收敛到同一套选择而不说明。

## Decisions Log
| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-07-01 | 主工作台复用 notch 美学（黑底+单一琥珀 accent+精密驾驶舱+每日变色+无 emoji） | notch 上已打磨成熟并验证，主前端此前是零设计线框，统一语言 |
| 2026-07-01 | 采纳 ORAGE 监控台/技术粗野皮（点阵/fiducial/坐标遥测/框选视口/CLI 面包屑） | 用户参考图；是"精密驾驶舱"再推一格，天然贴合 A |
| 2026-07-01 | 主方向 = 变体 A（Instrument Readout，无卡片单列账本） | 最忠于"一窗掌全局、掌控感>装饰"北极星，最差异化；B 卡片/C 留白与 ORAGE 冲突 |
| 2026-07-01 | 黑 + 白双主题，默认跟随系统 | 用户要求；靠 notch 对比度自适应保证 accent 在两底都可读 |
| 2026-07-01 | 监控 chrome 强度可切，日常默认偏弱 | 长时间使用散落准星/坐标 chip 会吵；展示可拉满 |
| 2026-07-02 | 加做 research + 探索批次 2（D 交易台/E 战术 HUD/F 器械面板/G 克制/H 磷光 CRT），A–G 合并对比后**复确认 A 为定稿** | 竞品调研（Bloomberg 密度印证黑+琥珀；工业粗野/TE/Vercel）撑开性格光谱；A 仍最忠北极星「一窗掌全局·掌控>装饰」。可回灌零件：D 多面板→Cockpit/Research 模式、F 的 MOD.xx+LED 状态语汇、G 问候大标题+留白→沉浸子态；H 仅作可选皮 |
