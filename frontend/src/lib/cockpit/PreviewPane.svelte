<script lang="ts">
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { cockpit, type Entry } from './cockpit.svelte'
  import { previewKind, rawUrl, type PreviewKind } from './previewKind'

  interface Loaded {
    kind: PreviewKind
    entry: Entry
    text?: string
    html?: string
    truncated?: boolean
    zip?: { name: string; size: number }[]
    error?: string
  }

  let view = $state<Loaded | null>(null)
  let loading = $state(false)
  let showDiff = $state(false)

  // Monotonic token: a stale fetch (older selection) must not overwrite the
  // view of a newer selection. Each effect run bumps it; load() bails if a
  // newer run started while it was awaiting.
  let token = 0

  $effect(() => {
    const sel = cockpit.selected
    showDiff = false // reset to preview when the selection changes
    if (!sel) {
      view = null
      return
    }
    const my = ++token
    void load(sel, my)
  })

  async function load(sel: Entry, my: number) {
    const kind = previewKind(sel.ext)
    loading = true
    try {
      if (kind === 'markdown' || kind === 'code') {
        const res = await fetch(`/api/cockpit/text?path=${encodeURIComponent(sel.path)}`)
        if (my !== token) return
        if (!res.ok) throw new Error()
        const body = await res.json()
        if (my !== token) return
        if (kind === 'markdown') {
          const rendered = await marked.parse(body.content)
          if (my !== token) return
          view = { kind, entry: sel, html: DOMPurify.sanitize(rendered), truncated: body.truncated }
        } else {
          view = { kind, entry: sel, text: body.content, truncated: body.truncated }
        }
      } else if (kind === 'zip') {
        const res = await fetch(`/api/cockpit/zip?path=${encodeURIComponent(sel.path)}`)
        if (my !== token) return
        if (!res.ok) throw new Error()
        view = { kind, entry: sel, zip: (await res.json()).entries }
      } else {
        // image / pdf load directly via <img>/<iframe>; none = no preview
        view = { kind, entry: sel }
      }
    } catch {
      if (my === token) view = { kind, entry: sel, error: '无法预览该文件' }
    } finally {
      if (my === token) loading = false
    }
  }
</script>

<div class="preview" aria-label="预览">
  {#if !view}
    <p class="empty">选择一个文件以预览</p>
  {:else if loading}
    <p class="empty">加载中…</p>
  {:else if view.error}
    <p class="error">{view.error}</p>
  {:else}
    <header class="title" title={view.entry.path}>{view.entry.name}</header>
    {#if view.truncated}<p class="trunc">（已截断，仅显示前 1MB）</p>{/if}

    {#if view.kind === 'markdown' || view.kind === 'code'}
      <div class="vtabs">
        <button class:active={!showDiff} onclick={() => (showDiff = false)}>预览</button>
        <button class:active={showDiff} onclick={() => (showDiff = true)}>Diff</button>
      </div>
    {/if}

    {#if showDiff && (view.kind === 'markdown' || view.kind === 'code')}
      <!-- Monaco is heavy: load DiffView lazily so it's code-split out of the
           main bundle and never imported in the test/jsdom module graph. -->
      {#await import('./DiffView.svelte') then mod}
        {@const DiffView = mod.default}
        <DiffView path={view.entry.path} ext={view.entry.ext} />
      {:catch}
        <p class="error">diff 加载失败</p>
      {/await}
    {:else if view.kind === 'markdown'}
      <!-- sanitized via DOMPurify above -->
      <div class="md">{@html view.html}</div>
    {:else if view.kind === 'code'}
      <pre class="code">{view.text}</pre>
    {:else if view.kind === 'image'}
      <img class="img" src={rawUrl(view.entry.path)} alt={view.entry.name} />
    {:else if view.kind === 'pdf'}
      <iframe class="pdf" src={rawUrl(view.entry.path)} title={view.entry.name}></iframe>
    {:else if view.kind === 'zip'}
      <ul class="zip">
        {#each view.zip ?? [] as z (z.name)}
          <li><span class="zn">{z.name}</span><span class="zs">{z.size} B</span></li>
        {/each}
      </ul>
    {:else}
      <p class="empty">该类型暂不支持预览（{view.entry.ext || '无扩展名'}）</p>
    {/if}
  {/if}
</div>

<style>
  .preview {
    height: 100%;
    overflow: auto;
    padding: 14px;
    box-sizing: border-box;
    font-family: var(--sans);
    color: var(--t2);
  }
  .empty,
  .error {
    color: var(--t4);
    font-size: 13px;
  }
  .error {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
  }
  .title {
    font-family: var(--mono);
    font-size: 12px;
    font-weight: 700;
    color: var(--t1);
    margin-bottom: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .trunc {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--orange);
  }
  .vtabs {
    display: flex;
    gap: 14px;
    margin-bottom: 8px;
    border-bottom: 1px solid var(--hair);
  }
  .vtabs button {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 1px;
    color: var(--t3);
    background: transparent;
    border: 0;
    border-bottom: 2px solid transparent;
    padding: 3px 1px 5px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .vtabs button:hover {
    color: var(--t1);
  }
  .vtabs button.active {
    color: var(--t1);
    border-bottom-color: var(--acc);
  }
  .code {
    margin: 0;
    font: 12px var(--mono);
    white-space: pre;
    overflow: auto;
    background: var(--tile);
    border: 1px solid var(--hair);
    padding: 12px;
    color: var(--t2);
  }
  .img {
    max-width: 100%;
    height: auto;
  }
  .pdf {
    width: 100%;
    height: 80vh;
    border: 0;
  }
  .md {
    font-size: 13px;
    line-height: 1.55;
    color: var(--t2);
  }
  .md :global(h1),
  .md :global(h2),
  .md :global(h3) {
    color: var(--t1);
  }
  .md :global(a) {
    color: var(--acc-ink);
  }
  .md :global(pre) {
    background: var(--tile);
    border: 1px solid var(--hair);
    padding: 12px;
    overflow: auto;
  }
  .md :global(code) {
    font-family: var(--mono);
    font-size: 12px;
  }
  .zip {
    list-style: none;
    margin: 0;
    padding: 0;
    font: 12px var(--mono);
    color: var(--t2);
  }
  .zip li {
    display: flex;
    justify-content: space-between;
    padding: 2px 0;
    border-bottom: 1px solid var(--hair);
  }
  .zs {
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
</style>
