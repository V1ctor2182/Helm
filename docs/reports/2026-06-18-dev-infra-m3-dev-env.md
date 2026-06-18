# dev-infra · m3 可复现 dev 环境

- **日期**：2026-06-18
- **Room / milestone**：dev-infra / m3（可复现本地 dev 环境 + 依赖管理）

## 目标
让人与 agent 都能一键起步、版本一致：一条命令装好后端+桌面依赖,并提供常用 dev 命令。

## 做了什么
- **`scripts/bootstrap.sh`**：挑 Python≥3.11（试 `HELM_PYTHON`/3.13/3.12/3.11/3 并校验版本）→ 建 `.venv` → `pip install -e ".[dev]"` → `cd desktop && npm ci`。幂等。
- **`Makefile`**：`bootstrap` / `test`(后端 pytest + 桌面 node) / `test-backend` / `test-desktop` / `run`(python -m helm) / `app`(打包) / `clean`。
- **`.python-version`** = 3.13（固定解释器）。
- **`docs/DEVELOPMENT.md`**：前置、一键起步、命令表、桌面外壳跑法、可复现性说明、env 配置。

## 决策（record_decision）
- 可复现性策略（两向门）：Node 用 `npm ci`（lockfile 精确还原）；Python 用 `.python-version`(解释器) + `pyproject`(依赖范围, `requires-python>=3.11`)。逐包精确锁(pip-tools/requirements.lock)当前阶段不做,后续需要再加——已在 DEVELOPMENT.md 注明。
- bootstrap 默认只装 `[dev]`；打包用的 `[packaging]`(pyinstaller) 按需单装（文档+`make app` 注释提示）。

## defer
- 无单向门。pip 逐包锁定推后（非阻塞,文档已注）。

## 验证
- **端到端实跑**：`./scripts/bootstrap.sh` 重建 `.venv` + `npm ci`(284 包)成功 → `make test` 后端 pytest 39 通过 + 桌面 node 9 通过。即"全新环境 → 门通过"DoD 达成。

## 熔断状态
- 未命中任何熔断条件。

## 下一步
- m4：技术栈最终确认 + 关闭 PRD §7 开放问题（前端栈已定 Vite+Svelte;记录最终选型、标注 spec 状态）。这是 dev-infra 最后一个 milestone,完成后收尾开 PR。
