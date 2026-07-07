<script lang="ts">
  import { layout } from '../layout.svelte'
  import { onMount } from 'svelte'
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { notes, type Note } from './notesStore.svelte'
  import { tasks } from './tasksStore.svelte'
  import { calendar } from '../mail/calendarStore.svelte'
  import { localHHMM, localDate, localDateTime } from '../time'
  import { ConfirmGate } from '../confirm.svelte'
  import Calendar from './Calendar.svelte'
  import CanvasView from './CanvasView.svelte'
  import NoteDetail from './NoteDetail.svelte'
  import PageDetail from './PageDetail.svelte'

  // 三视图(阶段 4 R08,source: helm-journal-pro.html 记录板块)+kind 过滤。
  let view = $state<'timeline' | 'canvas' | 'calendar'>('timeline')
  // filter 共享自 layout(侧栏分类与页内 chips 同源)
  const filterOf = () => layout.journalFilter


  // 深链兼容:旧四 tab 意图 → 三视图+过滤
  $effect(() => {
    if (layout.journalIntent) {
      const i = layout.journalIntent as string
      if (i === 'calendar') view = 'calendar'
      else {
        view = 'timeline'
        layout.journalFilter = i === 'tasks' ? 'task' : i === 'journal' ? 'journal' : 'all'
      }
      layout.journalIntent = null
    }
  })
  let draft = $state('')
  let taskPrompt = $state('')
  let taskKind = $state<'cron' | 'every' | 'at'>('cron')
  let taskCron = $state('0 9 * * *')
  let taskEvery = $state('3600')
  let taskAt = $state('')
  const del = new ConfirmGate()
  // note→task flow: →任务 jumps here with the note pinned; submit uses
  // /to-task so linked_note_id survives (server takes the note's content).
  // The prompt shown is derived — cancelling the pin restores the typed draft.
  let fromNote = $state<Note | null>(null)
  // 行内编辑:editingId + 草稿
  let editingId = $state<number | null>(null)
  let detailNote = $state<Note | null>(null)
  let detailDay = $state<string | null>(null)
  // K6 待办勾选:乐观划线,800ms 后删除(完成即清)
  let doneIds = $state<Set<number>>(new Set())
  function completeTodo(n: Note) {
    doneIds = new Set([...doneIds, n.id])
    setTimeout(() => void notes.remove(n.id), 800)
  }
  let editDraft = $state('')
  const promptValue = $derived(fromNote ? fromNote.content : taskPrompt)

  onMount(() => {
    // 头部计数要 notes+tasks;providers/日历按 tab 懒加载(见 $effect)。
    void notes.load()
    void tasks.load()
  })

  let providersLoaded = false
  let calendarLoaded = false
  $effect(() => {
    if (layout.journalFilter === 'journal' && !providersLoaded) {
      providersLoaded = true
      void notes.loadProviders()
    }
    if (view === 'calendar' && !calendarLoaded) {
      calendarLoaded = true
      void calendar.load()
      void calendar.loadCaldav()
    }
  })

  function today(): string {
    return new Date().toISOString().slice(0, 10)
  }

  // 三模式调度值(cron 表达式=本地墙钟;at 的本地时间转 UTC ISO)
  function scheduleValue(): Record<string, unknown> | null {
    if (taskKind === 'cron') return taskCron.trim() ? { expr: taskCron.trim() } : null
    if (taskKind === 'every') {
      const n = Number(taskEvery)
      return Number.isFinite(n) && n > 0 ? { seconds: n } : null
    }
    return taskAt ? { at: new Date(taskAt).toISOString() } : null
  }

  async function addTask() {
    const value = scheduleValue()
    if (!value) return
    if (fromNote) {
      const pinned = fromNote
      const ok = await notes.toTask(pinned.id, taskKind, value)
      if (ok) {
        fromNote = null
        await tasks.load()
      } else if (!notes.notes.some((n) => n.id === pinned.id)) {
        notes.error = '速记已被删除,已取消关联'
        fromNote = null
      }
      return
    }
    if (!taskPrompt.trim()) return
    const ok = await tasks.create('', taskPrompt, taskKind, value)
    if (ok) taskPrompt = ''
  }

  // 已转任务标记:tasks 里 linked_note_id 指向的速记
  const linkedNoteIds = $derived(new Set(tasks.tasks.map((t) => t.linked_note_id).filter((x): x is number => x != null)))

  function cmdEnter(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault()
      void add()
    }
  }

  function startEdit(n: Note) {
    editingId = n.id
    editDraft = n.content
  }

  async function saveEdit() {
    if (editingId == null) return
    if (await notes.update(editingId, editDraft)) {
      editingId = null
      editDraft = ''
    }
  }

  function noteToTask(n: Note) {
    fromNote = n
    view = 'timeline'
    layout.journalFilter = 'task'
  }

  // One load, three derived views (kind split) — captures/journal/todos share the table.
  const noteItems = $derived(
    notes.notes.filter((n) => {
      if (n.kind !== 'note') return false
      const f = layout.journalFilter
      if (f === 'collect') return !!n.meta?.url
      if (f === 'youtube' || f === 'paper' || f === 'inspiration') return n.meta?.type === f
      return true
    }),
  )
  const journalItems = $derived(notes.notes.filter((n) => n.kind === 'journal' || n.kind === 'focus'))
  // 「给自己」的任务(notch/捕获坞分流后落 notes kind:task)——任务 tab 顶部待办段。
  const todoItems = $derived(notes.notes.filter((n) => n.kind === 'task'))

  // 速记按天分组(最新日在前;今天/昨天友好标)——2026-07-06 用户:页面要结构化。
  const notesByDate = $derived(
    (() => {
      const groups = new Map<string, Note[]>()
      for (const n of noteItems) {
        const d = n.created_at ? localDate(n.created_at) : '未知时间'
        ;(groups.get(d) ?? groups.set(d, []).get(d)!).push(n)
      }
      return [...groups.entries()].sort((a, b) => b[0].localeCompare(a[0]))
    })(),
  )
  function dayLabel(d: string): string {
    const t = new Date()
    const pad = (n: number) => String(n).padStart(2, '0')
    const todayK = `${t.getFullYear()}-${pad(t.getMonth() + 1)}-${pad(t.getDate())}`
    const y = new Date(t.getTime() - 86400000)
    const yestK = `${y.getFullYear()}-${pad(y.getMonth() + 1)}-${pad(y.getDate())}`
    return d === todayK ? `今天 · ${d.slice(5)}` : d === yestK ? `昨天 · ${d.slice(5)}` : d
  }

  // Group journal entries by date (newest day first).
  const journalByDate = $derived(
    (() => {
      const groups = new Map<string, Note[]>()
      for (const n of journalItems) {
        const d = n.journal_date ?? '未注明日期'
        ;(groups.get(d) ?? groups.set(d, []).get(d)!).push(n)
      }
      return [...groups.entries()].sort((a, b) => b[0].localeCompare(a[0]))
    })(),
  )

  function renderMd(src: string): string {
    return DOMPurify.sanitize(marked.parse(src ?? '', { async: false }) as string)
  }

  const pad3 = (n: number) => String(n).padStart(3, '0')

  // K4 日记纸页:今日字数 + 连续天数(与 Today 同口径)
  const jToday = $derived(journalItems.filter((n) => n.journal_date === today()))
  const jTodayChars = $derived(jToday.reduce((a, e) => a + e.content.length, 0))
  const jStreak = $derived.by(() => {
    const dates = new Set(journalItems.filter((n) => n.journal_date).map((n) => n.journal_date as string))
    let count = 0
    const d = new Date()
    const p2 = (x: number) => String(x).padStart(2, '0')
    if (!dates.has(today())) d.setDate(d.getDate() - 1)
    for (;;) {
      const k = `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`
      if (!dates.has(k)) break
      count += 1
      d.setDate(d.getDate() - 1)
    }
    return count
  })
  function notesOfDay(day: string): Note[] {
    return notes.notes.filter((n) => n.kind !== 'journal' && (n.created_at ?? '').slice(0, 10) === day)
  }
  const WD_ZH = ['日', '一', '二', '三', '四', '五', '六']
  function weekdayOf(day: string): string {
    const d = new Date(day + 'T00:00:00')
    return Number.isNaN(d.getTime()) ? '' : `周${WD_ZH[d.getDay()]}`
  }
  function dayNum(day: string): string {
    const m = day.match(/(\d{4})-(\d{2})-(\d{2})/)
    return m ? `${Number(m[2])}月${Number(m[3])}日` : day
  }

  async function add() {
    if (!draft.trim()) return
    const ok =
      layout.journalFilter === 'journal'
        ? await notes.create(draft, 'journal', today())
        : await notes.create(draft, 'note')
    if (ok) draft = ''
  }
