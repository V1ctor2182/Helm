<script lang="ts">
  // Calendar lives with journal/tasks (the time/planning cluster). The store
  // still sits under mail/ from the original email-calendar room; mail itself
  // is currently disabled but the calendar capability stands alone.
  import { calendar, type CalEvent } from '../mail/calendarStore.svelte'
  import { localDate, localHHMM } from '../time'
  import { ConfirmGate } from '../confirm.svelte'

  let evSummary = $state('')
  const del = new ConfirmGate()
  // 列表(agenda)/ 月网格 双视图
  let calView = $state<'list' | 'month'>('list')
  let monthCursor = $state(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
  let evStart = $state('')
  let showCaldav = $state(false)
  let cdav = $state({ name: '', url: '', username: '', password: '' })

  async function addEvent() {
    if (await calendar.add(evSummary, evStart)) {
      evSummary = ''
      evStart = ''
    }
  }

  async function addCaldav() {
    if (await calendar.addCaldav(cdav)) {
      showCaldav = false
      cdav = { name: '', url: '', username: '', password: '' }
    }
  }

  async function doImport() {
    const text = window.prompt?.('粘贴 .ics 内容')
    if (text) await calendar.importIcs(text)
  }

  async function doExport() {
    const ics = await calendar.exportIcs()
    if (ics && typeof URL.createObjectURL === 'function') {
      const url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' }))
      const a = document.createElement('a')
      a.href = url
      a.download = 'helm-calendar.ics'
      a.click()
      URL.revokeObjectURL(url)
    }
  }

  // 日程账本:按本地日期分组(全天事件按原始日期,避免 UTC 解析漂移一天),
  // 组内按开始时间升序,最近的日期在前。
  function dayKey(ev: CalEvent): string {
    if (!ev.start) return '未定'
    return ev.all_day ? ev.start.slice(0, 10) : localDate(ev.start)
  }
  const pad2 = (n: number) => String(n).padStart(2, '0')
  const fmtDay = (y: number, m: number, d: number) => `${y}-${pad2(m + 1)}-${pad2(d)}`
  const todayStr = $derived(fmtDay(new Date().getFullYear(), new Date().getMonth(), new Date().getDate()))
  const monthLabel = $derived(`${monthCursor.getFullYear()}-${pad2(monthCursor.getMonth() + 1)}`)

  function shiftMonth(delta: number) {
    monthCursor = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + delta, 1)
  }

  // 月网格:周一开头,前置空位 + 当月各天(挂上当日事件)
  const monthCells = $derived(
    (() => {
      const y = monthCursor.getFullYear()
      const m = monthCursor.getMonth()
      const byDay = new Map<string, CalEvent[]>()
      for (const ev of calendar.events) {
        const k = dayKey(ev)
        ;(byDay.get(k) ?? byDay.set(k, []).get(k)!).push(ev)
      }
      const lead = (new Date(y, m, 1).getDay() + 6) % 7
      const days = new Date(y, m + 1, 0).getDate()
      const cells: { date: string | null; day: number; events: CalEvent[] }[] = []
      for (let i = 0; i < lead; i++) cells.push({ date: null, day: 0, events: [] })
      for (let d = 1; d <= days; d++) {
        const key = fmtDay(y, m, d)
        cells.push({ date: key, day: d, events: byDay.get(key) ?? [] })
      }
      return cells
    })(),
  )

  const eventsByDay = $derived(
    (() => {
      const groups = new Map<string, CalEvent[]>()
      const sorted = [...calendar.events].sort((a, b) => (a.start ?? '').localeCompare(b.start ?? ''))
      for (const ev of sorted) {
        const d = dayKey(ev)
        ;(groups.get(d) ?? groups.set(d, []).get(d)!).push(ev)
      }
      return [...groups.entries()].sort((a, b) => a[0].localeCompare(b[0]))
    })(),
  )
</script>

