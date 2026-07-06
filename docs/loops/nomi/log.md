## R01 · 2026-07-07 00:05 · 块① NOMI token 重铸
- 对齐: app.css 全套 token 换血——浅色转正(#f6f6f7 画布/白 chrome/墨色字族),深色改 NOMI 深面板(#0f0f11/#1d1d21 卡),新增 --card/--pill/--g1/--g2/--grad/--shadow(-lg)/--radius 族+--onink;--grid 置 transparent(点阵退场);系统跟随逻辑反转(默认浅)。变量名向后兼容,旧组件零改动整体换皮。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r01-tokens-light.png(旧骨架+新皮肤,预期;逐块重塑在后续轮)
- 疑问: 每日 accent 机制(theme store 覆写 --acc)与 NOMI 固定橙紫渐变的关系待用户拍板——暂保留每日色,accent 默认改渐变紫端 → backlog
- commit: feat/nomi-reskin
## R02 · 2026-07-07 00:10 · 块② 侧栏全局导航 + logo
- 对齐: Rail.svelte 整件重写——ORAGE 细丝竖条(58px icon rail/锚点/脉冲)退场,NOMI 白侧栏(250px)上位:娃娃脸 logo+Helm 品牌行/中文标签导航(图标+文字,--pill 胶囊激活)/底部两圆钮(记一条=openCapture,⌘K=openPalette)。Shell grid 列宽 --rail-w→--side-w。memory 入口保留(设计稿未画,功能不减)。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r02-sidebar.png——与稿侧栏一致(hover/激活胶囊/圆钮)
- 缺口: 导航计数(记录 12/对话 3)未接真数据 → backlog P2;titlebar/statusbar 仍 ORAGE mono(后续壳块)
## R03 · 2026-07-07 00:17 · 块③ 今日板块
- 对齐: Today.svelte 整件重写——问候(时段词,Victor)+日期摘要行 → CaptureDock → NOMI 七卡网格(任务/日程/日记/智能体/最近项目/今日收藏/简报·世界输入)。真数据 derived 全量移植(tasks/notes/agent/cockpit/calendar/briefing);A×C v3 时钟锚/区块聚光/右柱退场,briefing 功能收进第七卡(功能不减)。新增今日收藏卡(AI 管线产出:meta.type 色点+标签)。
- 修型: 4 个 check 错(Task.schedule_kind/CalEvent.summary/inspiration 枚举/prompt null)当轮修
- 门: build ✓ / check 0/0 / test 204 全绿(Today.test 断言随新结构更新,语义保留)
- 视觉: shots/r03-today.png——问候/卡网格/空态/HN 简报真数据 ✓
- 缺口: CaptureDock 仍 ORAGE 皮(独立块) → backlog P1
