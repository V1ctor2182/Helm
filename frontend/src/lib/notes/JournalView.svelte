<script lang="ts">
  import { onMount } from 'svelte'
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { notes, type Note } from './notesStore.svelte'
  import { tasks } from './tasksStore.svelte'
  import { calendar } from '../mail/calendarStore.svelte'
  import Calendar from './Calendar.svelte'

  let view = $state<'notes' | 'journal' | 'tasks' | 'calendar'>('notes')
  let draft = $state('')
  let taskPrompt = $state('')
  let taskCron = $state('0 9 * * *')
  // note→task flow: →任务 jumps here with the note pinned; submit uses
  // /to-task so linked_note_id survives (server takes the note's content).
  // The prompt shown is derived — cancelling the pin restores the typed draft.
  let fromNote = $state<Note | null>(null)
  const promptValue = $derived(fromNote ? fromNote.content : taskPrompt)

  onMount(() => {
    // 头部计数要 notes+tasks;providers/日历按 tab 懒加载(见 $effect)。
    void notes.load()
    void tasks.load()
  })

  let providersLoaded = false
  let calendarLoaded = false
  $effect(() => {
    if (view === 'journal' && !providersLoaded) {
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

  async function addTask() {
    if (fromNote) {
      const pinned = fromNote
      const ok = await notes.toTask(pinned.id, 'cron', { expr: taskCron })
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
    const ok = await tasks.create('', taskPrompt, 'cron', { expr: taskCron })
    if (ok) taskPrompt = ''
  }

  function noteToTask(n: Note) {
    fromNote = n
    view = 'tasks'
  }

  // One load, two derived views (kind split) — captures and journal share the table.
  const noteItems = $derived(notes.notes.filter((n) => n.kind === 'note'))
  const journalItems = $derived(notes.notes.filter((n) => n.kind === 'journal'))

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

  // 后端时间戳是 UTC(created_at 无时区标记、next_run 带 +00:00);
  // 显示一律转本地钟。裸 ISO 补 Z 再解析,避免被当本地时间。
  function toLocal(iso: string): Date {
    return new Date(/(Z|[+-]\d{2}:?\d{2})$/.test(iso) ? iso : iso + 'Z')
  }
  const pad2 = (n: number) => String(n).padStart(2, '0')
  function hhmm(iso: string | null): string {
    if (!iso) return ''
    const d = toLocal(iso)
    return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`
  }
  function nextRunLabel(iso: string | null): string {
    if (!iso) return '—'
    const d = toLocal(iso)
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`
  }

  const pad3 = (n: number) => String(n).padStart(3, '0')

  async function add() {
    if (!draft.trim()) return
    const ok =
      view === 'notes'
        ? await notes.create(draft, 'note')
        : await notes.create(draft, 'journal', today())
    if (ok) draft = ''
  }
</script>

<section class="jnt" aria-label="日记 / 速记">
  <header class="head">
    <h1>JOURNAL</h1>
    <span class="hd">记录</span>
    <span class="pg">{pad3(noteItems.length)} NOTES · {pad3(journalItems.length)} ENTRIES · {pad3(tasks.tasks.length)} TASKS</span>
  </header>

  <div class="seg" role="tablist" aria-label="速记 / 日记">
    <button role="tab" aria-selected={view === 'notes'} class:active={view === 'notes'} onclick={() => (view = 'notes')}>速记</button>
    <button role="tab" aria-selected={view === 'journal'} class:active={view === 'journal'} onclick={() => (view = 'journal')}>日记</button>
    <button role="tab" aria-selected={view === 'tasks'} class:active={view === 'tasks'} onclick={() => (view = 'tasks')}>任务</button>
    <button role="tab" aria-selected={view === 'calendar'} class:active={view === 'calendar'} onclick={() => (view = 'calendar')}>日历</button>
  </div>

  {#if notes.error}<p class="err" role="alert">{notes.error}</p>{/if}

  {#if view === 'notes' || view === 'journal'}
    <div class="row">
      <div class="gut"><span class="tm">{view === 'notes' ? '随手' : today().slice(5)}</span></div>
      <form
        class="compose"
        onsubmit={(e) => {
          e.preventDefault()
          void add()
        }}
      >
        <span class="car" aria-hidden="true"></span>
        <textarea
          placeholder={view === 'notes' ? '随手记一笔…' : '今天发生了什么?(支持 Markdown)'}
          bind:value={draft}
          aria-label={view === 'notes' ? '速记内容' : '日记内容'}
          rows={view === 'notes' ? 1 : 3}
        ></textarea>
        <button class="act pri" type="submit" disabled={!draft.trim()}>{view === 'notes' ? '记一笔' : '写入今天'}</button>
      </form>
    </div>
  {/if}

  {#if view === 'notes'}
    <div class="row">
      <div class="gut"><span class="tm">收集</span><br />{noteItems.length} 条</div>
      <div>
        <div class="h">速记 / SCRATCH</div>
        {#if noteItems.length === 0}
          <p class="empty">还没有速记 — 上面记一笔,或用 ⌘N 随手记。</p>
        {:else}
          <ul class="list">
            {#each noteItems as n (n.id)}
              <li class="note">
                <span class="nt">{hhmm(n.created_at)}</span>
                <span class="body">{n.content}</span>
                <span class="acts">
                  <button class="act" title="转为今天的日记" onclick={() => notes.toJournal(n.id)}>→日记</button>
                  <button class="act" title="存入记忆" onclick={() => notes.toMemory(n.id)}>→记忆</button>
                  <button class="act" title="转为定时任务" onclick={() => noteToTask(n)}>→任务</button>
                  <button class="act del" aria-label={`删除 ${n.content}`} onclick={() => notes.remove(n.id)}>×</button>
                </span>
              </li>
            {/each}
          </ul>
        {/if}
      </div>
    </div>
  {:else if view === 'journal'}
    <div class="row">
      <div class="gut"><span class="tm">AI</span></div>
      <div>
        <div class="h">今日小结 / SUMMARY</div>
        <button class="act pri" onclick={() => notes.summarizeToday(today())} disabled={notes.summarizing}>
          {notes.summarizing ? '生成中…' : 'AI 今日小结'}
        </button>
        {#if notes.summary}
          <div class="framed"><p class="summary">{notes.summary}</p></div>
        {/if}
      </div>
    </div>
    <div class="row">
      <div class="gut"><span class="tm">条目</span><br />{journalItems.length} 条</div>
      <div>
        <div class="h">日记 / ENTRIES</div>
        {#if journalByDate.length === 0}
          <p class="empty">还没有日记 — 写下今天的第一条。</p>
        {:else}
          <div>
            {#each journalByDate as [day, entries] (day)}
              <section class="day">
                <h3>{day}</h3>
                {#each entries as e (e.id)}
                  <article class="entry">
                    <div class="md">{@html renderMd(e.content)}</div>
                    <button class="act del" aria-label="删除日记" onclick={() => notes.remove(e.id)}>×</button>
                  </article>
                {/each}
              </section>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  {:else if view === 'tasks'}
    <div class="row">
      <div class="gut"><span class="tm">派发</span></div>
      <form
        class="compose"
        onsubmit={(e) => {
          e.preventDefault()
          void addTask()
        }}
      >
        {#if fromNote}
          <span class="chip">
            自速记 #{fromNote.id}
            <button
              type="button"
              class="act del"
              aria-label="取消关联速记"
              onclick={() => {
                fromNote = null
                taskPrompt = ''
              }}>×</button
            >
          </span>
        {/if}
        <input
          placeholder="到点让 agent 做什么(如:汇总未读邮件)…"
          value={promptValue}
          oninput={(e) => {
            if (!fromNote) taskPrompt = e.currentTarget.value
          }}
          aria-label="任务指令"
          readonly={fromNote !== null}
        />
        <input class="cron" placeholder="cron 表达式" bind:value={taskCron} aria-label="cron 表达式" />
        <button class="act pri" type="submit" disabled={fromNote ? false : !taskPrompt.trim()}>加定时</button>
      </form>
    </div>
    {#if tasks.error}<p class="err" role="alert">{tasks.error}</p>{/if}
    <div class="row">
      <div class="gut"><span class="tm">定时</span><br />{tasks.tasks.length} 项</div>
      <div>
        <div class="h">任务 / SCHEDULED</div>
        {#if tasks.tasks.length === 0}
          <p class="empty">还没有定时任务 — 加一个,到点自动触发 agent。</p>
        {:else}
          <ul class="list">
            {#each tasks.tasks as t (t.id)}
              <li class="task" class:off={!t.enabled}>
                <input type="checkbox" class="cbx" checked={t.enabled} aria-label={`启用 ${t.name}`} onchange={() => tasks.toggle(t)} />
                <span class="tname">{t.name}</span>
                <span class="tsched">{t.schedule_kind} · 下次 {nextRunLabel(t.next_run)}</span>
                <span class="acts">
                  <span class="runs">{t.run_count} 次{#if t.last_status}&nbsp;· {t.last_status}{/if}</span>
                  <button class="act del" aria-label={`删除 ${t.name}`} onclick={() => tasks.remove(t.id)}>×</button>
                </span>
              </li>
            {/each}
          </ul>
        {/if}
      </div>
    </div>
  {:else}
    <!-- TODO(F7 日历轮): Calendar.svelte 仍是旧线框样式,该模块轮重设计 -->
    <div class="calwrap">
      <Calendar />
    </div>
  {/if}
</section>

<style>
  .jnt {
    height: 100%;
    overflow: auto;
    padding: 18px 24px 24px 0;
    font-family: var(--sans);
    color: var(--t2);
    max-width: 860px; /* 阅读行长上限(承旧版 760 的约束) */
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
    font-family: var(--mono);
    font-size: 24px;
    font-weight: 800;
    letter-spacing: 1px;
    color: var(--t1);
    margin: 0;
  }
  .head .hd {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--acc-ink);
    font-weight: 700;
  }
  .head .pg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .5px;
    font-variant-numeric: tabular-nums;
  }
  /* 分段 = mono 大写 tag + accent 底线(无胶囊无圆角) */
  .seg {
    display: flex;
    gap: 18px;
    padding-left: var(--gutter-w);
    border-bottom: 1px solid var(--hair);
    margin-bottom: 2px;
  }
  .seg button {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 1px;
    color: var(--t3);
    background: transparent;
    border: 0;
    border-bottom: 2px solid transparent;
    padding: 4px 1px 6px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .seg button:hover {
    color: var(--t1);
  }
  .seg button.active {
    color: var(--t1);
    border-bottom-color: var(--acc);
  }
  /* 账本行:左槽 mono + 发丝分隔(承 Today .rdrow) */
  .row {
    display: grid;
    grid-template-columns: var(--gutter-w) 1fr;
    border-top: 1px solid var(--hair);
    padding: 10px 0;
  }
  /* 紧跟 tab 条的第一行不画顶线(避免和 .seg 底线叠成双线) */
  .seg + .row {
    border-top: none;
  }
  .gut {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    line-height: 1.5;
    padding-top: 3px;
    letter-spacing: .3px;
  }
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
    width: 2px;
    height: 14px;
    background: var(--acc);
    flex: none;
    margin-top: 5px;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .compose textarea,
  .compose input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 13px;
    padding: 3px 0 6px;
    resize: vertical;
    min-width: 0;
  }
  .compose textarea::placeholder,
  .compose input::placeholder {
    color: var(--t4);
  }
  .compose textarea:focus,
  .compose input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .compose input.cron {
    flex: none;
    width: 110px;
    font-family: var(--mono);
    font-size: 11px;
  }
  .compose input[readonly] {
    color: var(--t3);
  }
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
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 0;
    padding: 2px 4px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .act:hover {
    color: var(--t1);
  }
  .act.pri {
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    padding: 4px 10px;
    flex: none;
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
    cursor: default;
  }
  .act.del:hover {
    color: var(--red);
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .note,
  .task {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 4px 0;
    border-top: 1px solid var(--hair);
    font-size: 13px;
  }
  .note:first-child,
  .task:first-child {
    border-top: none;
  }
  .note .nt {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    flex: none;
    min-width: 34px;
    font-variant-numeric: tabular-nums;
  }
  .note .body {
    flex: 1;
    word-break: break-word;
    color: var(--t2);
  }
  .acts {
    display: flex;
    align-items: center;
    gap: 6px;
    flex: none;
  }
  /* 日记:日期 = accent 账本界标 */
  .day h3 {
    margin: 12px 0 4px;
    font-family: var(--mono);
    font-size: 11px;
    font-weight: 700;
    letter-spacing: .5px;
    color: var(--acc-ink);
    border-bottom: 1px solid var(--hair);
    padding-bottom: 3px;
    font-variant-numeric: tabular-nums;
  }
  .day:first-child h3 {
    margin-top: 0;
  }
  .entry {
    display: flex;
    gap: 8px;
    align-items: flex-start;
    padding: 4px 0;
  }
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
  /* AI 小结 = 框选视口(frame + accent L 角,ORAGE) */
  .framed {
    position: relative;
    border: 1px solid var(--line);
    padding: 8px 12px;
    margin-top: 8px;
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
  .summary {
    margin: 0;
    font-size: 13px;
    line-height: 1.55;
    color: var(--t2);
  }
  /* 任务行 */
  .cbx {
    appearance: none;
    width: 13px;
    height: 13px;
    border: 1.4px solid var(--t4);
    background: transparent;
    flex: none;
    cursor: pointer;
    margin: 0;
  }
  .cbx:checked {
    border-color: var(--acc-ink);
    background: var(--acc);
  }
  .task .tname {
    color: var(--t2);
    font-weight: 600;
    font-size: 12.5px;
  }
  .task .tsched {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .task .runs {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .task .acts {
    margin-left: auto;
  }
  .task.off .tname {
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
