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

## 想指定某个 Room(可选)

在命令里点名即可,会跳过自动选:

```
/loop 5m 读 docs/loop-procedure.md(及其引用的 METHODOLOGY.md、CONVENTIONS.md),按其「循环流程」以真·无人值守档位开发 platform-shell 这个 Room,直到它做完(自动合 main)或触发熔断。
```
