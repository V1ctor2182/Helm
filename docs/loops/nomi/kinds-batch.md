# 批次 2 · 三态 layout + 智能判类(2026-07-07 用户拍板)
设计基线(只读,新增): docs/design/helm-journal-kinds.html — 三态 layout/智能捕获/详情态/专注链路,全按此稿。

块清单(建议序,可自调):
- [x] K1 速记瀑布墙:Timeline filter=note/collect 视图改 masonry 卡墙(便签/收藏卡混排,天界标;卡=稿样式)
- [x] K2 速记详情重排:NoteDetail 改「原文主角(17px+内联链接高亮)/提到的内容附件卡/标签+线索胶囊/AI 注脚(hover 展开)/线索→行动主钮」
- [x] K3 后端多链接解析:enrich 从"第一个 URL"扩展为全部 URL→meta.links[](向后兼容保留单链接字段);pytest 覆盖;notch 契约不破(加字段)
- [x] K4 日记纸页:filter=journal 视图改纸栏(统计条/今天的页置顶可写/一天一页/AI 小结缀尾)
- [x] K5 日记页详情:全页阅读态+当日碎片时间线(该日 notes)+专注块
- [x] K6 任务操作台:filter=task 视图改 双列(待办 checkbox 清单+定时卡:渐变开关/cron chip/运行历史抽屉);派发条胶囊化
- [x] K7 智能判类:后端轻量 classify(enrich 前置或独立)+捕获条(CaptureDock/smartcap)实时判定徽章(先规则,AI 兜底)+可点改判;发送按判定落库
- [ ] K8 专注链路:全局专注状态(store)/速记墙顶活卡计时/待办 hover「开始专注」/停止写入今日日记
硬门/流程照 loop-procedure 阶段 4;功能不减;契约变更(K3/K7)同步 notch 检查+pytest。
