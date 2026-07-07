<script lang="ts">
  import { onMount } from 'svelte'
  import CaptureDock from './CaptureDock.svelte'
  import { layout } from './layout.svelte'
  import { tasks } from './notes/tasksStore.svelte'
  import { notes } from './notes/notesStore.svelte'
  import { agent } from './orchestration/agentStore.svelte'
  import { cockpit } from './cockpit/cockpit.svelte'
  import { calendar } from './mail/calendarStore.svelte'
  import { toLocal, localHHMM } from './time'

  // Today · NOMI 六卡仪表(阶段 4 R03,source: helm-journal-pro.html 今日板块):
  // 问候+日期摘要 → 捕获坞 → 卡网格(任务/日程/日记/智能体/最近项目/今日收藏/简报)。
  // 真数据全保留(A×C v3 的 derived 原样移植);ORAGE 时钟锚/聚光/右柱退场。

  let now = $state(new Date())

  interface BriefItem {
    title: string
    source: string
    url: string
    ago: string
  }
  let brief = $state<BriefItem[]>([])

  onMount(() => {
    void tasks.load()
    void notes.load()
    void agent.loadRuns()
    void cockpit.loadProjects()
    void calendar.load()
    void (async () => {
      try {
        const r = await fetch('/api/briefing')
        if (r.ok) brief = ((await r.json()) as { items?: BriefItem[] }).items ?? []
      } catch {
        /* 离线:简报卡显示占位 */
      }
    })()
    const t = setInterval(() => (now = new Date()), 1000)
    return () => clearInterval(t)
  })

  const pad2 = (n: number) => String(n).padStart(2, '0')
  const todayStr = $derived(`${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`)
  const weekNo = $derived.by(() => {
    const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()))
    const day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    const y0 = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil(((d.getTime() - y0.getTime()) / 86400000 + 1) / 7)
  })
  const greeting = $derived.by(() => {
    const h = now.getHours()
    if (h < 6) return '夜深了'
    if (h < 12) return '早上好'
    if (h < 18) return '下午好'
    return '晚上好'
  })
  const WD = ['日', '一', '二', '三', '四', '五', '六']

  // 任务:启用在前、按下次触发升序,取 3
  const topTasks = $derived(
    [...tasks.tasks]
      .sort((a, b) => Number(b.enabled) - Number(a.enabled) || (a.next_run ?? '').localeCompare(b.next_run ?? ''))
      .slice(0, 3),
  )
  const enabledCount = $derived(tasks.tasks.filter((t) => t.enabled).length)
  function dueSoon(iso: string | null): boolean {
    if (!iso) return false
    return toLocal(iso).getTime() - now.getTime() < 3_600_000
  }

  // 日记:今日条目 + 字数 + 连续天数
  const todayEntries = $derived(notes.notes.filter((n) => n.kind === 'journal' && n.journal_date === todayStr))
  const todayChars = $derived(todayEntries.reduce((n, e) => n + e.content.length, 0))
  // T4 每天一篇:今日多段按时间升序拼一篇(与 notch journalToday 同口径 \n\n)
  const todayText = $derived(
    [...todayEntries]
      .sort((a, b) => (a.created_at ?? '').localeCompare(b.created_at ?? ''))
      .map((e) => e.content)
      .join('\n\n'),
  )
  function goJournal() {
    layout.journalIntent = 'journal' // 落在记录页·日记 tab(今天的页可续写)
    layout.setMode('journal')
  }
  const streak = $derived.by(() => {
    const dates = new Set(
      notes.notes.filter((n) => n.kind === 'journal' && n.journal_date).map((n) => n.journal_date as string),
    )
    let count = 0
    const d = new Date(now)
    if (!dates.has(todayStr)) d.setDate(d.getDate() - 1)
    for (;;) {
      const key = `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
      if (!dates.has(key)) break
      count += 1
      d.setDate(d.getDate() - 1)
    }
    return count
  })

  // Agent:最近运行 + 运行中数
  const latestRuns = $derived(agent.runs.slice(0, 2))
  const runningCount = $derived(agent.runs.filter((r) => r.status === 'running').length)
  const lastRunTime = $derived(agent.runs[0]?.started_at ? localHHMM(agent.runs[0].started_at) : null)

  // 项目 + 日程
  const recent = $derived(cockpit.projects.slice(0, 3))
  const nextEvent = $derived(
    [...calendar.events]
      .filter((e) => e.start && toLocal(e.start).getTime() >= now.getTime())
      .sort((a, b) => (a.start ?? '').localeCompare(b.start ?? ''))[0] ?? null,
  )
  const nextIn = $derived.by(() => {
    if (!nextEvent?.start) return ''
    const m = Math.max(0, Math.round((toLocal(nextEvent.start).getTime() - now.getTime()) / 60000))
    return m < 60 ? `还有 ${m} 分钟` : `还有 ${Math.floor(m / 60)} 小时 ${m % 60} 分`
  })

  // 今日收藏:今天记的非日记条目,取 3(AI 收藏管线的产出)
  const KIND_COLOR: Record<string, string> = {
    youtube: '#ff2d2d', paper: '#8b5a2b', inspiration: '#0a84ff',
    article: '#0a84ff', text: '#111114', task: 'var(--green)',
  }
  const todayCaptures = $derived(
    notes.notes
      .filter((n) => n.kind !== 'journal' && (n.created_at ?? '').slice(0, 10) === todayStr)
      .slice(0, 3),
  )
  const capColor = (n: (typeof notes.notes)[number]) => KIND_COLOR[n.meta?.type ?? n.kind] ?? 'var(--t4)'
  const capLabel = (n: (typeof notes.notes)[number]) => {
    const t = n.meta?.type
    return t === 'youtube' ? '视频' : t === 'paper' ? '论文' : t === 'article' || t === 'inspiration' ? '收藏' : n.kind === 'task' ? '任务' : '速记'
  }

  function openProject(path: string) {
    void cockpit.openProject(path)
    layout.setMode('cockpit')
  }
</script>

<div class="v-today">
  <header class="greet">
    <h1 class="hi">{greeting},Victor</h1>
    <p class="sub">
      {now.getMonth() + 1}月{now.getDate()}日 周{WD[now.getDay()]} · 第 {weekNo} 周
      · 今天 {calendar.events.length} 个日程、{enabledCount} 个定时任务在跑
      · {pad2(now.getHours())}:{pad2(now.getMinutes())}
    </p>
  </header>

  <CaptureDock />

  <div class="tgrid">
    <!-- 任务 · 今日 -->
    <section class="card">
      <div class="pad">
        <span class="appic" style="background:var(--green)">T</span>
        <div class="ti">任务 · 今日</div>
        <div class="rows">
          {#if topTasks.length === 0}
            <p class="ghost">没有定时任务 — 记录 → 任务 里建一个。</p>
          {:else}
            {#each topTasks as t (t.id)}
              <div class="rowline">
                <span class="dotc" style="background:{t.enabled ? 'var(--green)' : 'var(--t4)'}"></span>
                <span class="rt">{t.name}</span>
                <span class="r" class:soon={dueSoon(t.next_run)}>{t.next_run ? localHHMM(t.next_run) : t.schedule_kind}</span>
              </div>
            {/each}
          {/if}
        </div>
      </div>
      <div class="foot"><span class="tm">{enabledCount} 项启用</span></div>
    </section>

    <!-- 日程 · 下一项 -->
    <section class="card">
      <div class="pad">
        <span class="appic grad">E</span>
        <div class="ti">日程 · 下一项</div>
        {#if nextEvent}
          <div class="stat"><span class="big">{nextEvent.start ? localHHMM(nextEvent.start) : '—'}</span>
            <span class="u">{nextEvent.summary} · {nextIn}</span></div>
        {:else}
          <p class="ghost">没有即将到来的日程。</p>
        {/if}
      </div>
      <div class="foot"><span class="tm">今天 {calendar.events.length} 项</span></div>
    </section>

    <!-- 日记 · 今天(T4 每天一篇:全文预览 + 续写 →) -->
    <section class="card">
      <div class="pad">
        <span class="appic" style="background:#c9a227">J</span>
        <div class="ti">日记 · 今天</div>
        <div class="stat"><span class="big">{todayChars}</span><span class="u">字 · 连续 {streak} 天</span></div>
        {#if todayText}
          <p class="jprev">{todayText}</p>
        {:else}
          <p class="ghost">今天还没写 — 从一句话开始。</p>
        {/if}
        <button class="aibtn" onclick={goJournal}>
          <span class="spark" aria-hidden="true"></span>AI 今日小结
        </button>
      </div>
      <div class="foot"><span class="tm">{todayEntries.length} 段</span>
        <button class="linkish" onclick={goJournal}>续写 →</button></div>
    </section>

    <!-- 智能体 -->
    <section class="card">
      <div class="pad">
        <span class="appic" style="background:linear-gradient(135deg,#34d6c0,#0a84ff)">A</span>
        <div class="ti">智能体</div>
        <div class="rows">
          {#if latestRuns.length === 0}
            <p class="ghost">没有 agent 运行 — 驾驶舱里跑一条。</p>
          {:else}
            {#each latestRuns as r (r.id)}
              <div class="rowline">
                <span class="dotc" style="background:{r.status === 'running' ? 'var(--green)' : 'var(--t4)'}"></span>
                <span class="rt">{(r.prompt ?? '').slice(0, 26)}</span>
                <span class="r">{r.status}</span>
              </div>
            {/each}
          {/if}
        </div>
      </div>
      <div class="foot"><span class="tm">{runningCount} live{lastRunTime ? ` · 上次 ${lastRunTime}` : ''}</span></div>
    </section>

    <!-- 最近项目 -->
    <section class="card">
      <div class="pad">
        <span class="appic" style="background:linear-gradient(135deg,#34d6c0,#0a84ff)">P</span>
        <div class="ti">最近项目</div>
        <div class="pills">
          {#if recent.length === 0}
            <p class="ghost">还没有项目 — 驾驶舱里打开一个。</p>
          {:else}
            {#each recent as p (p.path)}
              <button class="minipill" onclick={() => openProject(p.path)}>{p.name}</button>
            {/each}
          {/if}
        </div>
      </div>
      <div class="foot"><span class="tm">{cockpit.projects.length} 个</span></div>
    </section>

    <!-- 今日收藏 -->
    <section class="card">
      <div class="pad">
        <span class="appic" style="background:#ff2d2d">R</span>
        <div class="ti">今日收藏</div>
        <div class="rows">
          {#if todayCaptures.length === 0}
            <p class="ghost">今天还没记 — 上面随手记一笔。</p>
          {:else}
            {#each todayCaptures as n (n.id)}
              <div class="rowline">
                <span class="dotc" style="background:{capColor(n)}"></span>
                <span class="rt">{n.meta?.title ?? n.title ?? n.content.slice(0, 24)}</span>
                <span class="r">{capLabel(n)}</span>
              </div>
            {/each}
          {/if}
        </div>
      </div>
      <div class="foot"><button class="linkish" onclick={() => layout.setMode('journal')}>记录 →</button></div>
    </section>

    <!-- 简报 · 世界输入(功能保留,设计稿未画:以同款卡呈现) -->
    <section class="card" aria-label="世界输入">
      <div class="pad">
        <span class="appic" style="background:var(--t1);color:var(--onink)">B</span>
        <div class="ti">简报 · 世界输入</div>
        <div class="rows">
          {#if brief.length === 0}
            <p class="ghost">暂无简报 — 接入更多源(RSS · 行情 · Newsletter)。</p>
          {:else}
            {#each brief.slice(0, 3) as b (b.url)}
              <div class="rowline">
                <span class="dotc" style="background:var(--g1)"></span>
                <a class="rt" href={b.url} target="_blank" rel="noreferrer">{b.title}</a>
                <span class="r">{b.ago}</span>
              </div>
            {/each}
          {/if}
        </div>
      </div>
      <div class="foot"><span class="tm">{brief.length ? `Hacker News · ${brief.length} 条` : 'BRIEFING'}</span></div>
    </section>
  </div>
</div>

<style>
  .v-today {
    height: 100%;
    overflow-y: auto;
    padding: 10px 28px 30px;
  }
  .greet {
    margin: 8px 4px 18px;
  }
  .hi {
    font: 800 26px/1.2 var(--sans);
    letter-spacing: -0.3px;
    color: var(--t1);
    margin: 0;
  }
  .sub {
    font: 400 13.5px/1.5 var(--sans);
    color: var(--t4);
    margin: 4px 0 0;
  }

  .tgrid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 16px;
    margin-top: 18px;
  }
  .card {
    background: var(--card);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    display: flex;
    flex-direction: column;
    transition: box-shadow var(--dur-micro) var(--ease);
  }
  .card:hover {
    box-shadow: var(--shadow-lg);
  }
  .pad {
    padding: 14px 16px 10px;
    flex: 1;
  }
  .appic {
    width: 26px;
    height: 26px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font: 800 11px/1 var(--sans);
    margin-bottom: 9px;
  }
  .appic.grad {
    background: linear-gradient(135deg, var(--g1), var(--g2));
  }
  .ti {
    font: 600 14px/1.35 var(--sans);
    color: var(--t1);
  }
  .rows {
    margin-top: 10px;
  }
  .rowline {
    display: flex;
    align-items: center;
    gap: 9px;
    font: 400 12.5px/1.4 var(--sans);
    color: var(--t3);
    padding: 7px 0;
    border-top: 1px solid var(--hair);
    min-width: 0;
  }
  .rowline:first-child {
    border-top: none;
  }
  .dotc {
    width: 8px;
    height: 8px;
    border-radius: 3px;
    flex: none;
  }
  .rt {
    flex: 1;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--t2);
    text-decoration: none;
  }
  a.rt:hover {
    color: var(--t1);
  }
  .r {
    margin-left: auto;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    flex: none;
  }
  .r.soon {
    color: var(--orange);
  }
  .stat {
    display: flex;
    align-items: baseline;
    gap: 6px;
    margin-top: 10px;
  }
  .big {
    font: 800 30px/1 var(--sans);
    letter-spacing: -0.5px;
    color: var(--t1);
  }
  .u {
    font: 400 12px/1.4 var(--sans);
    color: var(--t4);
  }
  .ghost {
    font: 400 12px/1.5 var(--sans);
    color: var(--t4);
    margin: 8px 0;
  }
  /* T4 每天一篇:今日聚合全文预览(clamp 5 行,续写 → 看全文) */
  .jprev {
    font: 400 12.5px/1.65 var(--sans);
    color: var(--t2);
    margin: 8px 0 2px;
    white-space: pre-line;
    display: -webkit-box;
    -webkit-line-clamp: 5;
    line-clamp: 5;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .pills {
    margin-top: 12px;
  }
  .minipill {
    display: inline-block;
    font: 500 11.5px/1 var(--sans);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    color: var(--t3);
    cursor: pointer;
    margin: 0 6px 6px 0;
  }
  .minipill:hover {
    color: var(--t1);
    background: color-mix(in srgb, var(--pill) 80%, var(--t4) 20%);
  }
  .aibtn {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    background: var(--card);
    border: 1px solid var(--hair);
    border-radius: var(--radius-pill);
    padding: 7px 14px;
    font: 400 12px/1 var(--sans);
    color: var(--t3);
    cursor: pointer;
    margin-top: 10px;
  }
  .aibtn:hover {
    color: var(--t1);
    border-color: var(--t4);
  }
  .spark {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .foot {
    display: flex;
    align-items: center;
    padding: 6px 16px 12px;
    color: var(--t4);
  }
  .tm {
    margin-left: auto;
    font: 400 10.5px/1 var(--sans);
  }
  .linkish {
    margin-left: auto;
    font: 500 10.5px/1 var(--sans);
    color: var(--t3);
    background: none;
    border: 0;
    cursor: pointer;
    padding: 0;
  }
  .linkish:hover {
    color: var(--t1);
  }
</style>
