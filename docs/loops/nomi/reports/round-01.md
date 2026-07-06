# R01 · 块① NOMI token 重铸
**做了什么**: frontend/src/app.css 整文件重铸——NOMI 浅色为默认主形态,深色=NOMI 深面板(推导自 notch 稿);新增 NOMI 族 token(card/pill/渐变/阴影/圆角/onink);点阵 grid 透明化;滚动条圆角化;selection 渐变紫。变量名不变→全站旧组件即刻换皮、功能零损。
**门**: npm build ✓ · check 0 错 · test 204/204。
**视觉**: shots/r01-tokens-light.png——皮已换(浅底/白 chrome/无点阵),骨架仍旧(Rail 竖条/账本布局),按块序后续轮逐个重塑。
**取舍**: ①每日 accent 保留(功能不减),默认值改渐变紫端,固定与否待拍板(backlog);②深色 token 自行推导(主站稿只有浅色),标注待目视。
**下一块**: ② 侧栏全局导航+logo(Rail → NOMI 白侧栏)。
