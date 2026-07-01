# Notch 对齐 Loop · 启动命令

> 这条 loop 的本体:**`helm-notch-pro.html` 是锁定的最终设计稿(只读);把它的 UI 一块块做进原生 Swift notch App,直到 Swift App 和 HTML 一模一样。**
> 流程定义见 [`notch-loop-procedure.md`](./notch-loop-procedure.md)。
> **本档位:默认每对齐 1 块就停下让你 review(不自动 commit)。**
>
> **🎯 范围:只做「前端和 HTML 一模一样」,后端数据不碰。** 数据一律用 HTML 同款种子/mock(PORTS/PRS/CLIP/HEAT/LYRICS/RECENT/EVENTS 等照搬 HTML 写死的值);要后端加端口的(api-focus/文件上传/问大脑/真实 diff/PR/端口/剪贴板/歌词/per-day 事件…)留 TODO + mock 顶上,**绝不为接后端停留或去猜后端接口**。判断"对齐完"只看视觉/交互像不像 HTML,不看数据真不真。

## 别搞反的两个文件

- **只读设计基线 / 唯一真相**:`notch/docs/helm-notch-pro.html`(loop 绝不改它)。
- **要改的目标**:原生 Swift App —— `notch/Sources/HelmNotchApp/*`(NotchView 等)+ `HelmNotchCore/*`(NotchModel/Theme 等)。

现状(2026-07-01):Swift 已迁到 HTML 的 dock + 单模块设计,主体模块/交互都在;loop 现在 = 逐块**核对「一模一样」并补差的视觉细节**(色/字号/间距/动画/尺寸/hover 态…),数据用 HTML 同款 mock。

## 命令(默认:逐块对齐,1 块一停)

直接粘这一段:

```
先仔细读 notch/docs/notch-loop-procedure.md;再把 notch/docs/helm-notch-pro.html(锁定的最终设计稿/唯一真相,只读、绝不改)从头到尾读懂,并读现状 Swift(notch/Sources/HelmNotchApp/NotchView.swift、HelmNotchCore/NotchModel.swift、Theme.swift)搞清还差哪些视觉细节(主体 dock+模块已对齐,现在是逐块核对「一模一样」+补差)。范围:只做前端和 HTML 一模一样,后端不碰——数据用 HTML 同款 mock(照搬 HTML 写死的种子值),要后端加端口的留 TODO 别停。用 VibeHub:开工前 get_feature_context(a1ba5dd6-633c-4a30-834d-910d0c902e16=notch-panel room)+ get_file_context + get_team_conventions 拉上下文,已拍板方向(每日 accent 调色板/accent 用法/禁 emoji/原生 Swift 路线/dock 架构/自适应高度)当硬约束。然后按「每一轮」对齐:挑 HTML 里一个还没对齐的模块/方面/细节,精读 HTML 该块的确切布局/尺寸/色/交互,实现进对应 Swift 文件做到一模一样 → swift build + swift test 全绿(硬门)→ 用 browse 把 HTML 该 view 截成靶图做视觉比对(能跑就 screencapture 真机对比)→ 把这块的实现 record_decision、硬边界 add_constraint、原生难 1:1 的点 add_question(都绑 notch-panel room)→ 写 refs/log.md。每对齐 1 块就停下,给一份 report(HTML 靶图+实现说明+关键取舍,能截就附 Swift 实际截图),等我确认或给修正;绝不改 helm-notch-pro.html,不自动 commit(notch 不用 --auto,等 macOS CI 绿手动合),HTML 某设计原生无法 1:1 就 add_question 别擅自偏离。
```

## 变体

- **一次对齐几块再停**:把命令里的 `每对齐 1 块` 改成 `每对齐 2 块`(块大,建议别超 3)。
- **指定从哪块开始**:命令里加一句"先对齐 <折叠条 / dock 切模块 / media 歌词 / Dev 分页 / 日历 / 每日 accent 主题>"。
- **🔭 守候模式**(持续对齐,/loop):
  ```
  /loop 20m 读 notch/docs/notch-loop-procedure.md(通读设计基线 helm-notch-pro.html + 读现状 Swift + 用 VibeHub pull notch-panel room),按「每一轮」把 HTML 设计逐块做进 Swift App 到一模一样:挑一块→精读 HTML→实现进 Swift→swift build+test 绿→browse 截靶图视觉比对→record 进 notch-panel room→写 refs/log.md;每对齐 1 块停下让我 review(不自动 commit、不改 HTML);全部对齐完就报告并停。
  ```

