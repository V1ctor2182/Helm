<script lang="ts">
  import { onMount } from 'svelte'
  import { layout } from './layout.svelte'
  import { tasks } from './notes/tasksStore.svelte'
  import { notes } from './notes/notesStore.svelte'
  import { agent } from './orchestration/agentStore.svelte'
  import { cockpit } from './cockpit/cockpit.svelte'
  import { calendar } from './mail/calendarStore.svelte'
  import { toLocal, localHHMM, localDateTime, localDate } from './time'

  // Today = 无卡片仪表读数(承 helm-pro.html `.rd`)。阶段2:各节接真 /api,
  // 版式与阶段1对齐版一致;无数据走空态。邮件行按用户 2026-06-28 决定换成下个日程。

  let now = $state(new Date())

  onMount(() => {
    void tasks.load()
    void notes.load()
    void agent.loadRuns()
    void cockpit.loadProjects()
    void calendar.load()
    const t = setInterval(() => (now = new Date()), 30_000)
    return () => clearInterval(t)
  })

  const pad2 = (n: number) => String(n).padStart(2, '0')
  const pad3 = (n: number) => String(n).padStart(3, '0')
  const headDate = $derived(
    `周${'日一二三四五六'[now.getDay()]} · ${pad2(now.getDate())}.${pad2(now.getMonth() + 1)} · ${pad2(now.getHours())}:${pad2(now.getMinutes())}`,
  )
  const todayStr = $derived(`${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`)

  // 任务:启用在前、按下次触发时间升序,取 3
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

  // 日记:今天的条目
  const todayEntries = $derived(notes.notes.filter((n) => n.kind === 'journal' && n.journal_date === todayStr))

  // Agent:最近 2 次运行
  const latestRuns = $derived(agent.runs.slice(0, 2))
  const runningCount = $derived(agent.runs.filter((r) => r.status === 'running').length)

  // 项目:最近 2 个
  const recent = $derived(cockpit.projects.slice(0, 2))

  // 日程:下一个未来事件
  const nextEvent = $derived(
    [...calendar.events]
      .filter((e) => e.start && toLocal(e.start).getTime() >= now.getTime())
      .sort((a, b) => (a.start ?? '').localeCompare(b.start ?? ''))[0] ?? null,
  )

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

