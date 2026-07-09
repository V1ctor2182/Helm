<script lang="ts">
  import { layout } from '../layout.svelte'
  import { onMount } from 'svelte'
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { notes, famOf, FAM_BADGE, type Note } from './notesStore.svelte'
  import { tasks } from './tasksStore.svelte'
  import { calendar } from '../mail/calendarStore.svelte'
  import { localHHMM, localDate, localDateTime } from '../time'
  import { ConfirmGate } from '../confirm.svelte'
  import Calendar from './Calendar.svelte'
  import CanvasView from './CanvasView.svelte'
  import JournalCanvas from './JournalCanvas.svelte'
  import NoteDetail from './NoteDetail.svelte'
  import PageDetail from './PageDetail.svelte'
  import NoteEditSheet from './NoteEditSheet.svelte'
  import { renderInline } from './inlineMd'
  import { focus } from '../focus.svelte'
  import CaptureDock from '../CaptureDock.svelte'

  // 三视图(阶段 4 R08,source: helm-journal-pro.html 记录板块)+kind 过滤。
  let view = $state<'timeline' | 'canvas' | 'calendar'>('timeline')
  let display = $state<'timeline' | 'canvas'>('timeline') // 速记/日记内部的展示偏好
  // AI 归类(2026-07-08 用户确认):随便记,AI 静默归集合;墙可切按主题,胶囊可纠错,集合涌现
  let groupBy = $state<'time' | 'topic'>('time')
  const TKEY = 'helm.topics.ack' // {confirmed:[],dismissed:[]}
  function tAck(): { confirmed: string[]; dismissed: string[] } {
    try { return JSON.parse(localStorage.getItem(TKEY) ?? '') } catch { return { confirmed: [], dismissed: [] } }
  }
  function tSave(a: { confirmed: string[]; dismissed: string[] }) {
    try { localStorage.setItem(TKEY, JSON.stringify(a)) } catch { /* test env */ }
  }
  let topicAck = $state(tAck())
  const byTopic = $derived.by(() => {
    const m = new Map<string, Note[]>()
    const loose: Note[] = []
    for (const n of noteItems) {
      const t = n.meta?.topic
      if (t && !topicAck.dismissed.includes(t)) (m.get(t) ?? m.set(t, []).get(t)!).push(n)
      else loose.push(n)
    }
    return { topics: [...m.entries()].sort((a, b) => b[1].length - a[1].length), loose }
  })
  // 涌现:≥3 条且未确认过 → 建议卡
  const suggestion = $derived(byTopic.topics.find(([t, xs]) => xs.length >= 3 && !topicAck.confirmed.includes(t)) ?? null)
  async function unTopic(n: Note) {
    const meta = { ...(n.meta ?? {}) }
    delete meta.topic
    await notes.updateMeta(n.id, meta)
  }
  // filter 共享自 layout(侧栏分类与页内 chips 同源)
  const filterOf = () => layout.journalFilter


  // 深链兼容:旧四 tab 意图 → 三视图+过滤
  $effect(() => {
    if (layout.journalIntent) {
      const i = layout.journalIntent as string
      if (i === 'calendar') view = 'calendar'
      else {
        view = 'timeline'
        layout.journalFilter = i === 'tasks' ? 'task' : i === 'journal' ? 'journal' : 'note'
      }
      layout.journalIntent = null
    }
  })
  // 今天一张卡直接写/改(2026-07-09 用户反馈:不要两张卡)
  let todayText = $state('')
  let todayDirty = $state(false)
  let taskPrompt = $state('')
  // T2 人话排期:边打字出排期徽章(后端 /api/tasks/parse,与提交同一解析器);
  // cron/every/at 三模式表单退场,时间在句子里。
  let parsedLabel = $state<string | null>(null)
  let parseSeq = 0
  function onDispatchInput(v: string) {
    taskPrompt = v
    const seq = ++parseSeq
    setTimeout(() => {
      if (seq !== parseSeq) return
      void tasks.parse(taskPrompt).then((p) => {
        if (seq === parseSeq) parsedLabel = p?.label ?? null
      })
    }, 250)
  }
  const del = new ConfirmGate()
  // note→task flow: →任务 jumps here with the note pinned; submit uses
  // /to-task so linked_note_id survives (server takes the note's content).
  // The prompt shown is derived — cancelling the pin restores the typed draft.
  let fromNote = $state<Note | null>(null)
  // 编辑弹层(2026-07-08 用户拍板:行内 textarea 退场,所见即所得轻格式)
  let editingNote = $state<Note | null>(null)
  let detailNote = $state<Note | null>(null)
  let detailDay = $state<string | null>(null)
  // K6 待办勾选:乐观划线,800ms 后删除(完成即清)
  let doneIds = $state<Set<number>>(new Set())
  function completeTodo(n: Note) {
    doneIds = new Set([...doneIds, n.id])
    setTimeout(() => void notes.remove(n.id), 800)
  }
  // ⋯ 菜单(2026-07-08 用户拍板):打开的卡 id + 删除确认态;点外面/Esc 关
  let menuId = $state<number | null>(null)
  let menuArmed = $state<number | null>(null)
  // 日记页 ⋯ 菜单(按天键):编辑整天 / 删整天
  let dayMenu = $state<string | null>(null)
  let dayMenuArmed = $state<string | null>(null)
  // 瀑布墙分列:JS 轮转分列 + flex(用户反馈:CSS multicol 在 WebKit 把卡
  // 和绝对定位菜单切进邻列——hover 闪烁/菜单断裂/阴影伪影,一并根治)
  let wallW = $state(0)
  const wallCols = $derived(Math.max(1, Math.min(3, Math.floor((wallW + 14) / 264))))
  function splitCols(items: Note[], n: number): Note[][] {
    const cols: Note[][] = Array.from({ length: n }, () => [])
    items.forEach((it, i) => cols[i % n].push(it))
    return cols
  }

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
    // 本地日,不能用 toISOString(UTC)——凌晨 0-8 点会错一天(T4 修)
    const d = new Date()
    const p = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
  }

  // T2 人话排期:整句(或 fromNote 时的时间短语)交给后端解析落库。
  async function addTask() {
    if (fromNote) {
      const pinned = fromNote
      const ok = await notes.toTaskNL(pinned.id, taskPrompt.trim())
      if (ok) {
        fromNote = null
        taskPrompt = ''
        parsedLabel = null
        await tasks.load()
      } else if (!notes.notes.some((n) => n.id === pinned.id)) {
        notes.error = '速记已被删除,已取消关联'
        fromNote = null
      }
      return
    }
    if (!taskPrompt.trim()) return
    const ok = await tasks.createNL(taskPrompt)
    if (ok) {
      taskPrompt = ''
      parsedLabel = null
    }
  }

  // 已转任务标记:tasks 里 linked_note_id 指向的速记
  const linkedNoteIds = $derived(new Set(tasks.tasks.map((t) => t.linked_note_id).filter((x): x is number => x != null)))

  function todayKey(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault()
      void saveToday()
    }
  }

  function startEdit(n: Note) {
    editingNote = n
  }

  async function saveSheet(md: string) {
    if (editingNote == null) return
    if (await notes.update(editingNote.id, md)) editingNote = null
  }

  function noteToTask(n: Note) {
    fromNote = n
    view = 'timeline'
    layout.journalFilter = 'task'
  }

  // One load, three derived views (kind split) — captures/journal/todos share the table.
  // T3:墙上混排 速记/想法/任务回执卡(稿:速记墙分诊徽章+墙上任务回执卡)。
  const noteItems = $derived(
    notes.notes.filter((n) => {
      if (n.kind !== 'note' && n.kind !== 'idea' && n.kind !== 'task') return false
      const f = layout.journalFilter
      if (f === 'collect') return !!n.meta?.url
      // F1:侧栏收藏筛选按 family(兼容老 type),视频类不再漏 bilibili 等。
      if (f === 'youtube') return famOf(n.meta) === 'video' && !!n.meta?.url
      if (f === 'paper') return famOf(n.meta) === 'paper' && !!n.meta?.url
      if (f === 'inspiration') return famOf(n.meta) === 'design' && !!n.meta?.url
      return true
    }),
  )
  const journalItems = $derived(notes.notes.filter((n) => n.kind === 'journal' || n.kind === 'focus'))
  // 「给自己」的任务(分诊/捕获坞落 notes kind:task)——待办列。
  // 稿:按临近排序,有时限的在上(due 升序),没时限的按新旧。
  const todoItems = $derived(
    [...notes.notes.filter((n) => n.kind === 'task')].sort((a, b) => {
      const da = a.meta?.due
      const db = b.meta?.due
      if (da && db) return da.localeCompare(db)
      if (da) return -1
      if (db) return 1
      return (b.created_at ?? '').localeCompare(a.created_at ?? '')
    }),
  )
  // 24h 内(含已过期)= 橙色临近 chip
  function dueSoon(n: Note): boolean {
    const d = n.meta?.due
    return !!d && new Date(d).getTime() - Date.now() < 24 * 3600e3
  }

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
  // T4 每天一篇:天内段落按时间升序拼一篇(与 notch journalToday 口径一致,
  // \n\n 语义=段落续写);PageDetail 吃同一份序。
  const journalByDate = $derived(
    (() => {
      const groups = new Map<string, Note[]>()
      for (const n of journalItems) {
        const d = n.journal_date ?? '未注明日期'
        ;(groups.get(d) ?? groups.set(d, []).get(d)!).push(n)
      }
      return [...groups.entries()]
        .map(([d, xs]) => [d, xs.sort((a, b) => (a.created_at ?? '').localeCompare(b.created_at ?? ''))] as [string, Note[]])
        .sort((a, b) => b[0].localeCompare(a[0]))
    })(),
  )
  // 今天由顶部「今天的页」单卡直接编辑,下方只列过去的天(不重复今天)。
  const pastByDate = $derived(journalByDate.filter(([d]) => d !== today()))

  function renderMd(src: string): string {
    return DOMPurify.sanitize(marked.parse(src ?? '', { async: false }) as string)
  }

  const pad3 = (n: number) => String(n).padStart(3, '0')

  // K4 日记纸页:今日字数 + 连续天数(与 Today 同口径)
  const jToday = $derived(journalItems.filter((n) => n.journal_date === today()))
  // 只 journal-kind(不含 focus 自动记录)——续写/合并的对象
  const jTodayJournals = $derived(
    jToday.filter((n) => n.kind === 'journal').sort((a, b) => (a.created_at ?? '').localeCompare(b.created_at ?? '')),
  )
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

  // 今天的整篇内容(单卡直接编辑的对象);服务器变了且无未保存编辑时回填,
  // 不覆盖正在打的字。保存 = 整篇替换 → consolidate 成单条(自动收编历史碎片)。
  const todayContent = $derived(jTodayJournals.map((e) => e.content).join('\n\n'))
  $effect(() => {
    const c = todayContent
    if (!todayDirty) todayText = c
  })
  async function saveToday() {
    if (!todayDirty) return
    const md = todayText.trim()
    if (!md) { todayDirty = false; return }
    const mine = jTodayJournals
    if (mine.length > 0) {
      if (await notes.consolidateJournal(mine.map((e) => e.id), md)) todayDirty = false
    } else if (await notes.create(md, 'journal', today())) {
      todayDirty = false
    }
  }

  // 编辑「一天一页」:合并当天日记文进弹层;保存时合并回单条(消解历史碎片)。
  let editingDay = $state<{ ids: number[]; seed: Note } | null>(null)
  function editDay(entries: Note[]) {
    const js = entries.filter((e) => e.kind === 'journal')
    const base = js[0] ?? entries[0]
    if (!base) return
    editingDay = { ids: js.map((e) => e.id), seed: { ...base, content: js.map((e) => e.content).join('\n\n') } }
  }
  async function saveDay(md: string) {
    if (!editingDay) return
    const ids = editingDay.ids
    const ok = ids.length > 0 ? await notes.consolidateJournal(ids, md) : await notes.update(editingDay.seed.id, md)
    if (ok) editingDay = null
  }
  async function deleteDay(entries: Note[]) {
    for (const e of entries) await notes.remove(e.id)
  }
