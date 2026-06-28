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

  onMount(() => {
    void notes.load()
    void notes.loadProviders()
    void tasks.load()
    void calendar.load()
    void calendar.loadCaldav()
  })

  function today(): string {
    return new Date().toISOString().slice(0, 10)
  }

  async function addTask() {
    if (!taskPrompt.trim()) return
    const ok = await tasks.create('', taskPrompt, 'cron', { expr: taskCron })
    if (ok) taskPrompt = ''
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
  <div class="seg" role="tablist" aria-label="速记 / 日记">
    <button role="tab" aria-selected={view === 'notes'} class:active={view === 'notes'} onclick={() => (view = 'notes')}>速记</button>
    <button role="tab" aria-selected={view === 'journal'} class:active={view === 'journal'} onclick={() => (view = 'journal')}>日记</button>
    <button role="tab" aria-selected={view === 'tasks'} class:active={view === 'tasks'} onclick={() => (view = 'tasks')}>任务</button>
    <button role="tab" aria-selected={view === 'calendar'} class:active={view === 'calendar'} onclick={() => (view = 'calendar')}>📅 日历</button>
  </div>

  {#if view !== 'tasks' && view !== 'calendar'}
    <form
      class="add"
      onsubmit={(e) => {
        e.preventDefault()
        void add()
      }}
    >
      <textarea
        placeholder={view === 'notes' ? '随手记一笔…' : '今天发生了什么?(支持 Markdown)'}
        bind:value={draft}
        aria-label={view === 'notes' ? '速记内容' : '日记内容'}
        rows={view === 'notes' ? 1 : 3}
      ></textarea>
      <button type="submit" disabled={!draft.trim()}>{view === 'notes' ? '记一笔' : '写入今天'}</button>
    </form>
  {/if}

  {#if notes.error}<p class="err" role="alert">{notes.error}</p>{/if}

  {#if view === 'notes'}
    {#if noteItems.length === 0}
      <p class="empty">还没有速记 — 上面记一笔,或用 ⌘N 随手记。</p>
    {:else}
      <ul class="notes">
        {#each noteItems as n (n.id)}
          <li class="note">
            <span class="body">{n.content}</span>
            <div class="acts">
              <button title="转为今天的日记" onclick={() => notes.toJournal(n.id)}>→日记</button>
              <button title="存入记忆" onclick={() => notes.toMemory(n.id)}>→记忆</button>
              <button class="del" aria-label={`删除 ${n.content}`} onclick={() => notes.remove(n.id)}>🗑</button>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  {:else if view === 'journal'}
    <div class="sumbar">
      <button class="sum" onclick={() => notes.summarizeToday(today())} disabled={notes.summarizing}>
        {notes.summarizing ? '生成中…' : '✨ 今日小结'}
      </button>
      {#if notes.summary}<p class="summary">{notes.summary}</p>{/if}
    </div>
    {#if journalByDate.length === 0}
      <p class="empty">还没有日记 — 写下今天的第一条。</p>
    {:else}
      <div class="journal">
        {#each journalByDate as [day, entries] (day)}
          <section class="day">
            <h3>{day}</h3>
            {#each entries as e (e.id)}
              <article class="entry">
                <div class="md">{@html renderMd(e.content)}</div>
                <button class="del" aria-label="删除日记" onclick={() => notes.remove(e.id)}>🗑</button>
              </article>
            {/each}
          </section>
        {/each}
      </div>
    {/if}
  {:else if view === 'tasks'}
    <form
      class="addtask"
      onsubmit={(e) => {
        e.preventDefault()
        void addTask()
      }}
    >
      <input placeholder="到点让 agent 做什么(如:汇总未读邮件)…" bind:value={taskPrompt} aria-label="任务指令" />
      <input class="cron" placeholder="cron 表达式" bind:value={taskCron} aria-label="cron 表达式" />
      <button type="submit" disabled={!taskPrompt.trim()}>加定时</button>
    </form>
    {#if tasks.error}<p class="err" role="alert">{tasks.error}</p>{/if}
    {#if tasks.tasks.length === 0}
      <p class="empty">还没有定时任务 — 加一个,到点自动触发 agent。</p>
    {:else}
      <ul class="tasks">
        {#each tasks.tasks as t (t.id)}
          <li class="task" class:off={!t.enabled}>
            <div class="ti">
              <span class="tname">{t.name}</span>
              <span class="tsched">{t.schedule_kind} · 下次 {t.next_run?.slice(0, 16) ?? '—'}</span>
            </div>
            <div class="tacts">
              <span class="runs">{t.run_count} 次{#if t.last_status} · {t.last_status}{/if}</span>
              <input type="checkbox" checked={t.enabled} aria-label={`启用 ${t.name}`} onchange={() => tasks.toggle(t)} />
              <button class="del" aria-label={`删除 ${t.name}`} onclick={() => tasks.remove(t.id)}>🗑</button>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  {:else}
    <Calendar />
  {/if}
</section>

<style>
  .jnt {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 14px;
    overflow: auto;
    height: 100%;
    max-width: 760px;
  }
  .seg {
    display: flex;
    gap: 4px;
  }
  .seg button {
    border: 1px solid #e5e4e7;
    background: #f4f3f5;
    border-radius: 999px;
    padding: 3px 14px;
    cursor: pointer;
    font-size: 0.85rem;
  }
  .seg button.active {
    background: #fff;
    font-weight: 600;
  }
  .add {
    display: flex;
    gap: 6px;
  }
  .add textarea {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
    resize: vertical;
    box-sizing: border-box;
  }
  .add button {
    align-self: flex-start;
    padding: 6px 12px;
    border: 1px solid #cfcdd4;
    border-radius: 8px;
    background: #fff;
    cursor: pointer;
  }
  .notes {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .note {
    display: flex;
    align-items: center;
    gap: 8px;
    border: 1px solid #eceaef;
    border-radius: 8px;
    padding: 6px 10px;
    background: #fff;
  }
  .note .body {
    flex: 1;
    word-break: break-word;
  }
  .acts {
    display: flex;
    gap: 4px;
  }
  .acts button {
    border: 1px solid #e5e4e7;
    background: #f7f6f8;
    border-radius: 6px;
    padding: 2px 6px;
    cursor: pointer;
    font-size: 0.74rem;
  }
  .day h3 {
    margin: 10px 0 4px;
    font-size: 0.9rem;
    color: #555;
    border-bottom: 1px solid #eee;
  }
  .entry {
    display: flex;
    gap: 8px;
    align-items: flex-start;
    padding: 4px 0;
  }
  .md {
    flex: 1;
    line-height: 1.5;
  }
  .md :global(p) {
    margin: 0.3em 0;
  }
  .del {
    border: 0;
    background: transparent;
    cursor: pointer;
  }
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
  }
</style>
