# Helm 收尾清单 · 逐条解决 needs-human tickets

> 整个 PRD 一夜跑通、10 个 Room 合 main。剩下这些是「**只能你来**」的——要么需真实凭据/API（loop 硬底线不碰），要么需你拍板/你的环境。
> **用法**：照着一条一条做。每条做完，回到和我（Claude Code）的对话里说一句结果，我来关单 / 修 bug。
>
> **怎么回报**：
> - 通过 → 跟我说「#XX 正常」→ 我关单。
> - 有问题 → 跟我说「#XX 这里不对：<现象 / 报错 / 截图>」→ 我直接修。
>
> **前置（所有验证类共用）**：app 在跑。浏览器开 `http://127.0.0.1:8769`。没跑就：
> ```bash
> cd /Users/victor/work/AI-workspace/helm && make run
> ```

---

## 🟢 第 1 条（最容易，免费，先做这个）· #27 — 真实 IMAP 收邮件

**验什么**：真邮箱能否登录、收取、解析（尤其中文主题）。

**步骤**：
1. 浏览器 → 左侧点 **✉ Mail** → 上方 **邮件** 段 → 点 **+ 账户**。
2. 填表（凭据会自动 SecretBox 加密存储，不会明文落库）：
   - 名称：随便，如「我的 Gmail」
   - 邮箱地址：你的邮箱
   - IMAP 主机：Gmail=`imap.gmail.com`、iCloud=`imap.mail.me.com`、Outlook=`outlook.office365.com`
   - 用户名：通常就是邮箱地址
   - 密码：**多数邮箱要"应用专用密码"，不是登录密码**（见坑）
3. 点 **添加** → 再点上方 **收取**。

**通过标准**：收件箱出现邮件，主题/发件人正常，中文不乱码，未读有标识。
点开一封 → 点 **✨ AI 分诊**（需先配过 provider，见 #23 第 1 步）能出紧急度/摘要/草稿。

