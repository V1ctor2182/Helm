<script lang="ts">
  // Calendar lives with journal/tasks (the time/planning cluster). The store
  // still sits under mail/ from the original email-calendar room; mail itself
  // is currently disabled but the calendar capability stands alone.
  import { calendar, type CalEvent } from '../mail/calendarStore.svelte'
  import { tasks, type Task } from './tasksStore.svelte'
  import { notes, type Note } from './notesStore.svelte'
  import { localDate, localHHMM } from '../time'
  import { ConfirmGate } from '../confirm.svelte'

  let evSummary = $state('')
  const del = new ConfirmGate()
  // 列表(agenda)/ 月网格 双视图
  let calView = $state<'week' | 'list' | 'month'>('week')
  let weekOff = $state(0)
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

  // ── 周视图(阶段 4 R09,稿:helm-journal-pro.html Calendar)──
  const H0 = 8, H1 = 22, ROW = 44
  const weekDays = $derived(
    (() => {
      const now = new Date()
      const mon = new Date(now)
      mon.setDate(now.getDate() - ((now.getDay() + 6) % 7) + weekOff * 7)
      return Array.from({ length: 7 }, (_, i) => {
        const d = new Date(mon)
        d.setDate(mon.getDate() + i)
        return fmtDay(d.getFullYear(), d.getMonth(), d.getDate())
      })
    })(),
  )
  interface WkItem { key: string; title: string; hh: number; mm: number; kind: 'event' | 'task' | 'note' | 'journal' }
  const weekItems = $derived(
    (() => {
      const m = new Map<string, WkItem[]>()
      const push = (day: string, it: WkItem) => (m.get(day) ?? m.set(day, []).get(day)!).push(it)
      for (const ev of calendar.events) {
        if (!ev.start || ev.all_day) continue
        const day = localDate(ev.start)
        if (!weekDays.includes(day)) continue
        const d = new Date(ev.start)
        push(day, { key: `e${ev.id}`, title: ev.summary, hh: d.getHours(), mm: d.getMinutes(), kind: 'event' })
      }
      for (const t of tasks.tasks) {
        if (!t.enabled || !t.next_run) continue
        const day = localDate(t.next_run)
        if (!weekDays.includes(day)) continue
        const d = new Date(t.next_run)
        push(day, { key: `t${t.id}`, title: t.name, hh: d.getHours(), mm: d.getMinutes(), kind: 'task' })
      }
      // 所有记录都上日历(2026-07-08 用户拍板):速记/收藏(蓝)/日记(琥珀)按创建时间落格
      for (const n of notes.notes) {
        if (!n.created_at) continue
        const day = localDate(n.created_at)
        if (!weekDays.includes(day)) continue
        const d = new Date(n.created_at)
        const title = n.kind === 'journal'
          ? `日记 · ${n.content.slice(0, 14)}`
          : (n.meta?.title ?? n.content.slice(0, 18))
        push(day, {
          key: `n${n.id}`, title, hh: d.getHours(), mm: d.getMinutes(),
          kind: n.kind === 'journal' ? 'journal' : 'note',
        })
      }
      return m
    })(),
  )
  const nowLine = $derived(
    (() => {
      const n = new Date()
      const today = fmtDay(n.getFullYear(), n.getMonth(), n.getDate())
      const col = weekDays.indexOf(today)
      if (col < 0 || n.getHours() < H0 || n.getHours() >= H1) return null
      return (n.getHours() - H0) * ROW + Math.round((ROW * n.getMinutes()) / 60)
    })(),
  )
  const WD2 = ['一', '二', '三', '四', '五', '六', '日']

  function shiftMonth(delta: number) {
    monthCursor = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + delta, 1)
  }

  // 任务上日历(2026-07-06 用户:记录页还有任务,要 calendarview 式的呈现):
  // 启用任务按 next_run 的本地日分组,与事件并排落格。
  const tasksByDay = $derived(
    (() => {
      const byDay = new Map<string, Task[]>()
      for (const t of tasks.tasks) {
        if (!t.enabled || !t.next_run) continue
        const k = localDate(t.next_run)
        ;(byDay.get(k) ?? byDay.set(k, []).get(k)!).push(t)
      }
      return byDay
    })(),
  )

  // 月网格:周一开头,前置空位 + 当月各天(挂上当日事件 + 当日将跑的任务)
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
      const cells: { date: string | null; day: number; events: CalEvent[]; dayTasks: Task[] }[] = []
      for (let i = 0; i < lead; i++) cells.push({ date: null, day: 0, events: [], dayTasks: [] })
      for (let d = 1; d <= days; d++) {
        const key = fmtDay(y, m, d)
        cells.push({ date: key, day: d, events: byDay.get(key) ?? [], dayTasks: tasksByDay.get(key) ?? [] })
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

  // 列表(agenda)合流:事件 + 任务同一天并排(先事件后任务)。
  const agendaDays = $derived(
    (() => {
      const evMap = new Map(eventsByDay)
      const days = new Set<string>([...evMap.keys(), ...tasksByDay.keys()])
      return [...days].sort().map((d) => ({
        day: d,
        evs: evMap.get(d) ?? [],
        dts: tasksByDay.get(d) ?? [],
      }))
    })(),
  )
</script>

<div class="cal">
  <div class="toolrow">
    <div class="h">日程 / AGENDA</div>
    <span class="vsel" role="tablist" aria-label="日程视图">
      <button class="act" class:on={calView === 'week'} role="tab" aria-selected={calView === 'week'} onclick={() => (calView = 'week')}>周</button>
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

  {#if calView === 'week'}
    <div class="wk">
      <div class="wknav">
        <button class="nbtn" aria-label="上一周" onclick={() => (weekOff -= 1)}>‹</button>
        <span class="wkrng">{weekDays[0]?.slice(5)} — {weekDays[6]?.slice(5)}</span>
        <button class="nbtn" aria-label="下一周" onclick={() => (weekOff += 1)}>›</button>
        <button class="todaybtn" onclick={() => (weekOff = 0)}>今天</button>
        <span class="tz">GMT+8 · 本地</span>
      </div>
      <div class="wkgrid">
        <div class="wkcorner"></div>
        {#each weekDays as d, i (d)}
          <div class="wkdayh" class:istoday={d === todayStr}>
            <div class="dw">周{WD2[i]}</div>
            <div class="dn">{d.slice(8)}</div>
          </div>
        {/each}
        {#each Array.from({ length: H1 - H0 }, (_, r) => r + H0) as h (h)}
          <div class="wklabel">{String(h).padStart(2, '0')}:00</div>
          {#each weekDays as d (d + h)}
            <div class="wkcell">
              {#each (weekItems.get(d) ?? []).filter((it) => it.hh === h) as it (it.key)}
                <div class="wkcard" class:k-task={it.kind === 'task'} class:k-note={it.kind === 'note'} class:k-jr={it.kind === 'journal'} style="top:{Math.round((ROW * it.mm) / 60) + 2}px">
                  <div class="when">{String(it.hh).padStart(2, '0')}:{String(it.mm).padStart(2, '0')}</div>
                  <div class="t">{it.title}</div>
                </div>
              {/each}
            </div>
          {/each}
        {/each}
        {#if nowLine !== null}
          <div class="nowline" style="top:calc({nowLine}px + var(--wkhead, 46px))"></div>
        {/if}
      </div>
    </div>
  {:else if calView === 'month'}
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
            {#each c.dayTasks.slice(0, Math.max(0, 2 - c.events.length)) as t (t.id)}
              <span class="mtask" title={`任务 · ${t.name}`}>▸ {t.name}</span>
            {/each}
            {#if c.events.length + c.dayTasks.length > 2}
              <span class="mmore">+{c.events.length + c.dayTasks.length - 2}</span>
            {/if}
          {/if}
        </div>
      {/each}
    </div>
    <div class="legend"><span class="lgev">▪ 事件</span><span class="lgtask">▸ 任务(下次触发)</span></div>
  {:else if agendaDays.length === 0}
    <p class="empty">还没有日程 — 加一个事件、导入 .ics,或建一个定时任务。</p>
  {:else}
    {#each agendaDays as g (g.day)}
      <section class="day">
        <h3>{g.day}</h3>
        {#each g.evs as ev (ev.id)}
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
        {#each g.dts as t (t.id)}
          <div class="event taskrow">
            <span class="when">{t.next_run ? localHHMM(t.next_run) : '—'}</span>
            <span class="tmark" aria-hidden="true">▸</span>
            <span class="esum">{t.name}</span>
            <span class="esrc">任务</span>
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
    font: 600 12px/1 var(--sans);
    color: var(--t3);
    margin-bottom: 8px;
  }
  .tools {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .act {
    font: 500 11.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 7px 13px;
    cursor: pointer;
    transition: all .12s var(--ease);
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
    color: #fff;
    background: var(--grad);
    font-weight: 600;
  }
  .act.pri:disabled {
    background: var(--pill);
    color: var(--t4);
    cursor: default;
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
    background: var(--pill); border: 0; border-radius: var(--radius-sm);
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
    background: var(--t1);
    color: var(--onink);
    font-weight: 600;
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
  /* 任务落格:mono ▸ 行,青色左沿与事件(accent)区分 */
  .mtask {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    border-left: 2px solid var(--cyan);
    padding-left: 4px;
  }
  .legend {
    display: flex;
    gap: 14px;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 0.5px;
    color: var(--t4);
    margin-top: 2px;
  }
  .legend .lgev { color: var(--acc-ink); }
  .legend .lgtask { color: var(--cyan); }
  .event.taskrow .esum { color: var(--t3); }
  .tmark {
    font-family: var(--mono);
    color: var(--cyan);
    font-size: 10px;
  }
  .mmore {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
  }

  /* ── 周视图(NOMI:虚线格+浮卡+时刻线)── */
  .wk { margin-top: 8px; }
  .wknav {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 8px;
  }
  .nbtn {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: var(--pill);
    border: 0;
    color: var(--t3);
    cursor: pointer;
    font-size: 13px;
  }
  .nbtn:hover { color: var(--t1); }
  .wkrng {
    font: 700 13px/1 var(--sans);
    color: var(--t1);
  }
  .todaybtn {
    font: 500 11px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    cursor: pointer;
  }
  .todaybtn:hover { color: var(--t1); }
  .tz {
    margin-left: auto;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .wkgrid {
    position: relative;
    display: grid;
    grid-template-columns: 52px repeat(7, 1fr);
    max-height: 560px;
    overflow-y: auto;
  }
  .wkcorner { position: sticky; top: 0; z-index: 6; background: var(--bg); }
  .wkdayh {
    position: sticky;
    top: 0;
    z-index: 6;
    background: var(--bg);
    text-align: center;
    padding: 6px 4px 10px;
  }
  .wkdayh .dw { font: 400 11px/1.3 var(--sans); color: var(--t4); }
  .wkdayh .dn { font: 400 14px/1.3 var(--sans); color: var(--t3); font-variant-numeric: tabular-nums; }
  .wkdayh.istoday .dw, .wkdayh.istoday .dn { color: var(--t1); font-weight: 700; }
  .wklabel {
    height: 44px;
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
    text-align: right;
    padding-right: 8px;
    transform: translateY(-6px);
    font-variant-numeric: tabular-nums;
  }
  .wkcell {
    height: 44px;
    border-left: 1px dashed color-mix(in srgb, var(--t4) 28%, transparent);
    position: relative;
  }
  .wkcard {
    position: absolute;
    left: 4px;
    right: 4px;
    z-index: 3;
    background: var(--card);
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow);
    padding: 6px 9px;
    overflow: hidden;
    border-left: 3px solid var(--g2);
  }
  .wkcard.k-task { border-left-color: var(--green); }
  .wkcard.k-note { border-left-color: var(--blue); }
  .wkcard.k-jr { border-left-color: #c9a227; }
  .wkcard .when { font: 400 10px/1 var(--sans); color: var(--t4); }
  .wkcard .t {
    font: 600 11.5px/1.3 var(--sans);
    color: var(--t1);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    margin-top: 2px;
  }
  .nowline {
    position: absolute;
    left: 52px;
    right: 0;
    border-top: 1.5px solid var(--g1);
    z-index: 5;
  }
  .nowline::before {
    content: '';
    position: absolute;
    left: -4px;
    top: -4px;
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--g1);
  }
</style>
