# cockpit · m1 数据模型 + 项目后端

- **日期**：2026-06-19
- **Room / milestone**：cockpit / m1（数据模型 + 项目后端）

## 目标
为驾驶舱打底：`projects` 数据模型 + Python FileService（列目录 + 项目类型识别）+ REST，替代 FanBox 的 Node fs 管道。

## 做了什么
- **`helm/cockpit/models.py`**：`Project`（path PK / name / badges(csv) / last_opened）。`terminal_sessions`(m4)、`file_changes`(m5) 表待其 milestone 再建（避免空表；schema 已在决策里按 F0 §5 记录）。
- **`helm/cockpit/service.py`**：`list_dir`（dirs first + 字母序，逐项 try/except 跳过不可读，symlink 安全）；`detect_badges`（package.json→node、pyproject/requirements/setup.py→py 去重、Cargo.toml→rs、go.mod→go、index.html→web）；`ProjectService`（list 按 last_opened desc、open upsert + 刷新 badges/last_opened）。
- **`helm/cockpit/routes.py`**：`GET /api/cockpit/files?path=` 浏览、`GET /api/cockpit/projects` 列表、`POST /api/cockpit/projects` 注册/打开。404/403 映射。
- **`helm/app.py`**：`create_all` 移到 router include 之后——这样各 Room 的 router import 触发其 ORM 模型注册到 Base.metadata（settings/secrets/projects 三表都建）。include cockpit router。

## 决策（record_decision）
- 数据模型（单向门，依据 F0 §5）：`projects(path PK, name, badges, last_opened)` 本轮落地；`terminal_sessions(id, project_path, agent, started_at, ...)`、`file_changes(id, session_id, path, change_kind, ts)` 按需在 m4/m5 建，schema 形状先记录。
- 本地 FS 不沙箱（local-first 单用户，浏览自己的文件即目的）；信任边界 = 回环绑定。
- create_all 延后到 router include 之后 = "feature Room 加表" 的统一机制。

## defer
- terminal_sessions/file_changes 表 → m4/m5；缩略图、内容搜索、预览、分页、>1000 项性能优化 → 后续。

## 验证
- 后端 `pytest` **46 通过**（41 + 5 cockpit：badge 检测 / 列目录排序 / 非目录拒绝 / browse 404 / open+list 项目）。create_all 重排经全套测试验证（settings/secrets/projects 三表均建）。
- review（agent）：m1 范围内 clean，无 high/med；create_all 重排正确、list_dir try/except+symlink、无新网络面、open flush 取 server_default、模型注册可靠、错误映射均确认。修 2 处 low（`abs` 改名、browse 回显规范化路径）。

## 熔断状态
- 未命中。（一处测试失败：config fixture 的 data dir 落在 tmp_path 内被列出 → 改为浏览专用子目录，一次修好。）

## 下一步
- m2：文件浏览前端（Svelte 移植 FanBox 文件卡片/列表 + 实体图标 + 项目徽章）+ ⌘K 项目搜索注册进命令面板。
