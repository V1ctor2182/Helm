# NOMI notch 重塑 loop · log

## 2026-07-07 迭代 1 — 启动
- 通读设计稿 `docs/design/helm-notch-nomi.html`(726 行)+ 现状(昨日 vibeisland 交互刚落地,全部保留只换皮)。
- 建 backlog:B1 主题基建 → B2 单体壳/折叠态 → B3 顶行+dock+模块重组 → B4-B8 五模块页 → B9 智能体 → B10 banner → B11 浅色收尾。
- 设计稿要点:dark 默认(#0f0f11 面板/#1d1d21 卡);折叠 310px(左 logo+minicover+波形—cam—右 ● live);开 440px 圆角 26;banner 460px;dock 5 圆钮(渐变描边环);媒体从总览封面进,剪贴板并入暂存,专注并入速记;智能体三子页上下滑(会话/端口/PR)+sdots。
- git 基线:昨日 vibeisland 改动(用户已实测验收)先独立 commit 在 feat/cockpit-fanbox,再切 feat/notch-nomi-m1 —— nomi 块提交不混入前作。
- vibehub MCP 未连接:record/add_question 落 backlog 的决策/Open questions 段代替。
- 环境:共享检出上有另一个活跃 loop(主 app NOMI,feat/nomi-reskin)——本 loop 迁入独立 worktree `../helm-notch-nomi`(feat/notch-nomi-m1),互不踩分支;vibeisland 基线 commit(341db7d)落在 feat/nomi-reskin 上(分支点),无害。
- 本 loop 不重启用户的 Helm Notch.app(不合 main 前现网保持 vibeisland 版),视觉门用 --snapshot。

## 2026-07-07 迭代 2 — B1 主题基建 ✅
- Core `NomiTheme.swift`:NomiPalette dark/light 成套(逐 token 对齐 CSS 变量)+渐变/状态色/壳几何常量;NotchModel.nomiDark(默认深)+nomi 计算色板。
- App `NomiStyle.swift`:gradient(135°/90°/180°)、wcard(dark=发丝边,light=柔影)、GradientButton/InkButton/PillButton、SparkDot。
- Tests `NomiThemeTests` 5 条全绿;全套 suite 无失败无崩溃。
- 视图尚未接线(B2 起换装)——本块纯地基,无视觉变化。
