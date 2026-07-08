# Helm Loop 管理规范

> 2026-07-08 定稿。来源:主 app NOMI loop(R/K/T 批次)与 notch NOMI loop(B 批次)
> 两条线并跑一周的实战教训。新开或调整 loop 前先读这份。

## 0. 什么时候开 loop

Loop 适合**块状可验收、批量同质**的工作:设计稿逐块进代码、跨页换皮、批量修复。
不适合:一次性小改(直接说)、探索性设计(人机对话迭代更快)、跨仓库大迁移(先拆方案)。

开新 loop 前必答:**"这是不是现有某条 loop 的下一批次?"**
——是,就往它的 backlog 写块(见 §4);只有交付物不同才开新条。

## 1. 划分:一条 loop = 一个可合并的交付物

- 按**交付物**划,不按功能点:主 app 一条、notch 一条。"AI 分诊"不是 loop,
  是主 app loop 的 T 批次;"拖拽 dropmode"不是 loop,是 notch loop 的一个块。
- 每条 loop 四件套,缺一不开跑:
  | 件 | 例(notch 线) |
  |---|---|
  | 专属分支 | `feat/notch-nomi-m1`(块提交都在这,不合 main) |
  | 专属工作副本 | worktree `../helm-notch-nomi` |
  | 专属工作区 | `docs/loops/nomi-notch/` |
  | 只读设计基线 | `docs/design/helm-notch-nomi.html` |
- **活跃 loop ≤ 2**。第三个需求出现时,先归并成批次,归并不了再排队。

## 2. 隔离:一个工作副本只许一条 loop 碰

血的教训(2026-07-07):两条 loop 共用主检出,一条切分支把另一条的下一次
commit 悬空了。规则:

- 主检出归**一条** loop;其余 loop 一律 `git worktree add ../helm-<名> <分支>`。
- loop 不许 checkout 切别人的分支;发现检出分支不是自己的 → 立即停手退回。
- 共享检出上的**未提交改动**只许自己 loop 的文件;跨界文件(如另一条线的
  设计稿)改完要么立即 commit 要么复制走后 `git checkout --` 还原。
- worktree 可能成为**承重墙**(hook/app 从里面跑),拆除前先查:
  `grep worktree路径 ~/.claude/settings.json` + `pgrep -fl <app>`。

## 3. 节奏:批次制 + 绿门

- 工作切成**批次**(B1-B11 / K1-K8 / T1-T5),每批开跑前把**块清单**写进
  backlog(一块 = 一次可验收的提交量)。
- 每块**绿门**:`build && test` 全绿才 commit;UI 块加**快照视觉门**
  (`--snapshot` 对照设计稿,截图存 `shots/`)。
- commit 规范:`feat(<线名>): <块名>——<一句话> [loop]`;用户反馈修复标
  `[用户反馈]`,用户拍板标 `[用户拍板]`。推分支跑 CI,**不合 main,合并留用户**。
- 用户实测反馈**随时插队**:反馈修复优先于下一块,修完立刻重打包给用户复验。

## 4. 喂需求与拍板

- 新需求 → 目标 loop 的 `backlog.md` 追加块(写清验收口径),该 loop 的会话里
  说"开跑批次 N"。**不为需求开新 loop。**
- 产品行为拿不准 → backlog 记 `Q<N>` open question,**按默认走并注明,不猜**;
  用户拍板后标 `~~Q~~ 已拍板` 并落地。
- 设计变更先进**只读设计稿**(HTML 里注明"YYYY-MM-DD 用户拍板"),用户过目
  点头后才进代码。稿是真相源:改代码对齐稿,不反向改稿凑代码。

## 5. 契约归属(跨 loop 协作唯一规则)

- 后端 API 契约**只归主 app loop** 改;其他 loop 只消费。
  (前科:主线收紧 notes kind,notch 的任务落库 422 ——契约变更方要在自己
  backlog 里挂一条"通知消费方"的块,如 T5。)
- 消费方发现契约破裂:自己侧做**真通道降级**(不造假数据),同时把断点记进
  两边 backlog。

## 6. 数据诚实(假灯禁令在 loop 里的执行)

- seed/演示数据只许两种归宿:换**真数据源**(剪贴板 watcher、lsof 端口),
  或页面上**明示「示例数据 · 接入待定」**。
- 没有能力就不放交互:没有 seek API 就不做假进度点击;没有数据源就留空
  并记 Q,不放假天气。

## 7. 生命周期

```
开跑:四件套就位 → backlog 块清单 → cron(会话内)或 self-pace
迭代:一块一 commit 一 push;log.md 每迭代一条;截图/报告进工作区
插队:用户反馈 > 下一块
收尾:全部块对齐或全卡住 → 删 cron → 开 PR(留用户合) → 终报 reports/
     → 工作区留档不删 → 记 memory(状态/承重物/遗留 Q)
```

- Cron loop 是**会话级**的:会话关了 loop 就停(7 天也会自动过期);要长期
  跑的用 /schedule 云端。
- 收尾后冒出的反馈,直接在原会话续修(commit 进原分支/PR),不复活 cron。

## 8. 现役与归档

| Loop | 分支 | 工作区 | 状态 |
|---|---|---|---|
| 主 app NOMI | feat/nomi-reskin → feat/nomi-kinds | docs/loops/nomi/ | 已收尾(批次 3 T1-T5 全清,PR 待用户合;终报 reports/batch3-final.md) |
| notch NOMI | feat/notch-nomi-m1 | docs/loops/nomi-notch/ | 已收尾(PR #55 已合;worktree 承重:hook+app,合 main 后迁回正式路径) |

> 归档 = 状态改「已收尾」留表内,工作区永久保留;下次同交付物的新工作
> 开新批次或新分支,不复用旧分支名。

---

## 附录 A · 可直接粘贴的启动命令

### A1 重启主 app loop(批次 3,在主仓库目录新会话粘贴)

```
/loop 1m 按 docs/loops/LOOP-GUIDE.md 规范跑主 app loop:读 docs/loops/nomi/backlog.md,先清未完成的 K 块,再吃批次 3 的 T1-T5(AI 分诊管线/人话排期/前端对齐 kinds 稿/日记每天一篇)。只读设计基线 docs/design/helm-journal-kinds.html;分支 feat/nomi-kinds;每块前端 build+后端测试绿才 commit [loop],不合 main 留我合;契约变更按 T5 通知 notch 线;log/报告/截图记 docs/loops/nomi/;拿不准的产品行为记 Q 别猜。全部块对齐或全卡住才停。
```

会话还开着就不用这条,直接说:「批次 3 开跑,按 docs/loops/nomi/backlog.md 的 T1-T5」。

### A2 新开一条 loop 的模板(替换尖括号)

```
/loop 1m 按 docs/loops/LOOP-GUIDE.md 规范跑 <交付物名> loop:读 <只读设计基线文件> 与现状,把 <目标> 逐块做到一致。分支 <feat/xxx>(不合 main,留我合);工作副本 <主检出 或 worktree ../helm-xxx>;每块 <build/test 命令> 绿才 commit [loop];快照/截图视觉对比;log/report/backlog 记 docs/loops/<名>/(先建 README 说明结构)。后端契约不动(契约只归主 app loop);拿不准的产品行为记 Q 别猜。全部块对齐或全卡住才停。
```

开条前过一遍 §0 和 §1 的四件套检查。
