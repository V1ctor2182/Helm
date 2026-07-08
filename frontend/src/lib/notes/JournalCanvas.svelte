<script lang="ts">
  // 日记 · 回顾画布(批次3,稿:helm-journal-kinds.html #p-journal-canvas):
  // 把日子摆成一张图——页卡(日期/首行/字数/专注·碎片徽章)自由拖放,位置记住;点开=全页回放。
  import type { Note } from './notesStore.svelte'

  let {
    days,
    fragCount,
    onopen,
  }: {
    days: [string, Note[]][]
    fragCount: (day: string) => number
    onopen: (day: string) => void
  } = $props()

  const POSKEY = 'helm.jcanvas.pos'
  function loadPos(): Record<string, { x: number; y: number }> {
    try { return JSON.parse(localStorage.getItem(POSKEY) ?? '') } catch { return {} }
  }
  let pos = $state(loadPos())
  function savePos() {
    try { localStorage.setItem(POSKEY, JSON.stringify(pos)) } catch { /* test env */ }
  }

  const WD_ZH = ['日', '一', '二', '三', '四', '五', '六']
  const dayLabel = (d: string) => {
    const m = d.match(/(\d{4})-(\d{2})-(\d{2})/)
    return m ? `${Number(m[2])}月${Number(m[3])}日` : d
  }
  const weekdayOf = (d: string) => {
    const t = new Date(d + 'T00:00:00')
    return Number.isNaN(t.getTime()) ? '' : `周${WD_ZH[t.getDay()]}`
  }
  const focusMins = (entries: Note[]) => {
    let mins = 0
    for (const e of entries)
      for (const m of e.content.matchAll(/专注\s*(\d+)\s*分钟/g)) mins += Number(m[1])
    return mins
  }
  const firstLine = (entries: Note[]) =>
    (entries[0]?.content ?? '').split('\n').find((l) => l.trim()) ?? ''

  function at(day: string, i: number) {
    return pos[day] ?? { x: 24 + (i % 3) * 300, y: 16 + Math.floor(i / 3) * 170 }
  }

  let drag: { day: string; ox: number; oy: number } | null = null
  let moved = false
  function down(e: PointerEvent, day: string, i: number) {
    const p = at(day, i)
    drag = { day, ox: e.clientX - p.x, oy: e.clientY - p.y }
    moved = false
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
  }
  function move(e: PointerEvent) {
    if (!drag) return
    moved = true
    pos = { ...pos, [drag.day]: { x: Math.max(0, e.clientX - drag.ox), y: Math.max(0, e.clientY - drag.oy) } }
  }
  function up(day: string) {
    if (drag) savePos()
    const wasDrag = moved
    drag = null
    if (!wasDrag) onopen(day)
  }
</script>

<div class="jcvs" role="application" aria-label="日记画布">
  {#if days.length === 0}
    <p class="empty">还没有日记 — 切回列表写下今天的第一条。</p>
  {/if}
  {#each days as [day, entries], i (day)}
    {@const p = at(day, i)}
    <div
      class="jnode"
      style="left:{p.x}px;top:{p.y}px"
      role="button"
      tabindex="0"
      onpointerdown={(e) => down(e, day, i)}
      onpointermove={move}
      onpointerup={() => up(day)}
      onkeydown={(e) => e.key === 'Enter' && onopen(day)}
    >
      <div class="jmh">
        <b>{dayLabel(day)}</b>
        <span>{weekdayOf(day)} · {entries.reduce((a, e) => a + e.content.length, 0)} 字</span>
      </div>
      <p>{firstLine(entries)}</p>
      <div class="jmf">
        {#if focusMins(entries) > 0}<span class="fchip">专注 {focusMins(entries)} 分钟</span>{/if}
        {#if fragCount(day) > 0}<span class="fchip cy">{fragCount(day)} 条碎片</span>{/if}
      </div>
    </div>
  {/each}
  <div class="cvhint">日记 · 画布:把日子摆成一张图 — 页卡可拖 · 点开=全页回放 · 位置自动记住</div>
</div>

<style>
  .jcvs {
    position: relative;
    min-height: 480px;
    background: var(--bg);
    border-radius: 20px;
    overflow: hidden;
  }
  .jnode {
    position: absolute;
    width: 270px;
    background: var(--card);
    border-radius: 16px;
    box-shadow: var(--shadow);
    padding: 14px 16px;
    cursor: grab;
    user-select: none;
    touch-action: none;
  }
  .jnode:active {
    cursor: grabbing;
    z-index: 30;
    box-shadow: var(--shadow-lg);
  }
  .jmh {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin-bottom: 6px;
  }
  .jmh b {
    font: 800 14px/1 var(--sans);
    color: var(--t1);
  }
  .jmh span {
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
  }
  .jnode p {
    font: 400 12px/1.6 var(--sans);
    color: var(--t2);
    margin: 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .jmf {
    display: flex;
    gap: 6px;
    margin-top: 8px;
  }
  .fchip {
    font: 500 10px/1 var(--sans);
    color: var(--g2);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 4px 9px;
  }
  .fchip.cy { color: var(--cyan); }
  .cvhint {
    position: absolute;
    left: 18px;
    bottom: 14px;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    pointer-events: none;
  }
  .empty {
    padding: 40px;
    font: 400 13px/1.6 var(--sans);
    color: var(--t4);
  }
</style>