</script>

<svelte:window
  onclick={() => { menuId = null; menuArmed = null; dayMenu = null; dayMenuArmed = null }}
  onkeydown={(e) => { if (e.key === 'Escape') { menuId = null; menuArmed = null; dayMenu = null; dayMenuArmed = null } }}
/>

<section class="jnt" aria-label="日记 / 速记">
  <header class="head">
    <h1>记录</h1>
    <span class="hd">速记 · 日记 · 任务 · 日历</span>
    <span class="pg">{notes.notes.filter((n) => n.kind === 'note' || n.kind === 'idea').length} 条速记 · {journalItems.length} 篇日记 · {tasks.tasks.length} 个任务</span>
  </header>

  <!-- 分类为主维度(含日历=全量记录的日历视角);Canvas/Timeline 只是速记·日记内部
       的展示方式,右侧两枚小 icon 切换(用户拍板 2026-07-08) -->
  <div class="viewrow">
    <div class="chips2" role="tablist" aria-label="分类">
      <!-- 「全部」chip 退场(2026-07-08 用户反馈):速记为落地默认 -->
      <button role="tab" aria-selected={view !== 'calendar' && (layout.journalFilter === 'note' || layout.journalFilter === 'all')} class:on={view !== 'calendar' && (layout.journalFilter === 'note' || layout.journalFilter === 'all')} onclick={() => { view = display; layout.journalFilter = 'note' }}>速记</button>
      <button role="tab" aria-selected={view !== 'calendar' && layout.journalFilter === 'journal'} class:on={view !== 'calendar' && layout.journalFilter === 'journal'} onclick={() => { view = display; layout.journalFilter = 'journal' }}>日记</button>
      <button role="tab" aria-selected={view !== 'calendar' && layout.journalFilter === 'task'} class:on={view !== 'calendar' && layout.journalFilter === 'task'} onclick={() => { view = 'timeline'; layout.journalFilter = 'task' }}>任务</button>
      <button role="tab" aria-selected={view === 'calendar'} class:on={view === 'calendar'} onclick={() => (view = 'calendar')}>日历</button>
    </div>
    {#if view !== 'calendar' && layout.journalFilter !== 'task'}
      <div class="dispicons" role="group" aria-label="展示方式">
        <button class="dic" class:on={view === 'timeline'} title="列表" aria-label="列表视图" onclick={() => { view = 'timeline'; display = 'timeline' }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="5" cy="6" r="1" fill="currentColor" stroke="none"/><circle cx="5" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="5" cy="18" r="1" fill="currentColor" stroke="none"/><path d="M9.5 6h10M9.5 12h10M9.5 18h10"/></svg>
        </button>
        <button class="dic" class:on={view === 'canvas'} title="画布" aria-label="画布视图" onclick={() => { view = 'canvas'; display = 'canvas' }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/></svg>
        </button>
      </div>
    {/if}
  </div>

{#snippet wall(items: Note[], showTopic: boolean)}
          <div class="wall">
            {#each splitCols(items, wallCols) as col, ci (ci)}
            <div class="wcol">
            {#each col as n (n.id)}
              <!-- svelte-ignore a11y_no_static_element_interactions -->
              <div
                class="wcard"
                class:plain={!n.meta?.url}
                class:taskcard={n.kind === 'task'}
                role="button"
                tabindex="0"
                onclick={() => (detailNote = n)}
                onkeydown={(e) => e.key === 'Enter' && (detailNote = n)}
              >
                {#if true}
                  {#if n.meta?.url && n.meta.image}
                    <img class="wcover" src={n.meta.image} alt="" loading="lazy" onerror={(e) => ((e.currentTarget as HTMLImageElement).style.display = 'none')} />
                  {/if}
                  <div class="wpad">
                    {#if n.meta?.url}
                      <!-- F1:badge=family 视觉族(色),label=规范类别精确 chip -->
                      {@const fam = famOf(n.meta)}
                      <span class="wbadge" style="background:{FAM_BADGE[fam][1]}">{FAM_BADGE[fam][0]}</span>
                      {#if n.meta.label && n.meta.label !== FAM_BADGE[fam][0]}<span class="labelchip">{n.meta.label}</span>{/if}
                      <span class="wti">{n.meta.title ?? n.meta.url}</span>
                      {#if n.meta.summary}<p class="wsum">{n.meta.summary}</p>{/if}
                    {:else}
                      <span class="wbadge" style="background:var(--t1);color:var(--onink)">N</span>
                      <!-- T3 分诊徽章:想法蓝 tag;任务=回执卡(tag+抽取 chips) -->
                      {#if n.kind === 'idea'}
                        <div class="tagrow"><span class="ntag idea">想法</span></div>
                      {:else if n.kind === 'task'}
                        <div class="tagrow">
                          <span class="ntag task">任务</span>
                          {#if n.meta?.when}<span class="ntag xc">{n.meta.when}</span>{/if}
                          {#if n.meta?.where}<span class="ntag xc">@{n.meta.where}</span>{/if}
                        </div>
                      {/if}
                      <span class="wtx">{@html renderInline(n.content)}</span>
                    {/if}
                    <div class="wfoot">
                      {#if showTopic && n.meta?.topic && groupBy === 'topic'}
                        <!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
                        <span class="topicchip" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
                          <i class="gspark sm" aria-hidden="true"></i>{n.meta.topic}
                          <button class="tx-x" title="移出集合(AI 会学习)" aria-label={`移出集合 ${n.meta.topic}`} onclick={() => void unTopic(n)}>×</button>
                        </span>
                      {/if}
                      {#if n.meta?.site}<span>{n.meta.site}</span>{/if}
                      {#each n.meta?.tags ?? [] as t (t)}<span class="wtag">#{t}</span>{/each}
                      {#if linkedNoteIds.has(n.id)}<span class="linked">已转任务</span>{/if}
                      {#if n.kind === 'task'}
                        <button class="gotask" onclick={(e) => { e.stopPropagation(); view = 'timeline'; layout.journalFilter = 'task' }}>已入待办 →</button>
                      {/if}
                      <span class="wtm">{localHHMM(n.created_at)}</span>
                    </div>
                    <!-- ⋯ 菜单(2026-07-08 用户拍板:编辑/删除收进三个点,点开显示) -->
                    <!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
                    <span class="wacts" class:show={menuId === n.id} onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
                      <button class="dots" title="更多操作" aria-label={`更多操作 ${n.content}`}
                        aria-haspopup="menu" aria-expanded={menuId === n.id}
                        onclick={() => { menuArmed = null; menuId = menuId === n.id ? null : n.id }}>
                        <svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><circle cx="5" cy="12" r="1.8" fill="currentColor"/><circle cx="12" cy="12" r="1.8" fill="currentColor"/><circle cx="19" cy="12" r="1.8" fill="currentColor"/></svg>
                      </button>
                      {#if menuId === n.id}
                        <div class="cmenu" role="menu">
                          <button role="menuitem" onclick={() => { menuId = null; startEdit(n) }}>编辑</button>
                          <button role="menuitem" onclick={() => { menuId = null; void notes.toJournal(n.id) }}>→日记</button>
                          <button role="menuitem" onclick={() => { menuId = null; void notes.toMemory(n.id) }}>→记忆</button>
                          <button role="menuitem" onclick={() => { menuId = null; noteToTask(n) }}>→任务</button>
                          <button role="menuitem" class="mdanger"
                            onclick={() => { if (menuArmed === n.id) { menuId = null; menuArmed = null; void notes.remove(n.id) } else menuArmed = n.id }}>
                            {menuArmed === n.id ? '确认删除' : '删除'}
                          </button>
                        </div>
                      {/if}
                    </span>
                  </div>
                {/if}
              </div>
            {/each}
            </div>
            {/each}
          </div>
{/snippet}

  {#if notes.error}<p class="err" role="alert">{notes.error}</p>{/if}

  {#if view === 'timeline' && layout.journalFilter !== 'task' && layout.journalFilter !== 'journal'}
    <!-- 智能捕获坞(K7 判类内置):旧账本 compose 行退场,一个入口自动分流 -->
    <CaptureDock />
  {/if}

  {#if view === 'timeline'}
  {#if ['all', 'note', 'collect', 'youtube', 'paper', 'inspiration'].includes(layout.journalFilter)}
    <div class="wallwrap" bind:clientWidth={wallW}>
        <div class="groupsw">
          <button class="gsw" class:on={groupBy === 'time'} onclick={() => (groupBy = 'time')}>按时间</button>
          <button class="gsw" class:on={groupBy === 'topic'} onclick={() => (groupBy = 'topic')}>
            <span class="gspark" aria-hidden="true"></span>按主题 · AI
          </button>
        </div>
        {#if focus.running}
          <div class="focuslive">
            <span class="fring" style="background:conic-gradient(var(--g1) 0deg, var(--g2) {focus.deg}deg, var(--pill) {focus.deg}deg)">
              <span class="ftime">{focus.mmss}</span>
            </span>
            <span class="fmid">
              <span class="fl">专注中</span>
              <span class="fw">{focus.what || '未命名专注'}</span>
            </span>
            <button class="fstop" onclick={() => void focus.stop()}>停止并记入日记</button>
          </div>
        {/if}
        {#if noteItems.length === 0}
          <p class="empty">还没有速记 — 上面记一笔,或用 ⌘N 随手记。</p>
        {:else if groupBy === 'topic'}
          {#if suggestion}
            <div class="aisuggest">
              <span class="gspark" aria-hidden="true"></span>
              <span>发现 {suggestion[1].length} 条关于 <b>{suggestion[0]}</b> 的记录 — 建一个集合?</span>
              <button class="sgok" onclick={() => { topicAck = { ...topicAck, confirmed: [...topicAck.confirmed, suggestion![0]] }; tSave(topicAck) }}>创建集合</button>
              <button class="sgno" onclick={() => { topicAck = { ...topicAck, dismissed: [...topicAck.dismissed, suggestion![0]] }; tSave(topicAck) }}>忽略</button>
            </div>
          {/if}
          {#each byTopic.topics as [t, items] (t)}
            <div class="topich"><span class="tdot" aria-hidden="true"></span><b>{t}</b>
              <span class="tn">{items.length} 条 · AI 维护</span></div>
            {@render wall(items, true)}
          {/each}
          {#if byTopic.loose.length > 0}
            <div class="topich dim"><span class="tdot loose" aria-hidden="true"></span><b>未归类</b>
              <span class="tn">{byTopic.loose.length} 条 · AI 攒够相似的会提议建集合</span></div>
            {@render wall(byTopic.loose, false)}
          {/if}
        {:else}
          {#each notesByDate as [d, items] (d)}
          <div class="dstamp">{dayLabel(d)}<span class="dn">{items.length} 条</span></div>
          <!-- K1 瀑布卡墙(稿:helm-journal-kinds.html 速记态):便签/收藏卡混排 -->
          {@render wall(items, true)}
          {/each}
        {/if}
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
      <!-- 今天一张卡,直接写/改(2026-07-09 用户反馈:不要空写入框+已写卡两张) -->
      <div class="todaypage">
        <div class="dh"><span class="d">{dayNum(today())}</span><span class="w">{weekdayOf(today())} · 今天</span>
          {#if todayText.trim()}<span class="cnt">{todayText.length} 字</span>{/if}</div>
        <textarea
          placeholder="今天发生了什么?直接写(支持 Markdown);点开别处或 ⌘⏎ 自动保存"
          bind:value={todayText}
          oninput={() => (todayDirty = true)}
          onkeydown={todayKey}
          onblur={() => void saveToday()}
          aria-label="今天的日记"
        ></textarea>
        <div class="actrow"><span class="hint2">{todayDirty ? '未保存 · ⌘⏎ 或点开别处即存' : '已保存 · 直接改这里'} · Markdown</span>
          <button class="act pri" onclick={() => void saveToday()} disabled={!todayDirty || !todayText.trim()}>保存今天</button></div>
      </div>
      {#if pastByDate.length > 0}
        {#each pastByDate as [day, entries] (day)}
          <!-- T4 每天一篇:当天所有条目合成一大篇(\n\n 段落),不再一条条散着 -->
          <section class="jpage">
            <button class="dh openbtn" title="查看这一天" onclick={() => (detailDay = day)}>
              <span class="d">{dayNum(day)}</span><span class="w">{weekdayOf(day)}</span>
              <span class="cnt">{entries.reduce((a, e) => a + e.content.length, 0)} 字</span></button>
            <div class="md">{@html renderMd(entries.map((e) => e.content).join('\n\n'))}</div>
            <!-- 日级操作收进 ⋯(与速记卡一致):hover 浮现,点开出菜单 -->
            <!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
            <span class="jacts" class:show={dayMenu === day} onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
              <button class="dots" title="更多操作" aria-label={`这天日记的操作`}
                aria-haspopup="menu" aria-expanded={dayMenu === day}
                onclick={() => { dayMenuArmed = null; dayMenu = dayMenu === day ? null : day }}>
                <svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><circle cx="5" cy="12" r="1.8" fill="currentColor"/><circle cx="12" cy="12" r="1.8" fill="currentColor"/><circle cx="19" cy="12" r="1.8" fill="currentColor"/></svg>
              </button>
              {#if dayMenu === day}
                <div class="cmenu" role="menu">
                  <button role="menuitem" onclick={() => { dayMenu = null; editDay(entries) }}>编辑</button>
                  <button role="menuitem" class="mdanger"
                    onclick={() => { if (dayMenuArmed === day) { dayMenu = null; dayMenuArmed = null; void deleteDay(entries) } else dayMenuArmed = day }}>
                    {dayMenuArmed === day ? '确认删整天' : '删除'}
                  </button>
                </div>
              {/if}
            </span>
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
            onclick={() => { fromNote = null; taskPrompt = ''; parsedLabel = null }}>×</button>
        </span>
      {/if}
      <input
        placeholder={fromNote
          ? '什么时候?用人话说 —「每天早上 9 点」「明晚 8 点」…'
          : '让 agent 做什么,时间用人话说 —「每天早上 9 点汇总未读邮件」「周五下午回顾本周」…'}
        value={taskPrompt}
        oninput={(e) => onDispatchInput(e.currentTarget.value)}
        aria-label="任务指令"
      />
      {#if parsedLabel}
        <span class="aiverdict"><span class="vspark" aria-hidden="true"></span>{parsedLabel}</span>
      {/if}
      <button class="act pri" type="submit" disabled={fromNote ? false : !taskPrompt.trim()}>交给 agent</button>
    </form>
    {#if tasks.error}<p class="err" role="alert">{tasks.error}</p>{/if}

    <div class="taskcols">
      <div>
        <div class="colh"><span class="t">待办 · 给自己</span><span class="n">{todoItems.length} 条</span></div>
        {#if todoItems.length === 0}
          <p class="empty">没有待办 — 捕获坞/刘海里选「任务 · 给自己」记一条。</p>
        {:else}
          <div class="todolist">
            <!-- T3 两层任务行(稿):标题行 / 元信息 chips(临近 24h 橙);操作 hover 浮现 -->
            {#each todoItems as n (n.id)}
              <div class="todo" class:done={doneIds.has(n.id)}>
                <button class="cb" aria-label={`完成 ${n.content}`} onclick={() => completeTodo(n)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M5 13l4 4 10-10"/></svg>
                </button>
                <div class="mid">
                  <button class="tx openable2" title="查看详情" onclick={() => (detailNote = n)}>{@html renderInline(n.content)}</button>
                  {#if n.meta?.when || n.meta?.where || n.meta?.triage}
                    <div class="tmeta">
                      {#if n.meta?.when}<span class="tchip" class:duesoon={dueSoon(n)}>{n.meta.when}</span>{/if}
                      {#if n.meta?.where}<span class="tchip">@{n.meta.where}</span>{/if}
                      {#if n.meta?.triage}<span class="tchip"><span class="gspark sm" aria-hidden="true"></span>速记分诊</span>{/if}
                    </div>
                  {/if}
                </div>
                <span class="acts">
                  <button class="up" title="开始专注做这件事" onclick={() => { focus.start(n.content); layout.journalFilter = 'note' }}>专注</button>
                  <button class="up" title="转为定时任务(交给 agent)" onclick={() => noteToTask(n)}>→ agent</button>
                </span>
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
                  <!-- 人话排期 chip(T2:cron 表达式退出 UI);老任务没 nl 退回模式名 -->
                  <span class="cronchip">{(t.schedule_value?.nl as string | undefined) ?? t.schedule_kind}</span>
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
    {#if layout.journalFilter === 'journal'}
      <JournalCanvas
        days={journalByDate}
        fragCount={(day) => notesOfDay(day).length}
        onopen={(day) => (detailDay = day)}
      />
    {:else}
      <CanvasView
        notes={notes.notes.filter((n) => n.kind !== 'journal')}
        onopen={(n) => (detailNote = n)}
        ondelete={(n) => notes.remove(n.id)}
      />
    {/if}
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
      ondelete={(n) => notes.remove(n.id)}
    />
  {/if}

  {#if editingNote}
    <NoteEditSheet note={editingNote} onsave={saveSheet} onclose={() => (editingNote = null)} />
  {/if}

  {#if editingDay}
    <NoteEditSheet note={editingDay.seed} onsave={saveDay} onclose={() => (editingDay = null)} />
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
    margin: 2px 0 12px;
  }
  .dispicons {
    display: flex;
    gap: 4px;
    margin-left: auto;
  }
  .dic {
    width: 34px;
    height: 34px;
    border-radius: var(--radius-sm);
    border: 0;
    background: transparent;
    color: var(--t4);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all var(--dur-micro) var(--ease);
  }
  .dic :global(svg) {
    width: 17px;
    height: 17px;
  }
  .dic:hover {
    color: var(--t1);
    background: var(--pill);
  }
  .dic.on {
    color: var(--t1);
    background: var(--pill);
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
  /* 账本行:左槽 mono + 发丝分隔(承 Today .rdrow) */
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
  .linked {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
    border: 1px solid var(--hair);
    padding: 0 4px;
    flex: none;
  }
  .wallwrap {
    margin-top: 4px;
  }
  /* —— AI 归类(按主题) —— */
  .groupsw {
    display: flex;
    gap: 4px;
    margin-bottom: 12px;
  }
  .gsw {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font: 500 11.5px/1 var(--sans);
    color: var(--t4);
    background: transparent;
    border: 0;
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    cursor: pointer;
  }
  .gsw:hover { color: var(--t1); }
  .gsw.on {
    color: var(--t1);
    background: var(--pill);
    font-weight: 600;
  }
  .gspark {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex: none;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .gspark.sm {
    width: 8px;
    height: 8px;
  }
  .aisuggest {
    display: flex;
    align-items: center;
    gap: 9px;
    background: var(--card);
    border: 1.4px dashed color-mix(in srgb, var(--g2) 45%, transparent);
    border-radius: 14px;
    padding: 11px 14px;
    margin-bottom: 16px;
    font: 400 12.5px/1.4 var(--sans);
    color: var(--t2);
  }
  .aisuggest b { color: var(--t1); }
  .sgok {
    margin-left: auto;
    font: 600 11px/1 var(--sans);
    color: #fff;
    background: var(--grad);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 7px 13px;
    cursor: pointer;
    flex: none;
  }
  .sgno {
    font: 500 11px/1 var(--sans);
    color: var(--t4);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 7px 13px;
    cursor: pointer;
    flex: none;
  }
  .topich {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin: 16px 2px 10px;
  }
  .topich.dim { opacity: 0.72; }
  .tdot {
    width: 9px;
    height: 9px;
    border-radius: 3px;
    background: var(--grad);
    align-self: center;
  }
  .tdot.loose { background: var(--t4); }
  .topich b { font: 700 13.5px/1 var(--sans); color: var(--t1); }
  .topich .tn { font: 400 10.5px/1 var(--sans); color: var(--t4); }
  .topicchip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font: 500 9.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 3px 8px;
  }
  .topicchip .tx-x {
    border: 0;
    background: none;
    color: var(--t4);
    cursor: pointer;
    padding: 0 1px;
    font-size: 10px;
    visibility: hidden;
  }
  .wcard:hover .topicchip .tx-x { visibility: visible; }
  .topicchip .tx-x:hover { color: #e5484d; }
  /* —— K8 专注活卡 —— */
  .focuslive {
    display: flex;
    align-items: center;
    gap: 16px;
    background: var(--card);
    border-radius: 18px;
    box-shadow: var(--shadow);
    padding: 14px 18px;
    margin-bottom: 16px;
  }
  .fring {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    flex: none;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .ftime {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background: var(--card);
    display: flex;
    align-items: center;
    justify-content: center;
    font: 700 11px/1 var(--mono);
    color: var(--t1);
    font-variant-numeric: tabular-nums;
  }
  .fmid {
    display: flex;
    flex-direction: column;
    gap: 3px;
    min-width: 0;
  }
  .fl {
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
    letter-spacing: 0.4px;
  }
  .fw {
    font: 600 14px/1.4 var(--sans);
    color: var(--t1);
  }
  .fstop {
    margin-left: auto;
    font: 600 12px/1 var(--sans);
    color: #fff;
    background: var(--grad);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 9px 17px;
    cursor: pointer;
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
  .dispatch input {
    flex: 1;
    min-width: 200px;
    border: 0;
    outline: none;
    font: 400 13.5px/1 var(--sans);
    background: transparent;
    color: var(--t1);
  }
  .dispatch input::placeholder { color: var(--t4); }
  /* T2 实时排期徽章(稿 .aiverdict:spark+人话时间) */
  .aiverdict {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font: 500 11.5px/1 var(--sans);
    color: var(--t2);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 7px 11px;
    white-space: nowrap;
  }
  .vspark {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: linear-gradient(135deg, var(--g1), var(--g2));
    flex: none;
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
  /* T3 两层任务行(稿):cb 顶对齐,mid=标题+chips,acts 垂直居中 hover 现 */
  .todo {
    display: flex;
    align-items: flex-start;
    gap: 11px;
    padding: 11px 10px;
    border-radius: var(--radius-sm);
  }
  .todo:hover { background: var(--pill); }
  .todo .cb { margin-top: 1px; }
  .todo .mid {
    flex: 1;
    min-width: 0;
  }
  .todo .tmeta {
    display: flex;
    gap: 5px;
    margin-top: 5px;
    flex-wrap: wrap;
    align-items: center;
  }
  .tchip {
    font: 600 10px/1 var(--mono);
    color: var(--t2);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 3px 8px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .todo:hover .tchip { background: var(--card); }
  .tchip.duesoon {
    color: #c05e00;
    background: #fff4e8; /* 稿:24h 内临近橙 */
  }
  :global([data-theme='dark']) .tchip.duesoon {
    color: #ffab70;
    background: rgba(255, 138, 61, 0.16);
  }
  .todo .acts {
    display: flex;
    gap: 5px;
    align-self: center;
  }
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
    display: block;
    width: 100%;
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
  .todo:hover .up,
  .todo:focus-within .up { opacity: 1; }
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
  /* 日记页 ⋯ 操作:右上角,hover 浮现(与速记卡 .wacts 同语言) */
  .jacts {
    position: absolute;
    top: 18px;
    right: 22px;
    display: flex;
    opacity: 0;
    transition: opacity var(--dur-micro) var(--ease);
  }
  .jpage:hover .jacts,
  .jpage:focus-within .jacts,
  .jacts.show {
    opacity: 1;
  }

  /* —— K1 瀑布卡墙 —— */
  .wall {
    display: flex;
    gap: 14px;
    align-items: flex-start;
    margin-bottom: 6px;
  }
  .wcol {
    flex: 1;
    min-width: 0;
  }
  .wcard {
    background: var(--card);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    margin: 0 0 14px;
    overflow: visible; /* ⋯ 菜单要浮出卡外 */
    transition: box-shadow var(--dur-micro) var(--ease);
    position: relative;
  }
  .wcard .wcover {
    border-radius: var(--radius) var(--radius) 0 0; /* overflow:visible 后自己圆角 */
  }
  /* 轻格式高亮(编辑弹层写入的 <mark>) */
  .jnt :global(mark) {
    background: #fff3bf;
    border-radius: 3px;
    padding: 0 2px;
  }
  .wcard:hover {
    box-shadow: var(--shadow-lg);
  }
  /* T3 墙上任务回执卡(稿):橙左沿 + tag/chips + 已入待办 → */
  .wcard.taskcard { border-left: 3px solid var(--g1); }
  .tagrow {
    display: flex;
    gap: 5px;
    flex-wrap: wrap;
    margin-bottom: 6px;
    align-items: center;
  }
  .ntag {
    display: inline-block;
    font-size: 9.5px;
    font-weight: 700;
    border-radius: var(--radius-pill);
    padding: 2px 8px;
    color: #fff;
  }
  .ntag.idea { background: #0a84ff; }
  .ntag.task { background: var(--grad); }
  .ntag.xc {
    color: var(--t2);
    background: var(--pill);
    font-weight: 600;
    font-family: var(--mono);
  }
  .gotask {
    font: 600 10.5px/1 var(--sans);
    color: var(--g1);
    background: none;
    border: 0;
    padding: 0;
    cursor: pointer;
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
    padding: 0 6px;
    border-radius: 7px;
    color: #fff;
    font: 800 9.5px/1 var(--sans);
    margin-bottom: 8px;
  }
  /* F1 规范类别 chip(label,精确类型词) */
  .labelchip {
    display: inline-block;
    margin: 0 0 8px 6px;
    padding: 3px 8px;
    border-radius: var(--radius-pill);
    background: var(--pill);
    color: var(--t2);
    font: 600 10px/1 var(--sans);
    vertical-align: top;
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
  /* ⋯ 在卡片右上角(2026-07-08 用户拍板) */
  .wacts {
    position: absolute;
    top: 10px;
    right: 10px;
    display: flex;
    opacity: 0;
    transition: opacity var(--dur-micro) var(--ease);
  }
  .wcard:hover .wacts,
  .wcard:focus-within .wacts,
  .wacts.show {
    opacity: 1;
  }
  /* ⋯ 三点钮 + 下拉菜单(用户拍板) */
  .dots {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 22px;
    border: 0;
    border-radius: var(--radius-pill);
    background: var(--pill);
    color: var(--t3);
    cursor: pointer;
  }
  .dots:hover,
  .wacts.show .dots { color: var(--t1); }
  .cmenu {
    position: absolute;
    top: 26px;
    right: 0;
    z-index: 40;
    min-width: 128px;
    background: var(--card);
    border-radius: 12px;
    box-shadow: var(--shadow-lg);
    padding: 5px;
    display: flex;
    flex-direction: column;
  }
  .cmenu button {
    border: 0;
    background: none;
    text-align: left;
    font: 500 12px/1 var(--sans);
    color: var(--t2);
    padding: 8px 10px;
    border-radius: 8px;
    cursor: pointer;
  }
  .cmenu button:hover {
    background: var(--pill);
    color: var(--t1);
  }
  .cmenu .mdanger:hover,
  .cmenu .mdanger { color: #d3382f; }

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
