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

  // Monotonic token: a stale fetch (older selection) must not overwrite the
  // view of a newer selection. Each effect run bumps it; load() bails if a
  // newer run started while it was awaiting.
  let token = 0

  $effect(() => {
    const sel = cockpit.selected
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

    {#if view.kind === 'markdown'}
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
    padding: 16px;
    box-sizing: border-box;
    border-left: 1px solid #e5e4e7;
  }
  .empty,
  .error {
    color: #999;
    font-size: 0.9rem;
  }
  .error {
    color: #e5484d;
  }
  .title {
    font-weight: 600;
    margin-bottom: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .trunc {
    color: #c97b1f;
    font-size: 0.78rem;
  }
  .code {
    margin: 0;
    font: 13px ui-monospace, monospace;
    white-space: pre;
    overflow: auto;
    background: #f6f6f8;
    padding: 12px;
    border-radius: 8px;
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
  .md :global(pre) {
    background: #f6f6f8;
    padding: 12px;
    border-radius: 8px;
    overflow: auto;
  }
  .zip {
    list-style: none;
    margin: 0;
    padding: 0;
    font: 13px ui-monospace, monospace;
  }
  .zip li {
    display: flex;
    justify-content: space-between;
    padding: 2px 0;
    border-bottom: 1px solid #f0eff2;
  }
  .zs {
    color: #999;
  }
</style>
