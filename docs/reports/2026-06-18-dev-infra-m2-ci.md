# dev-infra · m2 CI 工作流

- **日期**：2026-06-18
- **Room / milestone**：dev-infra / m2（CI 工作流）

## 目标
把本地验证门（CONVENTIONS.md §4：pytest + node 测试）自动化成 GitHub Actions，让每个 PR 合 main 前有客观把关。

## 做了什么
- 新增 **`.github/workflows/ci.yml`**，两个 job：
  - `backend`：setup-python 3.13 → `pip install -e ".[dev]"` → `pytest -q`
  - `desktop`：setup-node 22 → `node --check main.js backend.js` → `node --test`
- 触发：PR → main（合并前的门）+ push → main（合并后）。`concurrency` 取消被取代的运行。
- desktop job 刻意不跑 `npm install`：测试只用 node 内置模块、`--check` 仅解析不执行 require，故无需 electron 依赖 → 更快。

## 决策（record_decision）
- 验证门 CI 跑在 **ubuntu-latest**：后端测试与 node --test 与 OS 无关，ubuntu 快且省；macOS 专属的**打包 CI（.app 构建 + 签名）**另起 job、暂缓（重且依赖签名）。
- Python 3.13（对齐 dev；`requires-python>=3.11` 已声明下限）、Node 22 LTS。

## defer
- macOS 打包 CI（PyInstaller + electron-builder 的 .app 构建）暂缓——重，且签名/公证本就 defer（见 platform-shell add_question）。引入 ChromaDB/onnxruntime 等原生依赖的 room 落地时再加。

## 验证
- YAML 结构校验通过（jobs = backend/desktop，triggers = push/pull_request）。
- CI 将运行的**确切命令本地复跑**：`pytest -q` → 39 通过；`node --check` ok；`node --test` → 9 通过。
- 注：GitHub 上的**实际 CI 运行**会在 dev-infra 的 PR 开起时触发（触发条件是 PR→main）；本轮无法在 feat 分支上触发实跑。

## 熔断状态
- 未命中任何熔断条件。

## 下一步
- m3：可复现 dev 环境（bootstrap 脚本/Makefile + 依赖/版本固定 + dev 文档）。
