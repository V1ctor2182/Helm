<script lang="ts">
  import { untrack } from 'svelte'
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { cockpit, type Entry } from './cockpit.svelte'
  import {previewKind, rawUrl, type PreviewKind, previewOriginUrl } from './previewKind'

  interface Loaded {
    kind: PreviewKind
    entry: Entry
    text?: string
    html?: string
    truncated?: boolean
    mtime?: number
    zip?: { name: string; size: number }[]
    error?: string
  }

  let view = $state<Loaded | null>(null)
  let loading = $state(false)
  // 预览标签:view=渲染/编辑(code 的预览即编辑) · src=md 源码编辑 · diff=git
  let vtab = $state<'view' | 'src' | 'diff'>('view')

  // ── 预览即编辑(承 FanBox app:1179-1382):停笔 0.8s 自动落盘 + ⌘S 立即 +
  //    expectedMtime 并发覆盖保护(agent 外改 → 409 → 显式选 重载/覆盖)。
  let editText = $state('')
  let editPath: string | null = null
  let editMtime = 0
  let dirty = $state(false)
  let savedAt = $state<number | null>(null)
  let conflict = $state(false)
  let saveErr = $state<string | null>(null)
  let nowTick = $state(Date.now())
  let saveTimer: ReturnType<typeof setTimeout> | null = null
  let chain: Promise<void> = Promise.resolve() // 写盘串行化
  let previewEl = $state<HTMLDivElement | null>(null)
  let editEl = $state<HTMLTextAreaElement | null>(null)
  let followPulse = $state(false)
  let lastFollowTick = 0

  $effect(() => {
    const t = setInterval(() => (nowTick = Date.now()), 1000)
    return () => clearInterval(t)
  })

  const savedLabel = $derived.by(() => {
    if (conflict || saveErr) return ''
    if (dirty) return '编辑中…'
    if (savedAt == null) return ''
    const s = Math.max(0, Math.floor((nowTick - savedAt) / 1000))
    if (s < 60) return `${s} 秒前已保存`
    if (s < 3600) return `${Math.floor(s / 60)} 分前已保存`
    const d = new Date(savedAt)
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')} 已保存`
  })

  function startEditSession(l: Loaded) {
    editPath = l.entry.path
    editText = l.text ?? ''
    editMtime = l.mtime ?? 0
    dirty = false
    conflict = false
    saveErr = null
    savedAt = null
  }

  function onEdit(v: string) {
    cockpit.manualTakeover() // 编辑=手动接管,跟随即停(承 FanBox)
    editText = v
    dirty = true
    if (saveTimer) clearTimeout(saveTimer)
    saveTimer = setTimeout(() => void flush(), 800)
  }

  async function doSave(path: string, text: string, expected: number | null) {
    try {
      const res = await fetch('/api/cockpit/text', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ path, content: text, expected_mtime: expected }),
      })
      if (res.status === 409) {
        if (path === editPath) conflict = true
        return
      }
      if (!res.ok) {
        if (path === editPath) saveErr = '保存失败'
        return
      }
      const body = (await res.json()) as { mtime: number }
      if (path === editPath) {
        editMtime = body.mtime
        dirty = false
        conflict = false
        saveErr = null
        savedAt = Date.now()
      }
    } catch {
      if (path === editPath) saveErr = '保存失败(网络)'
    }
  }

  /** 把当前草稿排进写盘链。overwrite=true 时不带 expectedMtime(显式覆盖外部改动)。 */
  function flush(overwrite = false): Promise<void> {
    if (saveTimer) {
      clearTimeout(saveTimer)
      saveTimer = null
    }
    if (!editPath || (!dirty && !overwrite)) return chain
    const path = editPath
    const text = editText
    const expected = overwrite ? null : editMtime
    chain = chain.then(() => doSave(path, text, expected))
    return chain
  }

  function editKeydown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault()
      void flush()
    }
  }

  /** 直挂 input/keydown 监听(action):绕开 Svelte 5 事件代理,
   *  jsdom 手动派发与真浏览器行为一致。 */
  function editInput(node: HTMLTextAreaElement) {
    const onInput = () => onEdit(node.value)
    node.addEventListener('input', onInput)
    node.addEventListener('keydown', editKeydown)
    return {
      destroy() {
        node.removeEventListener('input', onInput)
        node.removeEventListener('keydown', editKeydown)
      },
    }
  }

  // 跟随刷新(承 FanBox 代码实时流/md 贴底):同文件再写 → 干净时重载;
  // 代码滚到首个变动行+脉冲;md 尾部变更贴底、改中间保持视口。
  $effect(() => {
    const t = cockpit.followTick
    if (t === lastFollowTick) return
    lastFollowTick = t
    const sel = cockpit.selected
    if (!sel || dirty || conflict) return
    void followReload(sel)
  })

  // 编辑器有未保存改动 → 跟随不抢屏(同步给 store)
  $effect(() => {
    cockpit.editorBusy = dirty
  })

  function firstChangedLine(a: string, b: string): number {
    const la = a.split('\n')
    const lb = b.split('\n')
    const n = Math.min(la.length, lb.length)
    let i = 0
    while (i < n && la[i] === lb[i]) i++
    return i
  }

  async function followReload(sel: Entry) {
    const container = previewEl
    const nearBottom = container
      ? container.scrollHeight - container.scrollTop - container.clientHeight < 80
      : false
    const prevScroll = container?.scrollTop ?? 0
    const oldText = editText
    const my = ++token
    await load(sel, my)
    if (my !== token) return
    if (view?.kind === 'code' && editEl) {
      const line = firstChangedLine(oldText, editText)
      editEl.scrollTop = Math.max(0, (line - 3) * 18)
      followPulse = true
      setTimeout(() => (followPulse = false), 700)
    } else if (view?.kind === 'markdown' && container) {
      const tail = firstChangedLine(oldText, view.text ?? '') >= oldText.split('\n').length - 2
      container.scrollTop = tail || nearBottom ? container.scrollHeight : prevScroll
    }
  }

  function reloadFile() {
    conflict = false
    dirty = false
    const sel = cockpit.selected
    if (sel) {
      const my = ++token
      void load(sel, my)
    }
  }

  // Monotonic token: a stale fetch (older selection) must not overwrite the
  // view of a newer selection. Each effect run bumps it; load() bails if a
  // newer run started while it was awaiting.
  let token = 0

  $effect(() => {
    const sel = cockpit.selected
    // 离开自动 flush(guardDirty):切文件把残余改动静默写掉,不弹框。
    // untrack:这里读 dirty 只为守卫,绝不能让 dirty 变化触发本效果重跑
    // (否则每敲一个字就重新 load 把编辑态冲掉)。
    untrack(() => {
      if (dirty && editPath && editPath !== sel?.path) void flush()
    })
    vtab = 'view' // reset to preview when the selection changes
    if (!sel) {
      view = null
      return
    }
    const my = ++token
    void load(sel, my)
  })

  // ── HTML 交互预览(承 FanBox 双缓冲零白闪):两个 iframe 轮换,
  //    后台帧载完再换前台;文件变更(watch)自动刷新。──────────────
  let hSrc = $state<[string, string]>(['', ''])
  let hActive = $state(0)
  let hVer = 0
  let lastAutoReload = 0

  function htmlUrl(): string {
    return cockpit.selected ? previewOriginUrl(cockpit.selected.path, ++hVer) : ''
  }

  function reloadHtml() {
    const next = (1 - hActive) as 0 | 1
    const url = htmlUrl()
    hSrc = next === 0 ? [url, hSrc[1]] : [hSrc[0], url]
  }

  function onFrameLoad(idx: number) {
    // 后台帧就绪才切前台 → 不白闪
    if (hSrc[idx] && idx !== hActive) hActive = idx
  }

  // 选中的 html 被写入(agent/外部)→ 自动刷新;300ms 抑抖
  $effect(() => {
    const sel = cockpit.selected
    if (!sel || view?.kind !== 'html') return
    if (cockpit.changedPaths.has(sel.path)) {
      const now = Date.now()
      if (now - lastAutoReload > 300) {
        lastAutoReload = now
        reloadHtml()
      }
    }
  })

  async function load(sel: Entry, my: number) {
    const kind = previewKind(sel.ext)
    loading = true
    try {
      if (kind === 'markdown' || kind === 'code' || kind === 'html') {
        const res = await fetch(`/api/cockpit/text?path=${encodeURIComponent(sel.path)}`)
        if (my !== token) return
        if (!res.ok) throw new Error()
        const body = await res.json()
        if (my !== token) return
        if (kind === 'markdown') {
          const rendered = await marked.parse(body.content)
          if (my !== token) return
          view = {
            kind,
            entry: sel,
            html: DOMPurify.sanitize(rendered),
            text: body.content,
            truncated: body.truncated,
            mtime: body.mtime,
          }
        } else {
          view = { kind, entry: sel, text: body.content, truncated: body.truncated, mtime: body.mtime }
        }
        if (!body.truncated) startEditSession(view)
        if (kind === 'html') {
          hActive = 0
          hSrc = [previewOriginUrl(sel.path, ++hVer), '']
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

<div class="preview" aria-label="预览" bind:this={previewEl}>
  {#if !view}
    <p class="empty">选择一个文件以预览</p>
  {:else if loading}
    <p class="empty">加载中…</p>
  {:else if view.error}
    <p class="error">{view.error}</p>
  {:else}
    <header class="title" title={view.entry.path}>{view.entry.name}</header>
    {#if view.truncated}<p class="trunc">（已截断，仅显示前 1MB）</p>{/if}

    {#if view.kind === 'markdown' || view.kind === 'code' || view.kind === 'html'}
      <div class="vtabs">
        <button class:active={vtab === 'view'} onclick={() => (vtab = 'view')}>{view.kind === 'code' ? '编辑' : '预览'}</button>
        {#if (view.kind === 'markdown' || view.kind === 'html') && !view.truncated}
          <button class:active={vtab === 'src'} onclick={() => (vtab = 'src')}>源码</button>
        {/if}
        <button class:active={vtab === 'diff'} onclick={() => (vtab = 'diff')}>Diff</button>
        <span class="savest" class:warn={conflict || !!saveErr}>
          {#if conflict}文件被外部修改{:else if saveErr}{saveErr}{:else}{savedLabel}{/if}
        </span>
        {#if conflict}
          <button class="cbtn" onclick={reloadFile}>重载</button>
          <button class="cbtn ow" onclick={() => void flush(true)}>覆盖</button>
        {/if}
      </div>
    {/if}

    {#if vtab === 'diff' && (view.kind === 'markdown' || view.kind === 'code' || view.kind === 'html')}
      <!-- Monaco is heavy: load DiffView lazily so it's code-split out of the
           main bundle and never imported in the test/jsdom module graph. -->
      {#await import('./DiffView.svelte') then mod}
        {@const DiffView = mod.default}
        <DiffView path={view.entry.path} ext={view.entry.ext} />
      {:catch}
        <p class="error">diff 加载失败</p>
      {/await}
    {:else if (view.kind === 'markdown' || view.kind === 'html') && vtab === 'src' && !view.truncated}
      <textarea class="codeedit" class:fpulse={followPulse} bind:this={editEl} value={editText} use:editInput aria-label="编辑源码" spellcheck="false"></textarea>
    {:else if view.kind === 'html'}
      <!-- 隔离源(独立 origin=沙箱本体)+ 双缓冲不白闪(承 FanBox) -->
      <div class="htmlwrap">
        <div class="htmlbar">
          <button class="hbtn" onclick={reloadHtml}>↻ 刷新</button>
          <button class="hbtn" onclick={() => window.open(previewOriginUrl(view!.entry.path, Date.now()), '_blank')}>⧉ 新窗</button>
          <span class="hsrc">127.0.0.1:8770 · 隔离源</span>
        </div>
        <div class="hstage">
          {#each [0, 1] as idx (idx)}
            {#if hSrc[idx]}
              <iframe
                class="hframe"
                class:front={hActive === idx}
                title={`HTML 预览 ${idx}`}
                src={hSrc[idx]}
                sandbox="allow-scripts allow-same-origin allow-forms"
                onload={() => onFrameLoad(idx)}
              ></iframe>
            {/if}
          {/each}
        </div>
      </div>
    {:else if view.kind === 'markdown'}
      <!-- sanitized via DOMPurify above -->
      <div class="md">{@html view.html}</div>
    {:else if view.kind === 'code' && !view.truncated}
      <!-- 预览即编辑(FanBox):代码/纯文本打开就是可编辑态 -->
      <textarea class="codeedit" class:fpulse={followPulse} bind:this={editEl} value={editText} use:editInput aria-label="编辑内容" spellcheck="false"></textarea>
    {:else if view.kind === 'code'}
      <pre class="code">{view.text}</pre>
    {:else if view.kind === 'image'}
      <!-- 先走 w=1000 缩略图秒开(heic/tiff 也能看),失败回退原图(承 FanBox) -->
      {@const imgPath = view.entry.path}
      <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
      <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
      <img
        class="img zoomable"
        src={`/api/cockpit/thumb?path=${encodeURIComponent(imgPath)}&w=1000`}
        alt={view.entry.name}
        onclick={() => (cockpit.lightboxPath = imgPath)}
        onerror={(ev) => {
          const img = ev.currentTarget as HTMLImageElement
          const raw = rawUrl(imgPath)
          if (!img.src.endsWith(raw)) img.src = raw
        }}
      />
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
  .savest {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .3px;
    color: var(--t4);
    align-self: center;
    font-variant-numeric: tabular-nums;
  }
  .savest.warn {
    color: var(--orange);
  }
  .cbtn {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 1px 7px;
    cursor: pointer;
    align-self: center;
  }
  .cbtn:hover {
    color: var(--t1);
  }
  .cbtn.ow {
    color: var(--orange);
    border-color: var(--orange);
  }
  .codeedit {
    width: 100%;
    min-height: 60vh;
    box-sizing: border-box;
    background: var(--tile);
    border: 1px solid var(--hair);
    color: var(--t2);
    font: 12px var(--mono);
    line-height: 1.5;
    padding: 12px;
    resize: vertical;
    white-space: pre;
  }
  .codeedit.fpulse {
    animation: fpulse .7s ease-out;
  }
  @keyframes fpulse {
    0% { border-color: var(--green); box-shadow: 0 0 0 1px var(--green); }
    100% { border-color: var(--hair); box-shadow: none; }
  }
  .codeedit:focus {
    outline: none;
    border-color: var(--acc-ink);
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
  .htmlwrap {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }
  .htmlbar {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0 6px;
    flex: none;
  }
  .hbtn {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: .5px;
    color: var(--t3);
    background: transparent;
    border: 1px solid var(--line);
    padding: 3px 8px;
    cursor: pointer;
  }
  .hbtn:hover {
    color: var(--t1);
    border-color: var(--acc);
  }
  .hsrc {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    letter-spacing: .5px;
  }
  .hstage {
    flex: 1;
    min-height: 0;
    position: relative;
    border: 1px solid var(--hair);
    background: #fff; /* 页面自己的底色;白是网页世界的默认 */
  }
  .hframe {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    border: 0;
    visibility: hidden;
  }
  .hframe.front {
    visibility: visible;
  }
  .img {
    max-width: 100%;
    height: auto;
  }
  .img.zoomable {
    cursor: zoom-in;
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