<div class="cal">
  <div class="toolrow">
    <div class="h">日程 / AGENDA</div>
    <span class="vsel" role="tablist" aria-label="日程视图">
      <button class="act" class:on={calView === 'list'} role="tab" aria-selected={calView === 'list'} onclick={() => (calView = 'list')}>列表</button>
      <button class="act" class:on={calView === 'month'} role="tab" aria-selected={calView === 'month'} onclick={() => (calView = 'month')}>月</button>
    </span>
  </div>

  <div class="tools">
    <button class="act" onclick={doImport}>导入 .ics</button>
    <button class="act" onclick={doExport} disabled={!calendar.events.length}>导出 .ics</button>
    {#if calendar.caldavAccounts.length}
      <button class="act pri" onclick={() => calendar.syncCaldav()} disabled={calendar.syncing}>
        {calendar.syncing ? 'CalDAV 同步中…' : 'CalDAV 同步'}
      </button>
    {/if}
    <button class="act" onclick={() => (showCaldav = !showCaldav)}>+ CalDAV</button>
  </div>

  <form class="compose" onsubmit={(e) => { e.preventDefault(); void addEvent() }}>
    <span class="car" aria-hidden="true"></span>
    <input placeholder="事件标题" bind:value={evSummary} aria-label="事件标题" />
    <input class="dt" type="datetime-local" bind:value={evStart} aria-label="开始时间" />
    <button class="act pri" type="submit" disabled={!evSummary.trim() || !evStart}>加事件</button>
  </form>

  {#if showCaldav}
    <form class="cdform" onsubmit={(e) => { e.preventDefault(); void addCaldav() }}>
      <input placeholder="名称" bind:value={cdav.name} aria-label="CalDAV 名称" />
      <input placeholder="CalDAV URL(如 https://caldav.icloud.com)" bind:value={cdav.url} aria-label="CalDAV URL" />
      <input placeholder="用户名" bind:value={cdav.username} aria-label="CalDAV 用户名" />
      <input type="password" placeholder="密码 / 应用专用密码" bind:value={cdav.password} aria-label="CalDAV 密码" />
      <button class="act pri" type="submit" disabled={!cdav.url.trim() || !cdav.password.trim()}>添加(凭据加密存储)</button>
    </form>
  {/if}
  {#if calendar.error}<p class="err" role="alert">{calendar.error}</p>{/if}
  {#if calendar.syncMsg}<p class="cmsg">{calendar.syncMsg}</p>{/if}

  {#if calView === 'month'}
    <div class="mnav">
      <button class="act" aria-label="上一月" onclick={() => shiftMonth(-1)}>‹</button>
      <span class="mlabel">{monthLabel}</span>
      <button class="act" aria-label="下一月" onclick={() => shiftMonth(1)}>›</button>
    </div>
    <div class="mgrid">
      {#each ['一', '二', '三', '四', '五', '六', '日'] as w (w)}
        <div class="mw">{w}</div>
      {/each}
      {#each monthCells as c, i (i)}
        <div class="mc" class:blank={!c.date} class:istoday={c.date === todayStr}>
          {#if c.date}
            <span class="mnum">{c.day}</span>
            {#each c.events.slice(0, 2) as ev (ev.id)}
              <span class="mev" title={ev.summary}>{ev.summary}</span>
            {/each}
            {#if c.events.length > 2}<span class="mmore">+{c.events.length - 2}</span>{/if}
          {/if}
        </div>
      {/each}
    </div>
  {:else if calendar.events.length === 0}
    <p class="empty">还没有日程 — 加一个事件,或导入 .ics。</p>
  {:else}
    {#each eventsByDay as [day, evs] (day)}
      <section class="day">
        <h3>{day}</h3>
        {#each evs as ev (ev.id)}
          <div class="event">
            <span class="when">{ev.all_day ? '全天' : localHHMM(ev.start)}</span>
            <span class="esum">{ev.summary}</span>
            {#if ev.location}<span class="eloc">{ev.location}</span>{/if}
            <span class="esrc">{ev.source === 'caldav' ? 'CALDAV' : 'LOCAL'}</span>
            <button
              class="act del"
              class:armed={del.pending === `ev-${ev.id}`}
              aria-label={`删除 ${ev.summary}`}
              onclick={() => del.confirm(`ev-${ev.id}`) && calendar.remove(ev.id)}
            >{del.pending === `ev-${ev.id}` ? '确认' : '×'}</button>
          </div>
        {/each}
      </section>
    {/each}
  {/if}
</div>

<style>
  .cal {
    display: flex;
    flex-direction: column;
    gap: 8px;
    font-family: var(--sans);
    color: var(--t2);
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .tools {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .act {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 10px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .act:hover:not(:disabled) {
    color: var(--t1);
  }
  .act:disabled {
    cursor: default;
    color: var(--t4);
    border-color: var(--hair);
  }
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
  }
  .act.del {
    border: 0;
    padding: 2px 4px;
  }
  .act.del:hover,
  .act.del.armed {
    color: var(--red);
  }
  .compose {
    display: flex;
    align-items: center;
    gap: 9px;
  }
  .car {
    width: 2px;
    height: 14px;
    background: var(--acc);
    flex: none;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .compose input,
  .cdform input {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 13px;
    padding: 3px 0 6px;
    min-width: 0;
  }
  .compose input::placeholder,
  .cdform input::placeholder {
    color: var(--t4);
  }
  .compose input:focus,
  .cdform input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .compose input {
    flex: 1;
  }
  .compose input.dt {
    flex: none;
    width: 190px;
    font-family: var(--mono);
    font-size: 11px;
    color-scheme: dark light;
  }
  .cdform {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    border: 1px solid var(--line);
    padding: 10px 12px;
  }
  .cdform input {
    flex: 1;
    min-width: 150px;
  }
  .cmsg {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--green);
    margin: 0;
  }
  .err {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
    margin: 0;
  }
  .day h3 {
    margin: 10px 0 4px;
    font-family: var(--mono);
    font-size: 11px;
    font-weight: 700;
    letter-spacing: .5px;
    color: var(--acc-ink);
    border-bottom: 1px solid var(--hair);
    padding-bottom: 3px;
    font-variant-numeric: tabular-nums;
  }
  .day:first-of-type h3 {
    margin-top: 2px;
  }
  .event {
    display: flex;
    gap: 10px;
    align-items: center;
    padding: 4px 0;
    border-top: 1px solid var(--hair);
    font-size: 13px;
  }
  .day .event:first-of-type {
    border-top: none;
  }
  .when {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    flex: none;
    min-width: 34px;
    font-variant-numeric: tabular-nums;
  }
  .esum {
    flex: 1;
    color: var(--t2);
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .eloc {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
  }
  .esrc {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
    margin: 2px 0;
  }
  .toolrow {
    display: flex;
    align-items: baseline;
    gap: 12px;
  }
  .vsel {
    margin-left: auto;
    display: flex;
    gap: 8px;
  }
  .act.on {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .mnav {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .mlabel {
    font-family: var(--mono);
    font-size: 12px;
    font-weight: 700;
    color: var(--acc-ink);
    font-variant-numeric: tabular-nums;
  }
  .mgrid {
    display: grid;
    grid-template-columns: repeat(7, minmax(0, 1fr));
  }
  .mw {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
    text-align: center;
    padding: 4px 0;
    border-bottom: 1px solid var(--hair);
  }
  .mc {
    min-height: 64px;
    border-right: 1px solid var(--hair);
    border-bottom: 1px solid var(--hair);
    padding: 3px 5px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }
  .mc:nth-child(7n) {
    border-right: none;
  }
  .mc.blank {
    background: transparent;
  }
  .mc.istoday .mnum {
    color: var(--acc-ink);
    font-weight: 700;
  }
  .mnum {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    font-variant-numeric: tabular-nums;
  }
  .mev {
    font-size: 10.5px;
    color: var(--t2);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    border-left: 2px solid var(--acc);
    padding-left: 4px;
  }
  .mmore {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
  }
</style>