<div class="rd">
  <header class="rdhead">
    <h1>Today</h1>
    <span class="date">{headDate}</span>
    <span class="pg">{pad3(tasks.tasks.length)} TASKS · {pad3(agent.runs.length)} RUNS</span>
  </header>

  <div class="rdrow">
    <div class="gut"><span class="tm">今日</span><br />{enabledCount} 启用</div>
    <div>
      <div class="h">任务 / TASKS</div>
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
              onclick={() => tasks.toggle(t)}
            ></button>
            <span class:strk={!t.enabled}>{t.name}</span>
            <span class="due" class:hot={t.enabled && dueSoon(t.next_run)}>{t.enabled ? localHHMM(t.next_run) || '—' : '停用'}</span>
          </div>
        {/each}
      {/if}
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">{pad2(now.getHours())}:{pad2(now.getMinutes())}</span><br />{todayEntries.length} 条</div>
    <div>
      <div class="h">日记 / JOURNAL</div>
      <div class="jr">
        <span class="car" aria-hidden="true"></span>
        {#if todayEntries.length === 0}
          写两行今天…
        {:else}
          {todayEntries[todayEntries.length - 1].content.slice(0, 42)}
        {/if}
        <button class="aibtn" onclick={() => layout.setMode('journal')}>AI 今日小结</button>
      </div>
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">刚刚</span><br />{runningCount} 活跃</div>
    <div>
      <div class="h">Agent 收件箱 / VIEWPORT</div>
      <div class="framed">
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
              <span class="ac">
                {#if r.status === 'running'}<span class="cstar" aria-hidden="true">✻</span> {/if}{(r.prompt ?? '').slice(0, 40) || r.status}
              </span>
              <span class="st">{r.started_at ? localHHMM(r.started_at) : r.status.toUpperCase()}</span>
            </div>
          {/each}
        {/if}
      </div>
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">最近</span></div>
    <div>
      <div class="h">最近项目 / PROJECTS</div>
      {#if recent.length === 0}
        <div class="emptyline">还没有项目 — 驾驶舱里打开一个文件夹。</div>
      {:else}
        {#each recent as p (p.path)}
          <button class="projline" onclick={() => openProject(p.path)}>
            <span class="pd" aria-hidden="true"></span>
            <span class="pp">{p.name}</span>
            <span class="br">{p.last_opened ? localDate(p.last_opened) : p.path}</span>
          </button>
        {/each}
      {/if}
    </div>
  </div>

  <div class="rdrow">
    <div class="gut"><span class="tm">下个</span></div>
    <div>
      <div class="h">日程 / NEXT</div>
      {#if !nextEvent}
        <div class="emptyline">没有即将到来的日程。</div>
      {:else}
        <div class="mailn">
          <span class="fl" aria-hidden="true"></span>
          <span class="from">{nextEvent.summary}</span>
          {#if nextEvent.location}<span class="sj">— {nextEvent.location}</span>{/if}
          <span class="urg">{localDateTime(nextEvent.start)}</span>
        </div>
      {/if}
    </div>
  </div>

  <div class="qacts">
    <button class="qa pri" onclick={newChat}>＋ 新 Chat</button>
    <button class="qa" onclick={newResearch}>发起研究</button>
    <button class="qa" onclick={() => layout.openCapture()}>记一条 · ⌘N</button>
  </div>
</div>

<style>
  .rd {
    height: 100%;
    overflow: auto;
    padding: 18px 24px 24px 0;
    font-family: var(--sans);
  }
  .rdhead {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding-left: var(--gutter-w);
    margin-bottom: 6px;
  }
  .rdhead h1 {
    font-family: var(--mono);
    font-size: 24px;
    font-weight: 800;
    letter-spacing: 1px;
    color: var(--t1);
    margin: 0;
  }
  .rdhead .date {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--acc-ink);
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  .rdhead .pg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .5px;
    font-variant-numeric: tabular-nums; /* DESIGN:数据/计数一律 tabular */
  }
  .rdrow {
    display: grid;
    grid-template-columns: var(--gutter-w) 1fr;
    border-top: 1px solid var(--hair);
    padding: 10px 0;
  }
  .rdrow:first-of-type {
    border-top: none;
  }
  .gut {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    line-height: 1.5;
    padding-top: 3px;
    letter-spacing: .3px;
    font-variant-numeric: tabular-nums;
  }
  .gut .tm {
    color: var(--t3);
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 7px;
  }
  .task {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 3px 0;
    font-size: 13px;
    color: var(--t2);
  }
  .cbx {
    width: 13px;
    height: 13px;
    border: 1.4px solid var(--t4);
    background: transparent;
    flex: none;
    cursor: pointer;
    padding: 0;
  }
  .cbx.done {
    border-color: var(--acc-ink);
    background: var(--acc);
  }
  .strk {
    color: var(--t4);
    text-decoration: line-through;
  }
  .due {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .due.hot {
    color: var(--orange);
  }
  .jr {
    display: flex;
    align-items: center;
    gap: 9px;
    color: var(--t4);
    font-size: 13px;
    min-width: 0;
  }
  .car {
    width: 2px;
    height: 14px;
    background: var(--acc);
    display: inline-block;
    flex: none;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .aibtn {
    margin-left: auto;
    flex: none;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    background: transparent;
    padding: 3px 8px;
    cursor: pointer;
  }
  /* Agent 框选视口(frame + 琥珀 L 角) */
  .framed {
    position: relative;
    border: 1px solid var(--line);
    padding: 10px 12px;
    margin-top: 2px;
  }
  .framed::before,
  .framed::after {
    content: '';
    position: absolute;
    width: 9px;
    height: 9px;
    border: 1.4px solid var(--acc-ink);
  }
  .framed::before {
    top: -1px;
    left: -1px;
    border-right: none;
    border-bottom: none;
  }
  .framed::after {
    bottom: -1px;
    right: -1px;
    border-left: none;
    border-top: none;
  }
  .agl {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
  }
  .sdot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex: none;
    background: var(--t4);
  }
  .sdot.ok { background: var(--green); }
  .sdot.run { background: var(--acc); }
  .sdot.err { background: var(--red); }
  .agl .nm {
    color: var(--t1);
    font-weight: 600;
    font-size: 12px;
  }
  .agl .ac {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t3);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }
  .agl .st {
    margin-left: auto;
    flex: none;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .cstar {
    color: var(--acc-ink);
    display: inline-block;
    animation: cspin 1.1s ease-in-out infinite;
  }
  @keyframes cspin {
    0% { transform: rotate(0) scale(.85); opacity: .6; }
    50% { transform: rotate(180deg) scale(1.12); opacity: 1; }
    100% { transform: rotate(360deg) scale(.85); opacity: .6; }
  }
  .projline {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
    font-size: 12.5px;
    width: 100%;
    background: transparent;
    border: 0;
    cursor: pointer;
    text-align: left;
  }
  .projline .pd {
    width: 13px;
    height: 13px;
    border-radius: 3px;
    background: linear-gradient(135deg, #e8a07a, #6a4f8f);
    flex: none;
  }
  .projline .pp {
    color: var(--t2);
  }
  .projline:hover .pp {
    color: var(--t1);
  }
  .projline .br {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    margin-left: auto;
    font-variant-numeric: tabular-nums;
  }
  .mailn {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
    font-size: 12.5px;
    min-width: 0;
  }
  .mailn .fl {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--acc);
    flex: none;
  }
  .mailn .from {
    color: var(--t2);
  }
  .mailn .sj {
    color: var(--t4);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }
  .mailn .urg {
    margin-left: auto;
    flex: none;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .emptyline {
    color: var(--t4);
    font-size: 12.5px;
  }
  .qacts {
    padding-left: var(--gutter-w);
    margin-top: 15px;
    display: flex;
    gap: 8px;
  }
  .qa {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t3);
    border: 1px solid var(--line);
    background: transparent;
    padding: 6px 11px;
    cursor: pointer;
  }
  .qa:hover {
    color: var(--t1);
  }
  .qa.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
</style>
