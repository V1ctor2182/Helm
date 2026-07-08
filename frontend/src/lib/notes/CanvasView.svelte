<script lang="ts">
  // Canvas 视图(阶段 4 R08,source: helm-journal-pro.html 记录板块 Canvas):
  // 记录卡自由摆放,拖拽持久化(localStorage:helm.canvas.pos)。
  // 最小可用版:白卡(速记文本/收藏卡)+pointer 拖拽;连线/cluster 待后端关系数据(backlog)。
  import type { Note } from './notesStore.svelte'

  let {
    notes,
    onopen,
    ondelete,
  }: {
    notes: Note[]
    onopen?: (n: Note) => void
    ondelete?: (n: Note) => void
  } = $props()

  const KEY = 'helm.canvas.pos'
  type Pos = Record<string, { x: number; y: number }>
  function loadPos(): Pos {
    try {
      return JSON.parse(localStorage.getItem(KEY) ?? '{}') as Pos
    } catch {
      return {}
    }
  }
  let pos = $state<Pos>(loadPos())
  function save() {
    localStorage.setItem(KEY, JSON.stringify(pos))
  }

  // 未摆放过的卡:网格散布(3 列)
  function at(id: number, i: number): { x: number; y: number } {
    return pos[id] ?? { x: 24 + (i % 3) * 272, y: 16 + Math.floor(i / 3) * 235 }
  }

  // 画布高度跟着最低的卡长(反馈修复:overflow hidden + 固定高会裁掉下方卡片)
  const canvasH = $derived(Math.max(480, ...notes.map((n, i) => at(n.id, i).y + 340)))

  let dragging = $state<number | null>(null)
  let off = { x: 0, y: 0 }
  let start = { x: 0, y: 0 }
  let moved = false
  function down(e: PointerEvent, id: number, i: number) {
    const p = at(id, i)
    dragging = id
    moved = false
    start = { x: e.clientX, y: e.clientY }
    off = { x: e.clientX - p.x, y: e.clientY - p.y }
    ;(e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId)
  }
  function move(e: PointerEvent, id: number) {
    if (dragging !== id) return
    if (Math.abs(e.clientX - start.x) + Math.abs(e.clientY - start.y) > 4) moved = true
    if (moved) pos[id] = { x: Math.max(0, e.clientX - off.x), y: Math.max(0, e.clientY - off.y) }
  }
  function up(n: Note) {
    if (dragging !== n.id) return
    dragging = null
    if (moved) save()
    else onopen?.(n) // 没拖=点击 → 开详情(反馈修复:canvas 点不开详情)
  }

  // 删除两击确认(反馈修复:canvas 速记没有删除入口)
  let armed = $state<number | null>(null)
  function del(e: Event, n: Note) {
    e.stopPropagation()
    if (armed === n.id) {
      armed = null
      ondelete?.(n)
    } else armed = n.id
  }

  const TYPE_LABEL: Record<string, string> = {
    youtube: 'YT', paper: 'AX', inspiration: 'AW', article: 'WEB',
  }
  const TYPE_BG: Record<string, string> = {
    youtube: '#ff2d2d', paper: '#8b5a2b', inspiration: '#0a84ff', article: '#0a84ff',
  }
</script>

<div class="canvas" aria-label="画布" style="min-height:{canvasH}px">
  {#if notes.length === 0}
    <p class="empty">画布空空 — 记几条速记/收藏,回来自由摆放。</p>
  {/if}
  {#each notes as n, i (n.id)}
    {@const p = at(n.id, i)}
    <div
      class="cnode"
      class:dragging={dragging === n.id}
      style="left:{p.x}px;top:{p.y}px"
      onpointerdown={(e) => down(e, n.id, i)}
      onpointermove={(e) => move(e, n.id)}
      onpointerup={() => up(n)}
      onkeydown={(e) => e.key === 'Enter' && onopen?.(n)}
      role="button"
      tabindex="0"
    >
      {#if ondelete}
        <button class="cx" class:armed={armed === n.id} title="删除"
          aria-label={`删除 ${n.meta?.title ?? n.content}`}
          onpointerdown={(e) => e.stopPropagation()}
          onclick={(e) => del(e, n)}>{armed === n.id ? '确认' : '×'}</button>
      {/if}
      {#if n.meta?.url}
        <div class="card link">
          {#if n.meta.image}<img class="cover" src={n.meta.image} alt="" loading="lazy" />{/if}
          <div class="pad">
            <span class="appic" style="background:{TYPE_BG[n.meta.type ?? ''] ?? '#111114'}">{TYPE_LABEL[n.meta.type ?? ''] ?? 'WEB'}</span>
            <div class="ti">{n.meta.title ?? n.meta.url}</div>
            {#if n.meta.summary}<div class="sum">{n.meta.summary}</div>{/if}
          </div>
        </div>
      {:else}
        <div class="card">
          <div class="pad">
            <span class="appic" style="background:{n.kind === 'task' ? 'var(--green)' : 'var(--t1)'};color:{n.kind === 'task' ? '#fff' : 'var(--onink)'}">{n.kind === 'task' ? 'T' : 'N'}</span>
            <div class="body">{n.content}</div>
          </div>
        </div>
      {/if}
    </div>
  {/each}
</div>

<style>
  .canvas {
    position: relative;
    overflow: hidden; /* 高度由 canvasH 跟卡走,不再裁内容 */
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
    padding: 24px 4px;
  }
  .cnode {
    position: absolute;
    width: 250px;
    cursor: grab;
    user-select: none;
    touch-action: none;
  }
  .cnode.dragging {
    z-index: 30;
    cursor: grabbing;
  }
  .card {
    background: var(--card);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    overflow: hidden;
    transition: box-shadow var(--dur-micro) var(--ease);
  }
  .cnode.dragging .card {
    box-shadow: var(--shadow-lg);
  }
  .cover {
    width: 100%;
    aspect-ratio: 16 / 7.2;
    object-fit: cover;
    display: block;
  }
  .pad {
    padding: 12px 14px;
  }
  .appic {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 26px;
    height: 26px;
    padding: 0 4px;
    border-radius: 8px;
    color: #fff;
    font: 800 10px/1 var(--sans);
    margin-bottom: 8px;
  }
  .ti {
    font: 600 13px/1.35 var(--sans);
    color: var(--t1);
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .sum {
    font: 400 11.5px/1.5 var(--sans);
    color: var(--t3);
    margin-top: 4px;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .body {
    font: 500 12.5px/1.5 var(--sans);
    color: var(--t2);
    word-break: break-word;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 8;
    line-clamp: 8;
    -webkit-box-orient: vertical; /* 超长速记收 8 行,全文进详情看 */
  }
  .cx {
    position: absolute;
    top: 6px;
    right: 6px;
    z-index: 2;
    min-width: 22px;
    height: 22px;
    padding: 0 6px;
    border: 0;
    border-radius: 999px;
    background: var(--pill);
    color: var(--t3);
    font: 600 11px/1 var(--sans);
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.12s;
  }
  .cnode:hover .cx,
  .cnode:focus-within .cx,
  .cx.armed { opacity: 1; }
  .cx:hover,
  .cx.armed { color: #d3382f; }
</style>
