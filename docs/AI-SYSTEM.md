# Helm AI System · 详解(含全部 Prompt)

> 2026-07-08 · 对应分支 feat/nomi-kinds(PR #56)。本文覆盖记录页/捕获坞的
> AI 管线:分诊、收藏解析(enrich)、主题归类、人话排期、今日小结、问大脑。
> Chat/Research/Mail 各自的 AI 不在此文范围。

## 0. 一张表看全

| 环节 | 触发 | 引擎 | 延迟 | 花钱? |
|---|---|---|---|---|
| 判类徽章(输入时) | 捕获坞打字 | 前端规则 | 0 | 否 |
| 分诊·规则层 | 发送(triage:true) | 后端规则 | ~0 | 否 |
| 分诊·LLM 兜底 | 规则拿不准(confident=false) | 全局 provider | ~15s 异步 | 每条最多 1 次 |
| 收藏解析·抓取层 | 速记里有链接 | oEmbed/arXiv API/OpenGraph | 秒级 | 否 |
| 收藏解析·LLM 层 | 抓取层之后 | 全局 provider | 异步,90s 超时 | 每条 1 次 |
| 主题归类(集合) | 随 enrich 顺带产出 | 同上(同一次调用) | — | 0 额外 |
| 人话排期 | 派发条打字/提交 | 后端规则 | ~0 | 否 |
| AI 今日小结/周回顾 | 用户点按钮 | 指定 provider | 同步等待 | 用户主动,1 次 |
| 问大脑 | 捕获坞疑问句发送 | 全局 provider | 同步等待 | 1 次 |

设计原则:**规则先行零延迟、LLM 只兜底和增益、失败必降级、绝不丢用户内容、
不确定就标记而不是编造**。

## 1. 全局底座(helm/ai.py)

所有非 Chat 的 AI 功能走同一个旋钮:Settings → AI 的 `ai.provider_id`
(没设就用第一个已配置的 provider)。当前你配的是 **Claude Code 订阅 CLI**
(`claude-cli` 类型,base_url 存二进制路径)——走订阅,不烧 API key。

`llm_once(system, user)`:单轮补全,流式折叠成字符串;claude-cli 与 HTTP
adapter(OpenAI/Anthropic 兼容)同一接口。

## 2. 分诊管线(T1,helm/notes/triage.py + enrich 兜底)

### 2.1 触发

`POST /api/notes` 带 `"triage": true`(捕获坞自动挡;手动改类的客户端传显式
kind、不传 triage,完全绕过分诊)。

### 2.2 规则层(同步,~0ms)

判类顺序(与设计稿 demo/前端徽章同一套口径,后端为准):

```
链接(https?://)            → note(收藏,enrich 接手)      confident=true
任务词                       → task(自动进「待办·给自己」)  confident=true
想法词                       → idea                           confident=true
叙事词 且 len>14             → journal(journal_date=今天)    confident=true
其余                         → note                           confident=false ← LLM 兜底标记
```

- 任务触发词:`明早|明晚|今晚|明天|后天|下周|点前|之前完成|每天|每周|每月|提醒|记得|别忘|截止|deadline`
- 想法触发词:`也许|或许|说不定|要不要|想到|点子|灵感|如果…就|可以试试`
- 日记触发词:`今天|终于|感觉|开心|难受|累|复盘|想了想|反思`

**双抽取**(所有类别都做):
- 时间 `parse_when`:明早/明晚/今晚/明后天/周X/下周X/X点前/裸钟点/每天…
  → 人话标签 `meta.when`(如「明晚 20:00」)+ 可解析的绝对时刻 `meta.due`
  (本地 ISO,前端 24h 临近橙 chip 用);「每…」识别为 recurring(排期地基)。
  上/下午/晚上修饰自动 +12;「明晚8点」= 20:00。解析不出 → 不编造,置空。
- 地点 `parse_where`:`在X` / `@X`,懒匹配 + 动词边界前瞻(「在家帮…」只取
  「家」),`现/正/存/实在` 不算地点;抽不出边界宁可放弃。

响应带结构化回执块(前端 toast 用):
```json
"triage": {"kind":"task","when":"明晚 20:00","where":"家","due":"2026-07-09T20:00:00","recurring":false,"confident":true}
```
`meta.triage = {"by":"rule","confident":…}` 记录判定来源。

### 2.3 LLM 兜底(异步,挂在 enrich 里)

只有 `confident=false` 的速记,enrich 的文本整理 prompt 顺带让 LLM 判 kind
(见 §3 的 TEXT prompt,含 `"kind"` 字段)。写回规则:

- LLM 判 `idea|task|journal` → **升格** kind(journal 补 journal_date),
  `meta.triage = {"by":"llm","confident":true}`;
- LLM 判 `note` → 确认速记,同样标 `by:llm`(不留 pending);
- 只从 kind=note 升格——用户在 enrich 期间手动改过类,LLM 不覆盖;
- LLM 失败/超时/没配 provider → 保持规则结果,内容不丢。

实测(claude-cli):~15s 写回;「把 nomi-reference 的截图整理进仓库」
规则拿不准 → LLM 升格 task,自动进待办。

### 2.4 纠错回流

回执 toast「改」/卡片 ⋯ 菜单/详情页,都是 `PATCH /api/notes/{id} {"kind":…}`;
改成 journal 自动补 journal_date。「分诊记住纠正」(用纠正样本个性化)在
backlog [T1+],未实现。

## 3. 收藏解析 enrich(helm/notes/enrich.py)

速记发送后台跑,三层逐层降级,任何一步失败都不影响已落库的原文:

1. **抓取层(无 key)**:YouTube → 官方 oEmbed;arXiv → export API(Atom);
   其余 → 页面 OpenGraph/`<title>`(截 512KB,8s 超时)。多链接各抓一份存
   `meta.links[]`,顶层字段=第一个(向后兼容)。抓取结果**先落库**——卡片先
   有标题/封面,LLM 慢不拖累展示。
2. **LLM 层**(全局 provider,90s 超时,失败保留第一层):
3. **全失败** → meta 至少 `{type, url}`,卡片仍显示裸链接。

**meta 合并规则**:enrich 从不覆盖分诊的规则种子(when/where/due 优先,
LLM 只补空)。

### Prompt 原文 · 链接类(_LINK_SYSTEM)

```
你是 Helm 的收藏解析器。根据给出的链接元数据(可能不全)输出 JSON:
{"type":"youtube|paper|article|inspiration","summary":"2-3 句中文,讲清这是什么、为什么值得看",
"tags":["≤3个中文短标签"],"topic":"2-6字的主题集合名(如 Transformer 学习/设计灵感),不确定给 null"}。
UI/UX/设计/作品集类判为 inspiration。只输出 JSON。
```

user 消息形如:`链接: {url}\n元数据: {抓取层 JSON}\n用户原话: {content}`

### Prompt 原文 · 纯文本类(_TEXT_SYSTEM,含分诊兜底)

```
你是 Helm 的速记整理器。把用户随手记的一条整理成 JSON:
{"title":"≤12字标题","tags":["≤3个中文短标签"],"when":"文中提到的时间线索,无则null",
"where":"文中提到的地点线索,无则null",
"topic":"2-6字的主题集合名(把相关记录归到同一集合,如 Transformer 学习),不确定给 null",
"kind":"note|idea|task|journal 之一——task=要做的事(常带时间),idea=点子/假设,
journal=当天叙事,其余 note"}。
不改写原文,只输出 JSON。
```

解析容错:从回复里正则抠第一个 `{...}`,坏 JSON 一律当空处理(不炸管线)。

### 主题归类(集合)

`meta.topic` 就是上面两个 prompt 顺带产出的(**零额外调用**)。前端「按主题
· AI」分区;卡上主题胶囊 × = 整份 meta 回写移出集合;同一未确认主题攒够
3 条 → 涌现「建一个集合?」建议卡(确认/忽略记 localStorage)。

## 4. 人话排期(T2,helm/tasks/nl.py)· 纯规则,无 LLM

`POST /api/tasks {prompt}` 整句(或 to-task 的 schedule_nl)→ 解析:

| 人话 | schedule | 例 |
|---|---|---|
| 每天[早上N点/晚上N点] | cron `M H * * *` | 每天 09:00 |
| 每周X / 每星期X | cron `M H * * 1-6,0` | 每周五 15:00 |
| 每周(没说哪天) | cron 周一(注明可纠) | 每周一 09:00 |
| 每个工作日 | cron `M H * * 1-5` | 工作日 08:30 |
| 每月N号 | cron `M H N * *` | 每月 1 号 09:00 |
| 每 N 小时/分钟 | every {seconds} | 每 6 小时 |
| 一次性(明早9点/周五下午3点…) | at(复用 §2.2 parse_when,本地→带时区 ISO) | 明早 09:00 |

原句留在 `task.prompt`,人话标签存 `schedule_value.nl`(UI 只显示人话,
cron 表达式退场);`GET /api/tasks/parse?q=` 给派发条实时徽章——与提交同一
解析器,不双轨。解析不出 → 422 带提示「把『什么时候』放进句子」(不猜;
要不要改成「没时间=立即执行一次」在 backlog Q-T2 待拍板)。

## 5. AI 今日小结 / 周回顾(helm/notes/summary.py)

用户主动点按钮才调用(付费动作用户可控),provider/model 由请求指定。
`days=1` 当日小结,`days=7` 周回顾;可选把小结存回日记(source=agent)。

### Prompt 原文(SUMMARY_PROMPT)

```
为下面这一天的日记条目写一段简洁的「今日小结」(2-4 句,中文),提炼当天要点、进展与情绪基调,不要逐条复述。

日记条目:
{entries}

只输出小结正文,不要前缀。
```

多条目以 `\n---\n` 拼接填入 `{entries}`。

## 6. 问大脑(helm/chat/routes.py /api/ask)

捕获坞判定疑问句(`为什么/怎么/如何/…` 开头或 `?/?` 结尾)→ 发送走
`/api/ask`,同步等答案,答案就地显示在坞下方(notch 同契约)。

### Prompt 原文(system)

```
用中文简洁回答,直接给答案,不用客套。
```

## 7. 成本与降级一览

- **会花钱的**:LLM 兜底(每条不确定速记 1 次)、enrich LLM 层(每条带内容
  的速记 1 次)、今日小结(点一次 1 次)、问大脑(问一次 1 次)。当前
  claude-cli 订阅 = 不额外计费。
- **永远不花钱**:输入徽章、分诊规则层、双抽取、人话排期、抓取层、主题分区
  渲染。
- **降级链**:没配 provider → 全部规则结果照常;LLM 超时/坏 JSON → 保留上
  一层;抓取失败 → 裸链接卡。任何失败都不会丢内容、不会阻塞发送。

## 8. 已知边界(诚实声明)

- 输入时的实时徽章是**前端规则**(为了零延迟),后端才是权威——两边规则
  同口径,但以落库结果为准。
- LLM 兜底每条只跑一次,不重试不轮询;判错靠回执「改」纠正。
- 「分诊记住纠正」(个性化)未实现 → backlog [T1+]。
- 无时间的 agent 任务默认 422 → backlog Q-T2 待拍板。
- notch journalToday 按 createdAt 归日、主 app 按 journal_date——凌晨补写
  归属有差,已通知 notch 线对齐(docs/loops/nomi-notch/backlog.md)。
