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
## R04 · 2026-07-07 00:20 · CaptureDock NOMI 化(backlog P1 清)
- 对齐: 逻辑层零改动,纯换皮——白卡容器(圆角+阴影,L 角/边框退场)/kind 胶囊(黑激活)/任务双轨渐变胶囊/灰胶囊输入行/渐变发送钮(disabled=灰胶囊)/问大脑答案卡(白卡+spark)。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r04-capture.png——今日板块(问候+坞+七卡)整体成型
## R05 · 2026-07-07 00:24 · 记录页整体换皮
- 对齐: JournalView 皮肤层——tab 白胶囊容器+黑激活/输入行灰胶囊盒+渐变主钮/天组白卡化(圆角+阴影)/收藏卡圆角浅底/AI 小结框圆角化(L 角退场)/日界标 sans 化/标题中文化(记录)。结构与功能(编辑/四向转化/确认删/收藏卡/待办/定时/日历)零改动。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r05-journal.png——速记流已是 NOMI 脸(白卡天组+圆角收藏卡)
- 缺口: 三视图信息架构(Timeline/Canvas/Calendar 黑胶囊)未动——现仍是 速记/日记/任务/日历 四 tab;Canvas 视图不存在 → backlog P1;Calendar.svelte 仍 ORAGE 皮 → backlog P1
## R06 · 2026-07-07 00:29 · 对话板块换皮
- 对齐: Chat.svelte——消息流从账本(YOU/MODEL 左标)改 NOMI 气泡(用户黑胶囊右对齐/AI 白卡+spark「Helm 大脑」);会话列表白卡化(激活=描边环);composer 灰胶囊+黑发送;新会话表单胶囊输入;act 钮系胶囊化。流式/停止/删除/对比/Provider 功能零动。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r06-chat.png(会话列表真数据白卡 ✓)
- 缺口: CompareView/ProviderSettings 两个子面板未换皮 → backlog P2
## R07 · 2026-07-07 00:34 · 研究 + 设置换皮
- 对齐: Research(标题 sans 中文/问题输入灰圆角盒/act 渐变主钮/report·framed 白卡化)+Settings(标题中文/act·sel 胶囊化;主题段/AI provider 段功能原样)。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r07-research.png + r07-settings.png
- 缺口: 驾驶舱家族(3187 行)未换皮 → backlog P1(单独轮);Research 历史列表/badge 细节待精修 P2