## 🌙 夜间模式(完全自己跑,整夜不停)

档位 = 在默认档之上松开「停下 review」:每对齐一块**不再停下等你**,自检过了就自己 commit 到分支,接着下一块,整夜跑。把每个本该「停下 review / 问你 / add_question 等人」的点,都换成「**做最忠于 HTML 的暂定实现 + record_decision/add_question 记下来当 context + 代码留 TODO + 继续**」。

取舍(接受才跑整夜):
- **只做前端保真、后端不碰**:数据用 HTML 同款 mock(照搬写死的种子值);要后端加端口的(api-focus/文件上传/问大脑/真实 diff/PR/端口/剪贴板/歌词/per-day 事件…)留 TODO + mock 顶上,**绝不为接后端停留或去猜后端接口**。"对齐完"只看视觉/交互像不像 HTML。
- **每轮出 report**:夜里也每块给一份 report(见 procedure「每轮 report」)——记进 log + 收尾消息,你早上能一路回看。
- **硬底线不松**:`swift build` + `swift test` **非全绿绝不 commit**——某块 3 轮修不绿就 skip 它、add_question、切下一块,坏代码不进分支。
- **只攒分支 commit、不合 main**:notch 不用 `--auto`、要等 macOS CI——夜里只在 `feat/notch-*` 上 commit + push,**合并留给你早上**。
- **HTML 某点原生难 1:1**:不停。取最忠于设计的暂定做法 + `add_question`(点明哪块 / 暂定了什么 / 备选)+ TODO + 继续。
- **视觉对齐无人目视**:夜里没法你确认「一模一样」。用 browse HTML 靶图自比对到位即可;拿不准的 `add_question` 标「待你目视」,继续。
- **绝不改 `helm-notch-pro.html`**(设计基线只读);不可逆 / 破坏性操作绝不猜。
- **唯一会真停**:所有块都对齐完,或全卡住(都修不绿 / 全在等你)→ 报告并停。早上你看分支 commit + `add_question` 队列即可。

直接粘这一段跑整夜:
```
/loop 5m 读 notch/docs/notch-loop-procedure.md(通读只读设计基线 helm-notch-pro.html + 读现状 Swift + 用 VibeHub pull notch-panel room context),以【夜间模式】把 HTML 设计逐块做进 Swift App 到一模一样,整夜不停、完全自主。范围:只做前端和 HTML 一模一样,后端不碰——数据一律用 HTML 同款 mock,要后端加端口的留 TODO 别停别猜后端。每块 挑→精读 HTML→实现进 Swift→swift build+swift test 全绿(硬门,非绿绝不 commit;某块修 3 轮还不绿就 skip+add_question+切下一块)→browse 截 HTML 靶图视觉比对→把这块 context record_decision 进 notch-panel room(暂定/存疑的 add_question 标 [needs-human])→写 refs/log.md→每轮出一份 report(收尾消息+log)→自己 commit 到 feat/notch-* 分支并 push,接着下一块。关键:每个本该停下 review 或问我的点,都改成"做最忠于 HTML 的暂定实现 + record/add_question 记下来 + 代码留 TODO + 继续",不停下等我。硬底线:绝不改 helm-notch-pro.html;swift build/test 非全绿绝不 commit;不合 main(notch 不用 --auto,合并留我早上);不可逆/破坏操作不猜。全部块对齐完或全卡住才报告并停。
```

## 调参

- **对齐粒度 N**:命令里 `每对齐 1 块` 的块数。原生块大,默认 1 最稳。
- **保真度**:默认「一模一样」。某些地方你想用更原生的做法(而非死磕 HTML 像素),在命令里说,或让 loop 用 add_question 提给你定。
