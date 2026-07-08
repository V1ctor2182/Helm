<script lang="ts">
  // Canvas 视图(阶段 4 R08,source: helm-journal-pro.html 记录板块 Canvas):
  // 记录卡自由摆放,拖拽持久化(localStorage:helm.canvas.pos)。
  // 最小可用版:白卡(速记文本/收藏卡)+pointer 拖拽;连线/cluster 待后端关系数据(backlog)。
  import type { Note } from './notesStore.svelte'

  let { notes }: { notes: Note[] } = $props()

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

  let dragging = $state<number | null>(null)
  let off = { x: 0, y: 0 }
  function down(e: PointerEvent, id: number, i: number) {
    const p = at(id, i)
    dragging = id
    off = { x: e.clientX - p.x, y: e.clientY - p.y }
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
  }
  function move(e: PointerEvent, id: number) {
    if (dragging !== id) return
    pos[id] = { x: Math.max(0, e.clientX - off.x), y: Math.max(0, e.clientY - off.y) }
  }
  function up(id: number) {
    if (dragging === id) {
      dragging = null
      save()
    }
  }

  const TYPE_LABEL: Record<string, string> = {
    youtube: 'YT', paper: 'AX', inspiration: 'AW', article: 'WEB',
  }
  const TYPE_BG: Record<string, string> = {
    youtube: '#ff2d2d', paper: '#8b5a2b', inspiration: '#0a84ff', article: '#0a84ff',
  }
</script>

<div class="canvas" aria-label="画布">
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
      onpointerup={() => up(n.id)}
      role="button"
      tabindex="0"
    >
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
    min-height: 480px;
    overflow: hidden;
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
  }
</style>
