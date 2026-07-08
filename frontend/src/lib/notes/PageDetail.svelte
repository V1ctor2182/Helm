<script lang="ts">
  // 日记页详情(K5,稿:helm-journal-kinds.html 日记详情态):
  // 全页阅读 + 专注块(从当天条目聚合) + 当日碎片时间线(该日速记/收藏)。
  import type { Note } from './notesStore.svelte'
  import { localHHMM } from '../time'

  let {
    day,
    entries,
    dayNotes,
    renderMd,
    onclose,
    onedit,
  }: {
    day: string
    entries: Note[]
    dayNotes: Note[]
    renderMd: (s: string) => string
    onclose: () => void
    onedit: (n: Note) => void
  } = $props()

  const WD_ZH = ['日', '一', '二', '三', '四', '五', '六']
  const weekday = $derived.by(() => {
    const d = new Date(day + 'T00:00:00')
    return Number.isNaN(d.getTime()) ? '' : `周${WD_ZH[d.getDay()]}`
  })
  const dayLabel = $derived.by(() => {
    const m = day.match(/(\d{4})-(\d{2})-(\d{2})/)
    return m ? `${Number(m[2])}月${Number(m[3])}日` : day
  })
  const chars = $derived(entries.reduce((a, e) => a + e.content.length, 0))

  // 专注块:从当天条目聚合「专注 N 分钟」记录
  const focus = $derived.by(() => {
    const hits: { mins: number; what: string }[] = []
    for (const e of entries) {
      for (const m of e.content.matchAll(/专注\s*(\d+)\s*分钟(?:\s*[·:]\s*(\S[^\n]*))?/g)) {
        hits.push({ mins: Number(m[1]), what: (m[2] ?? '').trim() })
      }
    }
    return hits
  })
  const focusTotal = $derived(focus.reduce((a, f) => a + f.mins, 0))

  const capLabel = (n: Note) => {
    const t = n.meta?.type
    return t === 'youtube' ? '收藏了 ' + (n.meta?.title ?? '视频') + '(视频)'
      : t === 'paper' ? '收藏了 ' + (n.meta?.title ?? '论文') + '(论文)'
      : t === 'article' || t === 'inspiration' ? '收藏了 ' + (n.meta?.title ?? '网页')
      : n.kind === 'task' ? '待办:' + n.content.slice(0, 30)
      : '速记:' + n.content.slice(0, 30)
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose()
  }
</script>

<svelte:window {onkeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="scrim" role="presentation" onclick={onclose}>
  <div class="sheet" role="dialog" aria-label="日记页详情" tabindex="-1" onclick={(e) => e.stopPropagation()}>
    <header class="dh">
      <span class="kind">日记</span>
      <span class="when">{dayLabel} · {weekday} · {chars} 字</span>
      <button class="x" aria-label="关闭" onclick={onclose}>×</button>
    </header>

    <div class="body">
      <h2 class="ti">{dayLabel}</h2>
      {#each entries as e (e.id)}
        <div class="md">{@html renderMd(e.content)}</div>
      {/each}

      {#if focus.length > 0}
        <div class="focusblock">
          <span class="spark" aria-hidden="true"></span>
          这天专注 {focus.length} 段共 {focusTotal} 分钟{focus.some((f) => f.what) ? ' · ' + focus.map((f) => f.what).filter(Boolean).join(' / ') : ''}
        </div>
      {/if}

      {#if dayNotes.length > 0}
        <div class="fragbox">
          <div class="fragh">这天的碎片(速记时间线)</div>
          {#each dayNotes as n (n.id)}
            <div class="dayline">
              <span class="t">{localHHMM(n.created_at)}</span>
              <span class="tx">{capLabel(n)}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <footer class="acts">
      {#if entries[0]}<button onclick={() => { onedit(entries[0]); onclose() }}>编辑这页</button>{/if}
      <button onclick={onclose}>关闭</button>
    </footer>
  </div>
</div>

<style>
  .scrim {
    position: fixed;
    inset: 0;
    background: color-mix(in srgb, var(--t1) 26%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 90;
    padding: 32px;
  }
  .sheet {
    width: min(600px, 92vw);
    max-height: 86vh;
    overflow-y: auto;
    background: var(--card);
    border-radius: 22px;
    box-shadow: var(--shadow-lg);
  }
  .dh {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 16px 20px 10px;
  }
  .kind {
    font: 600 11px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 5px 11px;
  }
  .when {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .x {
    margin-left: auto;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 0;
    background: var(--pill);
    color: var(--t3);
    font-size: 15px;
    cursor: pointer;
  }
  .x:hover { color: var(--t1); }
  .body {
    padding: 6px 22px 8px;
  }
  .ti {
    font: 800 20px/1.3 var(--sans);
    color: var(--t1);
    margin: 0 0 10px;
  }
  .md {
    font: 400 14.5px/1.75 var(--sans);
    color: var(--t2);
    margin-bottom: 8px;
  }
  .md :global(h1),
  .md :global(h2),
  .md :global(h3) {
    font-size: 15px;
    color: var(--t1);
    margin: 0.5em 0 0.2em;
  }
  .md :global(strong) { color: var(--t1); }
  .focusblock {
    display: flex;
    align-items: center;
    gap: 10px;
    background: var(--bg);
    border-radius: var(--radius-sm);
    border-left: 3px solid var(--g2);
    padding: 11px 13px;
    margin-top: 12px;
    font: 400 12.5px/1.5 var(--sans);
    color: var(--t2);
  }
  .spark {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    flex: none;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .fragbox {
    background: var(--bg);
    border-radius: var(--radius-sm);
    padding: 12px 14px;
    margin-top: 12px;
  }
  .fragh {
    font: 700 12px/1 var(--sans);
    color: var(--t1);
    margin-bottom: 8px;
  }
  .dayline {
    display: flex;
    gap: 9px;
    font: 400 12px/1.7 var(--sans);
    color: var(--t3);
    padding: 2px 0;
    min-width: 0;
  }
  .dayline .t {
    font: 500 10.5px/1.9 var(--mono);
    color: var(--t4);
    flex: none;
  }
  .dayline .tx {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .acts {
    display: flex;
    gap: 8px;
    padding: 14px 20px 18px;
  }
  .acts button {
    font: 500 12px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 9px 16px;
    cursor: pointer;
  }
  .acts button:hover { color: var(--t1); }
</style>
