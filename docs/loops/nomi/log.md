## R01 · 2026-07-07 00:05 · 块① NOMI token 重铸
- 对齐: app.css 全套 token 换血——浅色转正(#f6f6f7 画布/白 chrome/墨色字族),深色改 NOMI 深面板(#0f0f11/#1d1d21 卡),新增 --card/--pill/--g1/--g2/--grad/--shadow(-lg)/--radius 族+--onink;--grid 置 transparent(点阵退场);系统跟随逻辑反转(默认浅)。变量名向后兼容,旧组件零改动整体换皮。
- 门: build ✓ / check 0/0 / test 204 全绿
- 视觉: shots/r01-tokens-light.png(旧骨架+新皮肤,预期;逐块重塑在后续轮)
- 疑问: 每日 accent 机制(theme store 覆写 --acc)与 NOMI 固定橙紫渐变的关系待用户拍板——暂保留每日色,accent 默认改渐变紫端 → backlog
- commit: feat/nomi-reskin
