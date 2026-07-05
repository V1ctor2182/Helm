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

  // Today · A×C v3(DESIGN.md 层级三层制+左内右外,2026-07-05 用户定稿):
  // 锚=72px 恒亮时钟;左列=我的一天(区块聚光,数字挂区块头右端,22px 大而暗);
  // 右柱=世界输入(HN 简报+未来源占位)。参照稿 docs/design/explore-hier-ac.html。

  let now = $state(new Date())
  let focus = $state<'tasks' | 'journal' | 'agent' | 'recent' | 'schedule'>('tasks')

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
        /* 离线:简报柱显示占位 */
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

  // 日记:今日条目 + 字数 + 连续天数(journal_date 去重回溯)
  const todayEntries = $derived(notes.notes.filter((n) => n.kind === 'journal' && n.journal_date === todayStr))
  const todayChars = $derived(todayEntries.reduce((n, e) => n + e.content.length, 0))
  const streak = $derived.by(() => {
    const dates = new Set(
      notes.notes.filter((n) => n.kind === 'journal' && n.journal_date).map((n) => n.journal_date as string),
    )
    let count = 0
    const d = new Date(now)
    if (!dates.has(todayStr)) d.setDate(d.getDate() - 1) // 今天还没写,从昨天数
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
    return m < 60 ? `还有 ${m}M` : `还有 ${Math.floor(m / 60)}H ${m % 60}M`
  })

  function newChat() {
    layout.setMode('chat')
    layout.openTab('New Chat', 'chat')
  }
  function newResearch() {
    layout.setMode('research')
    layout.openTab('Research', 'research')
  }
  function openProject(path: string) {
    void cockpit.openProject(path)
    layout.setMode('cockpit')
  }
</script>