**坑**：
- **Gmail**：要先在 Google 账号开「应用专用密码」（2FA 下），用那个 16 位密码，不是登录密码。
- **iCloud**：同样要[应用专用密码](https://appleid.apple.com)。
- IMAP 没启用的话先去邮箱设置里打开。

**回报**：「#27 正常」/「#27 收取报错：<贴 console 或 502 detail>」。

---

## 🟡 第 2 条（小额花钱，重要）· #19 — 真实 Claude Code 核对格式

**验什么**：我写的 ACP parser 解析 `claude --output-format stream-json` 的字段对不对。
**前置**：`claude` CLI 已装（你机器上有 `~/.local/bin/claude`）。会发一次真实 LLM 调用（小额）。

**步骤**（在你自己的终端）：
```bash
cd /Users/victor/work/AI-workspace/helm
claude -p "用一句话说你好" --output-format stream-json --verbose 2>&1 | head -40
```

**通过标准**：输出是逐行 JSON，含这些 `type`：
- `{"type":"system","subtype":"init",...}`（有 model/tools/cwd）
- `{"type":"assistant","message":{"content":[{"type":"text",...}]}}`
- `{"type":"result","subtype":"success","result":...}`

把这 head -40 的输出贴给我，我对照 `helm/orchestration/adapters.py` 的 `parse_line` 看字段名一不一致。

**（可选）整条链联调**：让 Helm 把自己的能力注入 Claude Code：
```bash
# 把 helm MCP server 注入当前项目的 .mcp.json(合并+备份,不覆盖):
curl -s -X POST http://127.0.0.1:8769/api/orchestration/mcp \
  -H 'content-type: application/json' \
  -d '{"config_path":"'$PWD'/.mcp.json","enabled":true}'
# 然后在这个目录跑 claude,它就能调 helm_memory_search / helm_email_unread 等工具
```

**回报**：把 head -40 输出贴我 →「字段一致 / 这几个对不上」。

---

## 🟠 第 3 条（花钱：LLM+网络）· #23 — 真实 Deep Research

**验什么**：真实搜索+LLM 跑研究、报告引用准不准、DDG 抓取稳不稳。

**步骤**：
1. **先配一个 chat provider**（这步也是 #23/#25/邮件分诊 共用的前提）：
   浏览器 → **💬 Chat** → provider 设置 → 加一个（如 Claude：type=anthropic、base_url=`https://api.anthropic.com`、填 API key、model=`claude-opus-4-8`）。
2. 浏览器 → **🔍 Research** → 选刚配的 provider/model → 输入一个研究问题（如「2026 年最值得学的编程语言对比」）→ **开始研究**。
3. 看实时进度流（round_start / source / synthesize），等它跑完。

**通过标准**：出报告，有「关键结论」每条带 `[1][2]` 引用、下面有对应来源 URL、迭代 ≥3 轮。

**坑**：DDG 用免 key 的 HTML 抓取，**可能被限流/改版** → 表现为搜索返回空、报告没来源。若这样，跟我说，我接一个有 API 的搜索后端做 fallback。

**回报**：「#23 正常，报告质量 OK」/「#23 DDG 没返回来源 / 报告质量差：<现象>」。

---

## 🔴 第 4 条（最复杂，花钱）· #25 — 后台调度真触发 agent

**验什么**：定时任务到点能否真触发 agent，结果写 task_runs。
**前置**：#19（Claude Code 能跑）+ 第 3 条第 1 步（配过 provider）。

**步骤**：
1. 停掉 app，带调度开关重启（在你终端）：
   ```bash
   pkill -f "python -m helm"; sleep 1
   cd /Users/victor/work/AI-workspace/helm
   HELM_SCHEDULER=1 make run
   ```
2. 建一个**近未来**的任务（每分钟跑，方便快速看到）：
   ```bash
   curl -s -X POST http://127.0.0.1:8769/api/tasks -H 'content-type: application/json' \
     -d '{"name":"测试","prompt":"说一句今天的天气提醒","schedule_kind":"every","schedule_value":{"seconds":60}}'
   ```
3. 等 1-2 分钟，看有没有跑（把下面的 `<id>` 换成上面返回的 id）：
   ```bash
   curl -s http://127.0.0.1:8769/api/tasks/<id>/runs
   ```

**通过标准**：`runs` 里出现一条 `status:"ok"` + `output`（agent 的输出）。

**坑**：会反复触发 agent（每 60 秒，每次花钱）。验完**赶紧删任务**：
```bash
curl -s -X DELETE http://127.0.0.1:8769/api/tasks/<id>
```
验完把 app 重启回不带 `HELM_SCHEDULER` 的常规模式。

**回报**：「#25 正常,task_runs 有记录」/「#25 没触发 / 报错：<现象>」。

---

## ⚪ 第 5 条（一句话决定）· #12 — httpx2 弃用警告

仅一条测试时的弃用警告（`starlette.testclient` 弃用 httpx）。tests 全过，不影响功能。httpx2 是独立 fork，强迁有破 100+ 测试风险。

**你只需回我一句**：
- 「#12 wontfix」→ 我标掉，清噪声。**（推荐）**
- 「#12 试着迁」→ 我在分支上试，破了就回滚。

---

## 📦 一簇（等你出 macOS 安装包时一起做）· #8 + #10 + #13

这三条绑在一起，都需**真实打包 + Apple 证书**：
- **#13** 打包体积：跑 `make app`（PyInstaller）量 .app 大小（chromadb/fastembed 会让它变大）。
- **#8** 代码签名 + 公证：需 **Apple Developer 证书**（你的账号）。
- **#10** Keychain 存密钥：依赖 #8（未签名访问 Keychain 会反复弹框）。

**现在不用管。** 等你确实要发安装包给别人用时，跟我说「准备打包了」，我带你过这一簇。

---

## 🔧 一条（需设计 + agent 集成）· #16 — Skills 启停真生效

现在 Skills 透视能列出/看健康/记状态，但「启停开关」只存 Helm 侧状态，**没真正控制 Claude Code 加载哪些 skill**（需 agent 集成）。

这条**留到最后**——等 #19 联调通了、你确实想要"在 Helm 里管 Claude Code 的 skill"时再说。要做我再帮你设计方案。

---

## ✅ 速查表

| 顺序 | ticket | 谁做 | 花钱 | 一句话 |
|---|---|---|---|---|
| 1 | #27 真 IMAP | 你跑 | 否 | 加真邮箱→收取 |
| 2 | #19 真 Claude Code | 你跑 | 小额 | 跑 stream-json 贴我 |
| 3 | #23 真 Deep Research | 你跑 | 是 | 配 provider→跑研究 |
| 4 | #25 后台调度 | 你跑 | 是 | HELM_SCHEDULER=1→建任务 |
| 5 | #12 httpx2 | 你拍板 | — | 回我 wontfix / 迁 |
| 6 | #8/#10/#13 打包簇 | 你的环境 | — | 出安装包时再说 |
| 7 | #16 Skills 集成 | 待设计 | — | 最后做 |

> 已完成(今天)：#22 引擎方向(决策)、#28 CalDAV(实现)、中文搜索 bug(白赚修复)。
