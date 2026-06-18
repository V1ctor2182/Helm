# Loop 启动命令

> 每次想自动化开发某个 Room 时,照这里做。流程定义见 [`loop-procedure.md`](./loop-procedure.md)。

## 启动前

不用指定 Room,也不用手动切分支——loop 的 step 0 会**自动选下一个该做的 Room**(按 `loop-procedure.md` 里的「Room 开发顺序」),并自己切 `feat/<room>` 分支。

## 启动命令(默认:自动选 Room)

`/loop 5m` = 每 5 分钟自动跑一轮(仅在会话空闲时触发,不会在一轮还在跑时重复进入),适合开发。直接粘这一行:

```
/loop 5m 读 docs/loop-procedure.md(及其引用的 METHODOLOGY.md),按其「循环流程」持续开发:自动选下一个该做的 Room,做完一个 Room 就停下让我合 PR,我合入 main 后下一轮自动接着做下一个,直到所有 Room 做完或触发熔断。
```

## 想指定某个 Room(可选)

在命令里点名即可,会跳过自动选:

```
/loop 5m 读 docs/loop-procedure.md(及其引用的 METHODOLOGY.md),按其「循环流程」开发 platform-shell 这个 Room,直到它做完或触发熔断。
```