<div class="rd3">
  <!-- 屏锚:72px 重磅时钟,恒亮,不参与聚光 -->
  <header class="dial">
    <span class="clock">{pad2(now.getHours())}:{pad2(now.getMinutes())}<span class="sec">:{pad2(now.getSeconds())}</span></span>
    <span class="datecol">
      <span class="d1">{pad2(now.getMonth() + 1)}·{pad2(now.getDate())}</span>
      <span class="d2">周{'日一二三四五六'[now.getDay()]} · W{weekNo}</span>
    </span>
    <span class="dmeta">
      <span>{tasks.tasks.length} TASKS · {agent.runs.length} RUNS</span>
      {#if runningCount > 0}<span class="acc">{runningCount} RUNNING</span>{/if}
    </span>
  </header>

  <div class="body3">
    <!-- 左列:我的一天(聚光系统) -->
    <div class="ledger" role="list">
      <!-- 捕获坞:notch 5-kind 同款(2026-07-05 用户:这几个放在一起) -->
      <CaptureDock />
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
      <section role="listitem" class="blk" class:focus={focus === 'tasks'} onclick={() => (focus = 'tasks')}>
        <div class="bh">
          <span class="bt">任务</span><span class="bl">TASKS · 今日</span>
          <span class="rule"></span>
          <span class="key">{enabledCount}<span class="ks">/{tasks.tasks.length} 启用</span></span>
        </div>
        {#if topTasks.length === 0}
          <div class="emptyline">没有定时任务 — 记录 → 任务 里建一个。</div>
        {:else}
          {#each topTasks as t (t.id)}
            <div class="task">
              <button
                class="cbx"
                class:done={t.enabled}
                aria-pressed={t.enabled}
                aria-label={`启用 ${t.name}`}
                onclick={(e) => {
                  e.stopPropagation()
                  void tasks.toggle(t)
                }}
              ></button>
              <span class:strk={!t.enabled}>{t.name}</span>
              <span class="due" class:hot={t.enabled && dueSoon(t.next_run)}>{t.enabled ? localHHMM(t.next_run) || '—' : '停用'}</span>
            </div>
          {/each}
        {/if}
      </section>

      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
      <section role="listitem" class="blk" class:focus={focus === 'journal'} onclick={() => (focus = 'journal')}>
        <div class="bh">
          <span class="bt">日记</span><span class="bl">JOURNAL · {pad2(now.getHours())}:{pad2(now.getMinutes())}</span>
          <span class="rule"></span>
          <span class="key">{todayChars}<span class="ks"> 字{streak > 0 ? ` · 连 ${streak} 天` : ''}</span></span>
        </div>
        <div class="jr">
          <span class="car" aria-hidden="true"></span>
          {#if todayEntries.length === 0}
            写两行今天…
          {:else}
            {todayEntries[todayEntries.length - 1].content.slice(0, 42)}
          {/if}
          <button
            class="aibtn"
            onclick={(e) => {
              e.stopPropagation()
              layout.setMode('journal')
            }}>AI 今日小结</button
          >
        </div>
      </section>

      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
      <section role="listitem" class="blk" class:focus={focus === 'agent'} onclick={() => (focus = 'agent')}>
        <div class="bh">
          <span class="bt">智能体</span><span class="bl">AGENT · {runningCount > 0 ? 'RUNNING' : 'IDLE'}</span>
          <span class="rule"></span>
          <span class="key">{lastRunTime ?? '—'}<span class="ks"> 上次运行</span></span>
        </div>
        {#if latestRuns.length === 0}
          <div class="emptyline">没有 agent 运行 — 驾驶舱里跑一条。</div>
        {:else}
          {#each latestRuns as r (r.id)}
            <div class="agl">
              <span
                class="sdot"
                class:run={r.status === 'running'}
                class:ok={r.status === 'completed' || r.status === 'done'}
                class:err={r.status === 'failed' || r.status === 'error'}
                aria-hidden="true"
              ></span>
              <span class="nm">{r.agent}</span>
              <span class="ac">{(r.prompt ?? '').slice(0, 44) || r.status}</span>
              <span class="st">{r.started_at ? localHHMM(r.started_at) : r.status.toUpperCase()}</span>
            </div>
          {/each}
        {/if}
      </section>

      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
      <section role="listitem" class="blk" class:focus={focus === 'recent'} onclick={() => (focus = 'recent')}>
        <div class="bh">
          <span class="bt">最近</span><span class="bl">RECENT · 项目</span>
          <span class="rule"></span>
          <span class="key">{cockpit.projects.length}<span class="ks"> 项目</span></span>
        </div>
        {#if recent.length === 0}
          <div class="emptyline">还没有项目 — 驾驶舱里打开一个文件夹。</div>
        {:else}
          <div class="chips">
            {#each recent as p (p.path)}
              <button
                class="chip"
                onclick={(e) => {
                  e.stopPropagation()
                  openProject(p.path)
                }}
              >
                <b>{p.name}</b>
              </button>
            {/each}
          </div>
        {/if}
      </section>

      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
      <section role="listitem" class="blk last" class:focus={focus === 'schedule'} onclick={() => (focus = 'schedule')}>
        <div class="bh">
          <span class="bt">日程</span><span class="bl">SCHEDULE · 下一项</span>
          <span class="rule"></span>
          <span class="key">{nextEvent?.start ? localHHMM(nextEvent.start) : '—'}<span class="ks"> {nextIn}</span></span>
        </div>
        {#if !nextEvent}
          <div class="emptyline">没有即将到来的日程。</div>
        {:else}
          <div class="evline">
            <span class="from">{nextEvent.summary}</span>
            {#if nextEvent.location}<span class="sj">— {nextEvent.location}</span>{/if}
          </div>
        {/if}
      </section>

      <div class="qacts">
        <button class="qa pri" onclick={newChat}>＋ 新 Chat</button>
        <button class="qa" onclick={newResearch}>发起研究</button>
        <button class="qa" onclick={() => layout.openCapture()}>记一条 · ⌘N</button>
      </div>
    </div>

    <!-- 右柱:世界输入(常亮 chrome,不参与聚光) -->
    <aside class="brief" aria-label="世界输入">
      <div class="bhh"><span>BRIEFING</span><span class="r">世界输入</span></div>
      <div class="bsec">
        <div class="blab"><span>NEWS</span><span class="r">Hacker News{brief.length ? ` · ${brief.length} 条` : ''}</span></div>
        {#if brief.length === 0}
          <p class="bempty">拿不到头条 — 离线或源超时。</p>
        {:else}
          {#each brief as b (b.url)}
            <button class="news" onclick={() => window.open(b.url, '_blank')}>
              <span class="nt">{b.title}</span>
              <span class="nm2">{b.source} · {b.ago}</span>
            </button>
          {/each}
        {/if}
      </div>
      <div class="ghost">+ 接入更多源 — RSS · 行情 · Newsletter</div>
    </aside>
  </div>
</div>

<style>
  .rd3 {
    height: 100%;
    display: flex;
    flex-direction: column;
    min-height: 0;
    font-family: var(--sans);
  }

  /* —— 屏锚(恒亮) —— */
  .dial {
    display: flex;
    align-items: flex-end;
    gap: 26px;
    flex: none;
    padding: 22px 42px 16px;
    border-bottom: 1px solid var(--line);
    max-width: 100%;
  }
  .clock {
    font: 800 72px/0.94 var(--mono);
    letter-spacing: -2px;
    color: var(--t1);
    font-variant-numeric: tabular-nums;
  }
  .clock .sec {
    font-size: 22px;
    font-weight: 700;
    color: var(--t4);
    letter-spacing: 0;
  }
  .datecol {
    display: flex;
    flex-direction: column;
    padding-bottom: 6px;
  }
  .datecol .d1 {
    font: 800 22px/1.1 var(--mono);
    color: var(--t1);
    letter-spacing: 1px;
    font-variant-numeric: tabular-nums;
  }
  .datecol .d2 {
    font: 400 12px/1.6 var(--mono);
    color: var(--t3);
    letter-spacing: 2px;
  }
  .dmeta {
    margin-left: auto;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 2px;
    padding-bottom: 6px;
    font: 700 9px/1.6 var(--mono);
    letter-spacing: 1.5px;
    color: var(--t4);
    text-transform: uppercase;
    font-variant-numeric: tabular-nums;
  }
  .dmeta .acc {
    color: var(--acc-ink);
  }

  /* —— 两区 —— */
  .body3 {
    flex: 1;
    min-height: 0;
    display: grid;
    grid-template-columns: minmax(0, 1fr) 300px;
  }
  .ledger {
    min-width: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
  }

  /* —— 区块聚光制 —— */
  .blk {
    padding: 13px 30px 12px 40px;
    cursor: default;
    box-shadow: inset 2px 0 0 transparent;
    transition:
      background 0.28s cubic-bezier(0.32, 0.72, 0, 1),
      box-shadow 0.28s cubic-bezier(0.32, 0.72, 0, 1);
  }
  .blk + .blk {
    border-top: 1px solid var(--hair);
  }
  .blk.focus {
    background: var(--tile);
    box-shadow: inset 2px 0 0 var(--acc);
  }
  /* 区块头:名 15/700 + 9 标签 + 发丝撑开 + 22px key 挂右端 */
  .bh {
    display: flex;
    align-items: baseline;
    gap: 10px;
    margin-bottom: 8px;
  }
  .bt {
    font-size: 15px;
    font-weight: 700;
    color: var(--t3);
  }
  .bl {
    font: 700 9px/1 var(--mono);
    letter-spacing: 1.5px;
    text-transform: uppercase;
    color: var(--t4);
  }
  .rule {
    flex: 1;
    height: 1px;
    background: var(--hair);
    align-self: center;
  }
  .key {
    font: 700 22px/1 var(--mono);
    color: var(--t4);
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.5px;
    white-space: nowrap;
  }
  .key .ks {
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 1px;
    color: var(--t4);
  }
  .blk.focus .bt {
    color: var(--t1);
  }
  .blk.focus .key {
    color: var(--acc-ink);
  }
  .blk.focus .key .ks {
    color: var(--t3);
  }

  /* 区块内容(焦点亮/非焦点暗) */
  .blk {
    color: var(--t4);
  }
  .blk.focus {
    color: var(--t2);
  }
  .task {
    display: flex;
    align-items: center;
    gap: 9px;
    font-size: 15px;
    padding: 3px 0;
  }
  .blk.focus .task {
    color: var(--t1);
  }
  .cbx {
    width: 13px;
    height: 13px;
    border: 1px solid var(--t4);
    background: transparent;
    cursor: pointer;
    flex: none;
    padding: 0;
  }
  .cbx.done {
    background: var(--t4);
  }
  .blk.focus .cbx {
    border-color: var(--t3);
  }
  .strk {
    text-decoration: line-through;
    opacity: 0.6;
  }
  .due {
    margin-left: auto;
    font: 400 12px/1 var(--mono);
    font-variant-numeric: tabular-nums;
  }
  .due.hot {
    color: var(--acc-ink);
  }
  .emptyline {
    font-size: 13px;
    padding: 2px 0;
  }
  .jr {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 15px;
  }
  .car {
    width: 2px;
    height: 16px;
    background: var(--acc);
    animation: blink 1.1s steps(1) infinite;
  }
  @keyframes blink {
    50% {
      opacity: 0;
    }
  }
  .aibtn {
    margin-left: auto;
    font: 700 10px/1 var(--mono);
    letter-spacing: 0.5px;
    color: var(--t3);
    background: transparent;
    border: 1px solid var(--line);
    padding: 5px 10px;
    cursor: pointer;
  }
  .aibtn:hover {
    color: var(--t1);
    border-color: var(--acc);
  }
  .agl {
    display: flex;
    align-items: baseline;
    gap: 8px;
    font-size: 13px;
    padding: 2px 0;
  }
  .sdot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--t4);
    align-self: center;
  }
  .sdot.run {
    background: var(--acc);
  }
  .sdot.ok {
    background: var(--green);
  }
  .sdot.err {
    background: var(--red, #d33);
  }
  .agl .nm {
    font-weight: 600;
  }
  .agl .ac {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .agl .st {
    margin-left: auto;
    font: 400 11px/1 var(--mono);
    font-variant-numeric: tabular-nums;
  }
  .chips {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .chip {
    font: 400 12px/1 var(--mono);
    color: inherit;
    background: transparent;
    border: 1px solid var(--line);
    padding: 6px 12px;
    cursor: pointer;
  }
  .chip b {
    font-weight: 700;
  }
  .blk.focus .chip:hover {
    border-color: var(--acc);
    color: var(--t1);
  }
  .evline {
    font-size: 15px;
  }
  .evline .sj {
    color: var(--t4);
  }
  .blk.last {
    flex: none;
  }
  .qacts {
    display: flex;
    gap: 10px;
    padding: 18px 30px 22px 40px;
    margin-top: auto;
  }
  .qa {
    font: 600 13px/1 var(--sans);
    color: var(--t2);
    background: transparent;
    border: 1px solid var(--line);
    padding: 9px 14px;
    cursor: pointer;
  }
  .qa.pri {
    border-color: var(--t2);
    color: var(--t1);
  }
  .qa:hover {
    border-color: var(--acc);
    color: var(--t1);
  }

  /* —— 右柱:世界输入(常亮) —— */
  .brief {
    border-left: 1px solid var(--line);
    background: var(--chrome);
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow-y: auto;
  }
  .bhh {
    display: flex;
    justify-content: space-between;
    padding: 12px 16px 10px;
    font: 700 9px/1 var(--mono);
    letter-spacing: 2px;
    color: var(--t3);
    border-bottom: 1px solid var(--hair);
  }
  .bhh .r {
    color: var(--t4);
    letter-spacing: 1px;
  }
  .bsec {
    padding: 12px 16px;
    border-bottom: 1px solid var(--hair);
  }
  .blab {
    display: flex;
    justify-content: space-between;
    font: 700 9px/1 var(--mono);
    letter-spacing: 1.5px;
    color: var(--t4);
    margin-bottom: 10px;
  }
  .news {
    display: block;
    width: 100%;
    text-align: left;
    background: transparent;
    border: 0;
    padding: 5px 0;
    cursor: pointer;
  }
  .news .nt {
    display: block;
    font-size: 12.5px;
    color: var(--t2);
    line-height: 1.45;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .news:hover .nt {
    color: var(--t1);
  }
  .news .nm2 {
    display: block;
    font: 400 9px/1.8 var(--mono);
    letter-spacing: 0.5px;
    color: var(--t4);
  }
  .bempty {
    font-size: 12px;
    color: var(--t4);
    margin: 0;
  }
  .ghost {
    margin: 12px 16px;
    border: 1px dashed var(--line);
    padding: 12px;
    font: 400 10px/1.7 var(--mono);
    letter-spacing: 0.5px;
    color: var(--t4);
  }
</style>
