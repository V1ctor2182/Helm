# Loop 启动命令

> 每次想自动化开发某个 Room 时,照这里做。流程定义见 [`loop-procedure.md`](./loop-procedure.md)。

## 启动前

不用指定 Room,也不用手动切分支——loop 的 step 0 会**自动选下一个该做的 Room**(按 `loop-procedure.md` 里的「Room 开发顺序」),并自己切 `feat/<room>` 分支。

> 档位 = **真·无人值守**:loop 自己 plan / 决策 / 记录 / 优化 / 反思 / 合并,全程不停,
> **只有遇到「难撤 / 定方向的产品决策」或触发熔断才停下找你**。技术决策(含数据模型、对外契约、
> 安全边界、核心选型)+ 可逆的产品小决定(文案、默认排序…)loop 都自决并分级 record 到 VibeHub;Room 做完全自动合 main。
> **两轨**:A 轨跑 PRD 路线图(主干);B 轨每 milestone 后反思建 ticket(技术 + 可逆产品小改自消化 / 难撤产品标 needs-human 等你批),Room 收尾限额 drain。

## 启动命令(默认:自动选 Room,全自动)

`/loop 5m` = 每 5 分钟自动跑一轮(仅在会话空闲时触发,不会在一轮还在跑时重复进入),适合开发。直接粘这一行:

```
/loop 5m 读 docs/loop-procedure.md(及其引用的 METHODOLOGY.md、CONVENTIONS.md),按其「循环流程」以真·无人值守档位持续开发:自动选下一个该做的 Room,逐个 milestone 开发→review→优化(前后端)→验证→反思建ticket→写 report;技术决策(含数据模型/对外契约/安全边界/核心选型)+ 可逆产品小决定(文案/默认排序…)自己定并分级 record 到 VibeHub,只有难撤/定方向的产品决策才停下问我;每 milestone 后用 create_ticket 把改进点落进 VibeHub(技术+可逆产品小改自消化/难撤产品标 needs-human 等我批);做完一个 Room 先限额 drain 技术 backlog,再跑全局优化扫描+全量验证全绿后自动合 main,自动接着下一个;所有 Room 做完后清剩余技术 backlog,直到只剩 needs-human ticket 才停。
```

## 🌙 放手模式(整夜跑,什么都不停)

档位 = **放手模式**:在真·无人值守之上再松一档——**把每一个本该"停下问人 / 熔断停"的点,都换成「自己做最可逆的暂定处置 + 开一张 `[needs-human]` ticket 标注是哪块业务逻辑 + 继续」,整夜不停。** 早上你扫一遍 `[needs-human]` ticket 队列就知道夜里哪些业务逻辑是它替你暂定的。定义见 [`METHODOLOGY.md` 第四节「放手模式」](./METHODOLOGY.md) 与 [`loop-procedure.md`](./loop-procedure.md) 顶部 🌙 段。

> 取舍:**暂定的业务决定会被实现、验证全绿就合进 main**(`[needs-human]` ticket 不挡合并,只作早上 review 队列)。安全网收窄成三条:①暂定实现倾向可逆 ②每条都有 ticket 可事后否决 ③不可逆/破坏性副作用(删数据、发真实外部请求、花钱…)绝不猜、skip + ticket。接受这个取舍再跑整夜。

直接粘这一行跑整夜:

```
/loop 5m 读 docs/loop-procedure.md(及其引用的 METHODOLOGY.md、CONVENTIONS.md),按其「循环流程」以【放手模式】持续开发,整夜不停:自动选下一个该做的 Room,逐个 milestone 开发→review→优化(前后端)→验证→反思建ticket→写 report。关键:把每一个本该停下问人或熔断停的点,都改成「自己做最可逆的暂定处置 + 用 create_ticket 开一张 [needs-human] 标题点明是哪块业务逻辑/暂定了什么/备选是什么 + 代码留 TODO + 继续」——难撤/定方向的产品决策这样处理,测试连败/打转/范围漂移/依据缺失等熔断条件也这样处理(绕到下一个可推进的 milestone 或 Room)。唯一硬底线:CI/验证非全绿绝不合 main,把该 Room 留分支+开 [needs-human] ticket+切下一个 Room 继续。不可逆/破坏性操作(删数据/丢弃式迁移/发真实外部请求/花钱/不可撤副作用)绝不靠猜执行,skip+开 ticket+继续别的工作。技术决策+可逆产品小决定照常自己定并分级 record 到 VibeHub。[needs-human] ticket 不阻塞合并,只作我早上的 review 队列。只有当所有 Room 都卡在合并门、没有任何可推进的工作时才报告并停;否则一直跑。
```

## 想指定某个 Room(可选)

在命令里点名即可,会跳过自动选:

```
/loop 5m 读 docs/loop-procedure.md(及其引用的 METHODOLOGY.md、CONVENTIONS.md),按其「循环流程」以真·无人值守档位开发 platform-shell 这个 Room,直到它做完(自动合 main)或触发熔断。
```