</script>

<section class="jnt" aria-label="日记 / 速记">
  <header class="head">
    <h1>记录</h1>
    <span class="hd">速记 · 日记 · 任务 · 日历</span>
    <span class="pg">{pad3(noteItems.length)} NOTES · {pad3(journalItems.length)} ENTRIES · {pad3(tasks.tasks.length)} TASKS</span>
  </header>

  <div class="viewrow">
    <div class="seg" aria-label="视图">
      <button class:active={view === 'timeline'} onclick={() => (view = 'timeline')}>Timeline</button>
      <button class:active={view === 'canvas'} onclick={() => (view = 'canvas')}>Canvas</button>
      <button class:active={view === 'calendar'} onclick={() => (view = 'calendar')}>Calendar</button>
    </div>
    {#if view !== 'calendar'}
      <div class="chips2" role="tablist" aria-label="分类">
        <button role="tab" aria-selected={layout.journalFilter === 'all'} class:on={layout.journalFilter === 'all'} onclick={() => (layout.journalFilter = 'all')}>全部</button>
        <button role="tab" aria-selected={layout.journalFilter === 'note'} class:on={layout.journalFilter === 'note'} onclick={() => (layout.journalFilter = 'note')}>速记</button>
        <button role="tab" aria-selected={layout.journalFilter === 'journal'} class:on={layout.journalFilter === 'journal'} onclick={() => (layout.journalFilter = 'journal')}>日记</button>
        <button role="tab" aria-selected={layout.journalFilter === 'task'} class:on={layout.journalFilter === 'task'} onclick={() => (layout.journalFilter = 'task')}>任务</button>
      </div>
    {/if}
  </div>

  {#if notes.error}<p class="err" role="alert">{notes.error}</p>{/if}

  {#if view === 'timeline' && layout.journalFilter !== 'task' && layout.journalFilter !== 'journal'}
    <div class="row">
      <div class="gut"><span class="tm">随手</span></div>
      <form
        class="compose"
        onsubmit={(e) => {
          e.preventDefault()
          void add()
        }}
      >
        <span class="car" aria-hidden="true"></span>
        <textarea
          placeholder="随手记一笔…"
          bind:value={draft}
          aria-label="速记内容"
          rows={1}
          onkeydown={cmdEnter}
        ></textarea>
        <button class="act pri" type="submit" disabled={!draft.trim()}>记一笔</button>
      </form>
    </div>
  {/if}

  {#if view === 'timeline'}
  {#if ['all', 'note', 'collect', 'youtube', 'paper', 'inspiration'].includes(layout.journalFilter)}
    <div class="row">
      <div class="gut"><span class="tm">收集</span><br />{noteItems.length} 条</div>
      <div>
        <div class="h">速记 / SCRATCH</div>
        {#if noteItems.length === 0}
          <p class="empty">还没有速记 — 上面记一笔,或用 ⌘N 随手记。</p>
        {:else}
          {#each notesByDate as [d, items] (d)}
          <div class="dstamp">{dayLabel(d)}<span class="dn">{items.length} 条</span></div>
          <!-- K1 瀑布卡墙(稿:helm-journal-kinds.html 速记态):便签/收藏卡混排 -->
          <div class="wall">
            {#each items as n (n.id)}
              <article class="wcard" class:plain={!n.meta?.url}>
                {#if editingId === n.id}
                  <div class="wpad">
                    <textarea class="editbox" bind:value={editDraft} aria-label="编辑内容" rows="3"></textarea>
                    <span class="wacts show">
                      <button class="act pri" onclick={saveEdit} disabled={!editDraft.trim()}>保存</button>
                      <button class="act" onclick={() => (editingId = null)}>取消</button>
                    </span>
                  </div>
                {:else}
                  {#if n.meta?.url && n.meta.image}
                    <img class="wcover" src={n.meta.image} alt="" loading="lazy" onerror={(e) => ((e.currentTarget as HTMLImageElement).style.display = 'none')} />
                  {/if}
                  <div class="wpad">
                    {#if n.meta?.url}
                      <span class="wbadge" style="background:{({ youtube: '#ff2d2d', paper: '#8b5a2b', inspiration: '#0a84ff' } as Record<string, string>)[n.meta.type ?? ''] ?? '#0a84ff'}">
                        {({ youtube: 'YT', paper: 'AX', inspiration: 'AW' } as Record<string, string>)[n.meta.type ?? ''] ?? 'WEB'}
                      </span>
                      <button class="wti openable" title="查看详情" onclick={() => (detailNote = n)}>{n.meta.title ?? n.meta.url}</button>
                      {#if n.meta.summary}<p class="wsum">{n.meta.summary}</p>{/if}
                    {:else}
                      <span class="wbadge" style="background:var(--t1);color:var(--onink)">N</span>
                      <button class="wtx openable" title="查看详情" onclick={() => (detailNote = n)}>{n.content}</button>
                    {/if}
                    <div class="wfoot">
                      {#if n.meta?.site}<span>{n.meta.site}</span>{/if}
                      {#each n.meta?.tags ?? [] as t (t)}<span class="wtag">#{t}</span>{/each}
                      {#if linkedNoteIds.has(n.id)}<span class="linked">已转任务</span>{/if}
                      <span class="wtm">{localHHMM(n.created_at)}</span>
                    </div>
                    <span class="wacts">
                      <button class="act" title="编辑" aria-label={`编辑 ${n.content}`} onclick={() => startEdit(n)}>编辑</button>
                      <button class="act" title="转为今天的日记" onclick={() => notes.toJournal(n.id)}>→日记</button>
                      <button class="act" title="存入记忆" onclick={() => notes.toMemory(n.id)}>→记忆</button>
                      <button class="act" title="转为定时任务" onclick={() => noteToTask(n)}>→任务</button>
                      <button
                        class="act del"
                        class:armed={del.pending === `note-${n.id}`}
                        aria-label={`删除 ${n.content}`}
                        onclick={() => del.confirm(`note-${n.id}`) && notes.remove(n.id)}
                      >{del.pending === `note-${n.id}` ? '确认' : '×'}</button>
                    </span>
                  </div>
                {/if}
              </article>
            {/each}
          </div>
          {/each}
        {/if}
      </div>
    </div>
  {:else if layout.journalFilter === 'journal'}
    <!-- K4 日记纸页(稿:helm-journal-kinds.html 日记态):窄栏/今天的页/一天一页 -->
    <div class="paper">
      <div class="streakbar">
        <span class="s"><span class="big">{jTodayChars}</span><span class="u">字 · 今天</span></span>
        <span class="s"><span class="big">{jStreak}</span><span class="u">天连续</span></span>
        <button class="aibtn2" onclick={() => notes.summarizeToday(today())} disabled={notes.summarizing}>
          <span class="spark2" aria-hidden="true"></span>{notes.summarizing ? '生成中…' : 'AI 今日小结'}
        </button>
        <button class="aibtn2" onclick={() => notes.summarizeToday(today(), 7)} disabled={notes.summarizing}>周回顾</button>
      </div>
      {#if notes.summary}
        <div class="sumcard"><span class="spark2" aria-hidden="true"></span><p>{notes.summary}</p></div>
      {/if}
      <div class="todaypage">
        <div class="dh"><span class="d">{dayNum(today())}</span><span class="w">{weekdayOf(today())} · 今天的页</span></div>
        <textarea
          placeholder="今天发生了什么?(支持 Markdown,⌘⏎ 写入)"
          bind:value={draft}
          onkeydown={cmdEnter}
          aria-label="日记内容"
        ></textarea>
        <div class="actrow"><span class="hint2">⌘⏎ 写入今天 · Markdown</span>
          <button class="act pri" onclick={() => void add()} disabled={!draft.trim()}>写入今天</button></div>
      </div>
      {#if journalByDate.length === 0}
        <p class="empty">还没有日记 — 上面写下今天的第一条。</p>
      {:else}
        {#each journalByDate as [day, entries] (day)}
          <section class="jpage">
            <button class="dh openbtn" title="查看这一天" onclick={() => (detailDay = day)}>
              <span class="d">{dayNum(day)}</span><span class="w">{weekdayOf(day)}</span>
              <span class="cnt">{entries.reduce((a, e) => a + e.content.length, 0)} 字</span></button>
            {#each entries as e (e.id)}
              {#if editingId === e.id}
                <textarea class="editbox" bind:value={editDraft} aria-label="编辑日记" rows="4"></textarea>
                <span class="acts"><button class="act pri" onclick={saveEdit} disabled={!editDraft.trim()}>保存</button>
                  <button class="act" onclick={() => (editingId = null)}>取消</button></span>
              {:else}
                <div class="md">{@html renderMd(e.content)}</div>
                <span class="pacts">
                  <button class="act" aria-label="编辑日记" onclick={() => startEdit(e)}>编辑</button>
                  <button class="act del" class:armed={del.pending === `jr-${e.id}`} aria-label="删除日记"
                    onclick={() => del.confirm(`jr-${e.id}`) && notes.remove(e.id)}>{del.pending === `jr-${e.id}` ? '确认' : '×'}</button>
                </span>
              {/if}
            {/each}
          </section>
        {/each}
      {/if}
    </div>
  {:else if layout.journalFilter === 'task'}
    <!-- K6 任务操作台(稿:helm-journal-kinds.html 任务态):派发条 + 待办清单 + 定时卡 -->
    <form
      class="dispatch"
      onsubmit={(e) => {
        e.preventDefault()
        void addTask()
      }}
    >
      {#if fromNote}
        <span class="chip">
          自速记 #{fromNote.id}
          <button type="button" class="act del" aria-label="取消关联速记"
            onclick={() => { fromNote = null; taskPrompt = '' }}>×</button>
        </span>
      {/if}
      <input
        placeholder="到点让 agent 做什么(如:汇总未读邮件)…"
        value={promptValue}
        oninput={(e) => { if (!fromNote) taskPrompt = e.currentTarget.value }}
        aria-label="任务指令"
        readonly={fromNote !== null}
      />
      <select class="kind" bind:value={taskKind} aria-label="调度模式">
        <option value="cron">cron</option>
        <option value="every">every</option>
        <option value="at">at</option>
      </select>
      {#if taskKind === 'cron'}
        <input class="cron" placeholder="cron 表达式" bind:value={taskCron} aria-label="cron 表达式" />
      {:else if taskKind === 'every'}
        <input class="cron" type="number" min="1" placeholder="间隔秒" bind:value={taskEvery} aria-label="间隔秒" />
      {:else}
        <input class="cron at" type="datetime-local" bind:value={taskAt} aria-label="触发时间" />
      {/if}
      <button class="act pri" type="submit" disabled={(fromNote ? false : !taskPrompt.trim()) || !scheduleValue()}>加定时</button>
    </form>
    {#if tasks.error}<p class="err" role="alert">{tasks.error}</p>{/if}

    <div class="taskcols">
      <div>
        <div class="colh"><span class="t">待办 · 给自己</span><span class="n">{todoItems.length} 条</span></div>
        {#if todoItems.length === 0}
          <p class="empty">没有待办 — 捕获坞/刘海里选「任务 · 给自己」记一条。</p>
        {:else}
          <div class="todolist">
            {#each todoItems as n (n.id)}
              <div class="todo" class:done={doneIds.has(n.id)}>
                <button class="cb" aria-label={`完成 ${n.content}`} onclick={() => completeTodo(n)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M5 13l4 4 10-10"/></svg>
                </button>
                <button class="tx openable2" title="查看详情" onclick={() => (detailNote = n)}>{n.content}</button>
                <span class="ttm">{localHHMM(n.created_at)}</span>
                <button class="up" title="转为定时任务(交给 agent)" onclick={() => noteToTask(n)}>→交给 agent</button>
              </div>
            {/each}
          </div>
        {/if}
      </div>
      <div>
        <div class="colh"><span class="t">定时 · 交给 agent</span>
          <span class="n">{tasks.tasks.filter((t) => t.enabled).length} 项启用</span></div>
        {#if tasks.tasks.length === 0}
          <p class="empty">还没有定时任务 — 上面派发一个,到点自动触发 agent。</p>
        {:else}
          <div class="sched">
            {#each tasks.tasks as t (t.id)}
              <div class="scard" class:open={tasks.runsFor === t.id}>
                <div class="sh">
                  <span class="nm" class:off={!t.enabled}>{t.name}</span>
                  <button class="sw" class:on={t.enabled} role="switch" aria-checked={t.enabled}
                    aria-label={`启用 ${t.name}`} onclick={() => tasks.toggle(t)}></button>
                </div>
                <div class="smeta">
                  <span class="cronchip">{t.schedule_kind}</span>
                  <span class="nextchip">{t.enabled ? `下次 ${localDateTime(t.next_run)}` : '已停用'}</span>
                  <button class="runbtn" aria-label={`运行记录 ${t.name}`} aria-expanded={tasks.runsFor === t.id}
                    onclick={() => tasks.toggleRuns(t.id)}>{t.run_count} 次{#if t.last_status}&nbsp;· {t.last_status}{/if} ▾</button>
                  <button class="act del sdel" class:armed={del.pending === `task-${t.id}`} aria-label={`删除 ${t.name}`}
                    onclick={() => del.confirm(`task-${t.id}`) && tasks.remove(t.id)}>{del.pending === `task-${t.id}` ? '确认' : '×'}</button>
                </div>
                {#if tasks.runsFor === t.id}
                  <div class="rundrawer">
                    {#if tasks.runsLoading}
                      <p class="empty">读取运行记录…</p>
                    {:else if tasks.runs.length === 0}
                      <p class="empty">还没有运行记录 — 到点触发后结果会记在这里。</p>
                    {:else}
                      {#each tasks.runs as r (r.id)}
                        <div class="runrow">
                          <span class="rdot" class:ok={r.status === 'ok'} class:err={r.status === 'error'} aria-hidden="true"></span>
                          <span class="rtime">{localDateTime(r.started_at)}</span>
                          <span class="rstatus">{r.status}</span>
                          <span class="rout" title={r.output ?? ''}>{r.output ?? ''}</span>
                        </div>
                      {/each}
                    {/if}
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  {/if}
  {:else if view === 'canvas'}
    <CanvasView notes={notes.notes.filter((n) => n.kind !== 'journal')} />
  {:else}
    <!-- TODO(F7 日历轮): Calendar.svelte 仍旧样式,周视图轮重设计 -->
    <div class="calwrap">
      <Calendar />
    </div>
  {/if}

  {#if detailDay}
    {@const dayEntries = journalByDate.find(([d]) => d === detailDay)?.[1] ?? []}
    <PageDetail
      day={detailDay}
      entries={dayEntries}
      dayNotes={notesOfDay(detailDay)}
      {renderMd}
      onclose={() => (detailDay = null)}
      onedit={(n) => startEdit(n)}
    />
  {/if}

  {#if detailNote}
    <NoteDetail
      note={detailNote}
      onclose={() => (detailNote = null)}
      onedit={(n) => startEdit(n)}
      totask={(n) => noteToTask(n)}
    />
  {/if}
</section>

<style>
  .jnt {
    height: 100%;
    overflow: auto;
    padding: 18px 24px 24px 22px; /* 左侧留白:用户反馈字贴边(07-03);07-06 再提一档 */
    font-family: var(--sans);
    color: var(--t2);
    max-width: 1180px; /* 墙态放宽;纸页态(日记)组件内自限窄栏 */
  }
  .calwrap {
    padding-left: var(--gutter-w);
  }
  .head {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding-left: var(--gutter-w);
    margin-bottom: 6px;
  }
  .head h1 {
    font: 800 22px/1.2 var(--sans);
    letter-spacing: -0.2px;
    color: var(--t1);
    margin: 0;
  }
  .head .hd {
    font: 400 13px/1 var(--sans);
    color: var(--t4);
  }
  .head .pg {
    margin-left: auto;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  /* 分段 = mono 大写 tag + accent 底线(无胶囊无圆角) */
  .viewrow {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }
  .chips2 {
    display: flex;
    gap: 5px;
  }
  .chips2 button {
    font: 500 11.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    cursor: pointer;
  }
  .chips2 button.on {
    background: var(--t1);
    color: var(--onink);
    font-weight: 600;
  }
  .seg {
    display: inline-flex;
    gap: 4px;
    background: var(--card);
    border-radius: var(--radius-pill);
    padding: 4px;
    box-shadow: var(--shadow);
    margin: 4px 0 12px;
  }
  .seg button {
    font: 500 13px/1 var(--sans);
    color: var(--t3);
    background: transparent;
    border: 0;
    border-radius: var(--radius-pill);
    padding: 8px 18px;
    cursor: pointer;
    transition: all .18s var(--ease);
  }
  .seg button:hover {
    color: var(--t1);
  }
  .seg button.active {
    background: var(--t1);
    color: var(--onink);
    font-weight: 600;
  }
  /* 账本行:左槽 mono + 发丝分隔(承 Today .rdrow) */
  .row {
    display: grid;
    grid-template-columns: var(--gutter-w) 1fr;
    border-top: none;
    padding: 10px 0;
  }
  .gut {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    line-height: 1.5;
    padding-top: 3px;
    letter-spacing: .3px;
  }
  /* 速记按天界标(今天/昨天/日期 + 条数) */
  .dstamp {
    display: flex;
    align-items: baseline;
    gap: 8px;
    font: 700 13px/1 var(--sans);
    color: var(--t1);
    margin: 16px 0 8px;
  }
  .dstamp:first-of-type { margin-top: 2px; }
  .dstamp .dn { color: var(--t4); font-size: 9px; }

  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 7px;
  }
  /* 输入 = 光标细丝 + 透明输入面,发丝托底 */
  .compose {
    display: flex;
    align-items: flex-start;
    gap: 9px;
  }
  .car {
    display: none;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .compose {
    background: var(--pill);
    border-radius: var(--radius);
    padding: 8px 8px 8px 14px;
    align-items: center;
  }
  .compose textarea,
  .compose textarea::placeholder,
  .compose textarea:focus,
  .chip {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    padding: 2px 6px;
    flex: none;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-top: 2px;
  }
  /* 动作按钮 = mono 小字,主动作 accent 描边 */
  .act {
    font: 500 11px/1 var(--sans);
    color: var(--t4);
    background: transparent;
    border: 0;
    border-radius: var(--radius-pill);
    padding: 4px 8px;
    cursor: pointer;
    transition: all .12s var(--ease);
  }
  .act:hover {
    color: var(--t1);
    background: var(--pill);
  }
  .act.pri {
    color: #fff;
    background: var(--grad);
    padding: 7px 14px;
    flex: none;
    font-weight: 600;
  }
  .act.pri:disabled {
    background: var(--pill);
    color: var(--t4);
    cursor: default;
  }
  .act.del:hover,
  .act.del.armed {
    color: var(--red);
  }
  .editbox {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--acc-ink);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 13px;
    padding: 3px 0 6px;
    resize: vertical;
    min-width: 0;
  }
  .editbox:focus {
    outline: none;
  }
  .linked {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
    border: 1px solid var(--hair);
    padding: 0 4px;
    flex: none;
  }
  /* —— K6 任务操作台 —— */
  .dispatch {
    display: flex;
    gap: 8px;
    background: var(--card);
    border-radius: var(--radius-pill);
    box-shadow: var(--shadow);
    padding: 6px 6px 6px 20px;
    align-items: center;
    margin: 4px 0 20px;
    flex-wrap: wrap;
  }
  .dispatch input:not(.cron):not(.at) {
    flex: 1;
    min-width: 200px;
    border: 0;
    outline: none;
    font: 400 13.5px/1 var(--sans);
    background: transparent;
    color: var(--t1);
  }
  .dispatch input::placeholder { color: var(--t4); }
  .dispatch input.cron {
    width: 130px;
    font: 500 12px/1 var(--mono);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 9px 13px;
    outline: none;
    color: var(--t1);
  }
  .taskcols {
    display: grid;
    grid-template-columns: 1fr 1.25fr;
    gap: 20px;
    align-items: start;
  }
  @media (max-width: 980px) {
    .taskcols { grid-template-columns: 1fr; }
  }
  .colh {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin: 0 4px 10px;
  }
  .colh .t {
    font: 700 13.5px/1 var(--sans);
    color: var(--t1);
  }
  .colh .n {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .todolist {
    background: var(--card);
    border-radius: 18px;
    box-shadow: var(--shadow);
    padding: 6px 8px;
  }
  .todo {
    display: flex;
    align-items: center;
    gap: 11px;
    padding: 11px 10px;
    border-radius: var(--radius-sm);
  }
  .todo:hover { background: var(--pill); }
  .cb {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    border: 1.6px solid var(--t4);
    background: transparent;
    flex: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: transparent;
    transition: all 0.15s var(--ease);
  }
  .todo.done .cb {
    background: var(--grad);
    border-color: transparent;
    color: #fff;
  }
  .cb :global(svg) {
    width: 11px;
    height: 11px;
  }
  .todo .tx {
    flex: 1;
    min-width: 0;
    font: 400 13.5px/1.45 var(--sans);
    color: var(--t1);
    background: none;
    border: 0;
    padding: 0;
    text-align: left;
    cursor: pointer;
  }
  .todo.done .tx {
    color: var(--t4);
    text-decoration: line-through;
  }
  .todo .ttm {
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
    flex: none;
  }
  .todo .up {
    font: 500 10.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 5px 10px;
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.12s;
    flex: none;
  }
  .todo:hover .up { opacity: 1; }
  .todo .up:hover { color: var(--t1); }
  .sched {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .scard {
    background: var(--card);
    border-radius: 18px;
    box-shadow: var(--shadow);
    padding: 14px 16px;
  }
  .sh {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .scard .nm {
    font: 600 13.5px/1.3 var(--sans);
    color: var(--t1);
    flex: 1;
    min-width: 0;
  }
  .scard .nm.off { color: var(--t4); }
  .sw {
    width: 40px;
    height: 24px;
    border-radius: 99px;
    background: var(--pill);
    border: 0;
    position: relative;
    cursor: pointer;
    flex: none;
    transition: background 0.18s var(--ease);
  }
  .sw::after {
    content: '';
    position: absolute;
    top: 3px;
    left: 3px;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--card);
    box-shadow: var(--shadow);
    transition: left 0.18s var(--ease);
  }
  .sw.on { background: var(--grad); }
  .sw.on::after { left: 19px; }
  .smeta {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-top: 9px;
    flex-wrap: wrap;
  }
  .cronchip {
    font: 600 10px/1 var(--mono);
    color: var(--t3);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 5px 10px;
  }
  .nextchip {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .runbtn {
    margin-left: auto;
    font: 500 10.5px/1 var(--sans);
    color: var(--t4);
    background: transparent;
    border: 0;
    cursor: pointer;
  }
  .runbtn:hover { color: var(--t1); }
  .sdel { flex: none; }

  /* —— K4 日记纸页 —— */
  .paper {
    max-width: 640px;
    margin: 6px auto 0;
  }
  .streakbar {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 14px;
  }
  .streakbar .s {
    display: flex;
    align-items: baseline;
    gap: 5px;
  }
  .streakbar .big {
    font: 800 24px/1 var(--sans);
    color: var(--t1);
  }
  .streakbar .u {
    font: 400 11.5px/1 var(--sans);
    color: var(--t4);
  }
  .aibtn2 {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    background: var(--card);
    border: 1px solid var(--hair);
    border-radius: var(--radius-pill);
    padding: 8px 15px;
    font: 500 12px/1 var(--sans);
    color: var(--t3);
    cursor: pointer;
  }
  .aibtn2:first-of-type {
    margin-left: auto;
  }
  .aibtn2:hover:not(:disabled) {
    color: var(--t1);
  }
  .spark2 {
    width: 13px;
    height: 13px;
    border-radius: 50%;
    flex: none;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .sumcard {
    display: flex;
    gap: 9px;
    background: var(--card);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 13px 16px;
    margin-bottom: 14px;
    font: 400 13px/1.65 var(--sans);
    color: var(--t2);
  }
  .sumcard p { margin: 0; }
  .todaypage {
    background: var(--card);
    border-radius: 20px;
    box-shadow: var(--shadow);
    padding: 22px 26px;
    margin-bottom: 26px;
  }
  .todaypage .dh,
  .jpage .dh {
    display: flex;
    align-items: baseline;
    gap: 10px;
    margin-bottom: 12px;
  }
  .todaypage .d {
    font: 800 19px/1 var(--sans);
    color: var(--t1);
  }
  .jpage .d {
    font: 800 15.5px/1 var(--sans);
    color: var(--t1);
  }
  .todaypage .w,
  .jpage .w {
    font: 400 12px/1 var(--sans);
    color: var(--t4);
  }
  .jpage .cnt {
    margin-left: auto;
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
  }
  .todaypage textarea {
    width: 100%;
    min-height: 120px;
    border: 0;
    outline: none;
    resize: vertical;
    font: 400 14.5px/1.75 var(--sans);
    color: var(--t1);
    background: transparent;
  }
  .todaypage textarea::placeholder {
    color: var(--t4);
  }
  .actrow {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 10px;
  }
  .hint2 {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .actrow .act.pri {
    margin-left: auto;
  }
  .jpage {
    position: relative;
    background: var(--card);
    border-radius: 20px;
    box-shadow: var(--shadow);
    padding: 20px 26px;
    margin-bottom: 18px;
  }
  .dh.openbtn {
    width: 100%;
    background: none;
    border: 0;
    padding: 0;
    cursor: pointer;
    text-align: left;
  }
  .dh.openbtn:hover .d {
    color: var(--t3);
  }
  .jpage .md {
    font: 400 14px/1.75 var(--sans);
    color: var(--t2);
  }
  .pacts {
    display: flex;
    gap: 4px;
    margin-top: 10px;
    opacity: 0;
    transition: opacity var(--dur-micro) var(--ease);
  }
  .jpage:hover .pacts {
    opacity: 1;
  }

  /* —— K1 瀑布卡墙 —— */
  .wall {
    columns: 3 250px;
    column-gap: 14px;
    margin-bottom: 6px;
  }
  .wcard {
    break-inside: avoid;
    background: var(--card);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    margin: 0 0 14px;
    overflow: hidden;
    transition: box-shadow var(--dur-micro) var(--ease);
    position: relative;
  }
  .wcard:hover {
    box-shadow: var(--shadow-lg);
  }
  .wcover {
    width: 100%;
    display: block;
    aspect-ratio: 16 / 9;
    object-fit: cover;
    background: var(--pill);
  }
  .wpad {
    padding: 12px 14px;
  }
  .wbadge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 24px;
    height: 24px;
    padding: 0 5px;
    border-radius: 7px;
    color: #fff;
    font: 800 9.5px/1 var(--sans);
    margin-bottom: 8px;
  }
  .wti,
  .wtx {
    display: block;
    width: 100%;
    background: none;
    border: 0;
    padding: 0;
    text-align: left;
    cursor: pointer;
    color: var(--t1);
  }
  .wti {
    font: 600 13.5px/1.35 var(--sans);
  }
  .wtx {
    font: 500 13.5px/1.6 var(--sans);
    white-space: pre-wrap;
    word-break: break-word;
  }
  .wti:hover,
  .wtx:hover {
    color: var(--t3);
  }
  .wsum {
    font: 400 12px/1.55 var(--sans);
    color: var(--t3);
    margin: 5px 0 0;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .wfoot {
    display: flex;
    flex-wrap: wrap;
    gap: 7px;
    align-items: center;
    margin-top: 9px;
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
  }
  .wtag {
    color: var(--cyan);
  }
  .wtm {
    margin-left: auto;
  }
  .wacts {
    display: flex;
    gap: 2px;
    margin-top: 8px;
    opacity: 0;
    transition: opacity var(--dur-micro) var(--ease);
  }
  .wcard:hover .wacts,
  .wacts.show {
    opacity: 1;
  }

  /* —— AI 收藏卡(链接 parse 结果) —— */
  .acts {
    display: flex;
    align-items: center;
    gap: 6px;
    flex: none;
  }
  /* 日记:日期 = accent 账本界标 */
  .md {
    flex: 1;
    line-height: 1.55;
    color: var(--t2);
    font-size: 13px;
  }
  .md :global(p) {
    margin: .3em 0;
  }
  .md :global(h1),
  .md :global(h2),
  .md :global(h3) {
    font-size: 13px;
    margin: .4em 0 .2em;
    color: var(--t1);
  }
  .md :global(code) {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--t1);
    background: var(--tile);
    padding: 0 4px;
  }
  .md :global(a) {
    color: var(--acc-ink);
  }
  /* 任务行 */
  /* 运行历史抽屉:mono 子账本行 */
  .rundrawer {
    margin: 0 0 6px 23px;
    padding-left: 10px;
    border-left: 1px solid var(--hair);
  }
  .runrow {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 2px 0;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    font-variant-numeric: tabular-nums;
  }
  .rdot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: var(--t4);
    flex: none;
  }
  .rdot.ok {
    background: var(--green);
  }
  .rdot.err {
    background: var(--red);
  }
  .rout {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--t4);
  }
  .err {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
    margin: 4px 0 0 var(--gutter-w);
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
    margin: 2px 0;
  }
</style>
