# cockpit · m6 Git diff

- **日期**：2026-06-19
- **Room / milestone**：cockpit / m6（Git diff：GitService + Monaco DiffEditor）

## 目标
选中文件一眼看 git diff：HEAD vs 工作区，Monaco 只读 DiffEditor 并排。

## 做了什么
- **后端 `git.py`**：GitService —— `repo_root`（`git -C rev-parse --show-toplevel`）、`file_diff`（`git show HEAD:rel` 取 HEAD 内容 + 读工作区 + porcelain status；untracked→head=""、deleted、modified、unchanged；两侧均按 1MB 封顶）、`status`（porcelain 列表）。argv 列表 + `HEAD:` 前缀 + `--` 分隔防选项注入。
- **`routes.py`**：`GET /api/cockpit/git/diff?path=`（不在仓库→404）、`/git/status?path=`。
- **前端 `gitClient.ts`**（纯函数）：fetchDiff + langForExt（ext→Monaco 语言）。
- **`DiffView.svelte`**：Monaco 只读 DiffEditor（original=HEAD/modified=工作区，renderSideBySide，automaticLayout）；EditorWorker；onDestroy 释放 editor + models。
- **`PreviewPane.svelte`**：code/markdown 文件加「预览 | Diff」切换；Diff **懒加载** DiffView（`{#await import()}`）——把 Monaco 从主包 code-split 出去、且不进测试/jsdom 模块图；切文件重置回预览。
- 依赖 `monaco-editor`。
- **测试**：后端 git diff（HEAD vs 工作区 modified）/ untracked / 不在仓库 404；前端 gitClient（fetchDiff/langForExt）。

## 决策（record_decision）
- Monaco 懒加载（动态 import）——既 code-split 重型 Monaco，又避开 jsdom 无法加载 monaco+?worker 的测试问题。
- diff 两侧按 1MB 封顶（与预览一致）；git 调用 argv + HEAD:/-- 防注入。

## defer
- 语法高亮深度、暂存/提交、多文件 diff、blame、binary diff；status() 的 rename 解析（当前 UI 只用 file_diff）。

## 验证
- 后端 `pytest` **56 通过**（+3 git）；前端 `svelte-check` 0/0、`vitest` **68 通过**（+4 gitClient）；build ok（Monaco 已 code-split，无 chunk 警告）。
- review（agent）：git 子进程注入面（argv/HEAD:/--）确认安全、file_diff 各状态正确、懒加载语法正确。修 1 med（工作区读未封顶→加 1MB cap）+ 1 low（Monaco model 泄漏→onDestroy 释放）。Monaco 实际渲染人工目视。

## 熔断状态
- 未命中。（一处：引入 monaco 后 2 个测试文件加载失败 → 改 DiffView 懒加载，一次修好。）

## 下一步（Room 收尾）
- **cockpit 全部 milestone（m1–m6）完成** → 停下等人开 PR 合 main。合入后下一个 Room：`chat-multimodel`（Chat 与多模型）。
