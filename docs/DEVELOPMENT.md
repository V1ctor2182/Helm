# 本地开发

> 可复现的一键起步。约定见 [`CONVENTIONS.md`](./CONVENTIONS.md)。

## 前置
- **Python ≥ 3.11**（仓库 `.python-version` 固定 3.13；系统自带 `python3` 在 macOS 常是旧版，脚本会自动挑合适的，或设 `HELM_PYTHON`）。
- **Node ≥ 18**（开发用 22 LTS；桌面外壳与其测试需要）。
- 首版仅 macOS（Apple Silicon）。

## 一键起步
```bash
./scripts/bootstrap.sh      # 或: make bootstrap
```
做三件事:建 `.venv` → `pip install -e ".[dev]"` → `cd desktop && npm ci`。幂等,可重复跑。

## 常用命令（Makefile）
| 命令 | 作用 |
|------|------|
| `make test` | 跑验证门:后端 `pytest` + 桌面 `node --check` / `node --test` |
| `make test-backend` | 仅后端 pytest |
| `make test-desktop` | 仅桌面 node 检查 + 测试 |
| `make run` | 启动后端（`python -m helm`,绑 127.0.0.1:8769） |
| `make app` | 打包 `.app`（需先 `pip install -e ".[packaging]"`） |
| `make clean` | 删 `.venv` / `node_modules` / `dist` 等 |

## 桌面外壳（开发态）
```bash
cd desktop && npm start     # Electron 起壳;会 spawn 后端或连已起的后端
```
也可单独跑后端（`make run`）再 `HELM_NO_SPAWN=1 npm start` 让壳连它。

## 可复现性
- **Node**:`npm ci` 按 `desktop/package-lock.json` 精确还原。
- **Python**:解释器由 `.python-version` 固定;依赖由 `pyproject.toml` 声明（`requires-python>=3.11`）。如需逐包精确锁定,后续可引入 pip-tools 生成 `requirements.lock`（当前阶段未做）。

## 配置（env）
- `HELM_PORT`（默认 8769）、`HELM_HOST`（仅回环 127.0.0.1/::1）、`HELM_DATA_DIR`（默认 `~/Library/Application Support/Helm`;测试用临时目录）。
