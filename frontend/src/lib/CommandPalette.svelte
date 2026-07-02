<script lang="ts">
  import { commands } from './commands.svelte'
  import { layout } from './layout.svelte'
  import { cockpit } from './cockpit/cockpit.svelte'

  let query = $state('')
  let selected = $state(0)
  let inputEl = $state<HTMLInputElement>()

  // ── 文件/内容搜索(承 FanBox ⌘K:文件名模糊 + 「内容:」全文,150ms 防抖,
  //    Tab 切 当前目录/全机 范围)──────────────────────────────────────────
  interface FileHit {
    kind: 'file' | 'hit'
    name: string
    path: string
    is_dir: boolean
    line?: string
  }
  let fileHits = $state<FileHit[]>([])
  let truncated = $state(false)
  let scope = $state<'cwd' | 'home'>('cwd')
  let searchTimer: ReturnType<typeof setTimeout> | null = null
  let searchToken = 0

  const contentMode = $derived(/^(内容:|content:)/i.test(query.trim()))
  const searchQ = $derived(query.trim().replace(/^(内容:|content:)/i, '').trim())
  const rootLabel = $derived(scope === 'cwd' && cockpit.cwd ? '当前目录' : '全机(~)')

  // 内容模式不掺命令;普通模式命令在前、文件命中在后
  const cmdResults = $derived(contentMode ? [] : commands.search(query))
  const combinedLen = $derived(cmdResults.length + fileHits.length)

  $effect(() => {
    const open = layout.paletteOpen
    const q = searchQ
    const mode = contentMode ? 'content' : 'name'
    const root = scope === 'cwd' && cockpit.cwd ? cockpit.cwd : '~'
    if (searchTimer) clearTimeout(searchTimer)
    if (!open || !q) {
      fileHits = []
      truncated = false
      return
    }
    const my = ++searchToken
    searchTimer = setTimeout(async () => {
      try {
        const res = await fetch(
          `/api/cockpit/search?q=${encodeURIComponent(q)}&root=${encodeURIComponent(root)}&mode=${mode}`,
        )
        if (my !== searchToken || !res.ok) return
        const body = (await res.json()) as {
          results: { name?: string; path: string; is_dir?: boolean; line?: string }[]
          truncated: boolean
        }
        if (my !== searchToken) return
        fileHits = body.results.slice(0, 12).map((r) => ({
          kind: mode === 'content' ? 'hit' : 'file',
          name: r.name ?? (r.path.split('/').pop() || r.path),
          path: r.path,
          is_dir: r.is_dir ?? false,
          line: r.line,
        }))
        truncated = body.truncated
      } catch {
        /* 搜索失败静默:命令结果仍可用 */
      }
    }, 150)
  })

  function shortPath(p: string): string {
    const parts = p.split('/').filter(Boolean)
    return parts.slice(-3, -1).join('/') || '/'
  }

  // Focus on open; reset query/selection on close.
  $effect(() => {
    if (layout.paletteOpen) {
      inputEl?.focus()
    } else {
      query = ''
      selected = 0
      fileHits = []
    }
  })

  // Keep the highlighted row within range as results shrink.
  $effect(() => {
    if (selected > combinedLen - 1) selected = Math.max(0, combinedLen - 1)
  })

  function runAt(i: number) {
    if (i < cmdResults.length) {
      const cmd = cmdResults[i]
      if (!cmd) return
      layout.closePalette()
      cmd.run()
      return
    }
    const hit = fileHits[i - cmdResults.length]
    if (!hit) return
    layout.closePalette()
    layout.setMode('cockpit')
    cockpit.openPath(hit.path, hit.is_dir)
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      layout.closePalette()
    } else if (e.key === 'Tab') {
      e.preventDefault()
      scope = scope === 'cwd' ? 'home' : 'cwd'
    } else if (e.key === 'ArrowDown') {
      e.preventDefault()
      selected = Math.min(selected + 1, combinedLen - 1)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      selected = Math.max(selected - 1, 0)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      runAt(selected)
    }
  }
</script>

{#if layout.paletteOpen}
  <!-- Backdrop is a real button so outside-click + keyboard both dismiss; the
       palette is a sibling (not nested) to avoid interactive nesting. -->
  <button class="overlay" aria-label="关闭命令面板" onclick={() => layout.closePalette()}
  ></button>
  <div class="palette" role="dialog" aria-modal="true" aria-label="命令面板">
    <input
      bind:this={inputEl}
      bind:value={query}
      {onkeydown}
      placeholder="输入命令或文件名…  「内容:」全文搜索 · Tab 切范围 · ⏎ 执行"
      aria-label="命令"
    />
    <div class="scopebar">
      <span class="scopelabel">范围 {rootLabel}(Tab 切换)</span>
      {#if truncated}<span class="trunc">结果不完整 — 换更具体关键词或缩小范围</span>{/if}
    </div>
    <ul role="listbox" aria-label="命令结果">
      {#each cmdResults as cmd, i (cmd.id)}
        <li role="option" aria-selected={i === selected} class:sel={i === selected}>
          <button class="row" onclick={() => runAt(i)} onmouseenter={() => (selected = i)}>
            <span class="title">{cmd.title}</span>
            <span class="group">{cmd.group}</span>
          </button>
        </li>
      {/each}
      {#each fileHits as hit, j (hit.path + (hit.line ?? ''))}
        {@const i = cmdResults.length + j}
        <li role="option" aria-selected={i === selected} class:sel={i === selected}>
          <button class="row" onclick={() => runAt(i)} onmouseenter={() => (selected = i)}>
            <span class="title">
              {hit.name}
              {#if hit.line}<span class="hitline">{hit.line}</span>{/if}
            </span>
            <span class="group">{hit.kind === 'hit' ? 'HIT' : hit.is_dir ? 'DIR' : 'FILE'} · {shortPath(hit.path)}</span>
          </button>
        </li>
      {/each}
      {#if combinedLen === 0}
        <li class="empty">{searchQ ? '无匹配' : '无匹配命令'}</li>
      {/if}
    </ul>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    border: 0;
    padding: 0;
    background: rgba(0, 0, 0, 0.5);
    -webkit-backdrop-filter: blur(6px);
    backdrop-filter: blur(6px);
    cursor: default;
    z-index: 100;
  }
  .palette {
    position: fixed;
    top: 18vh;
    left: 50%;
    transform: translateX(-50%);
    width: min(560px, 92vw);
    background: var(--chrome);
    border: 1px solid var(--line);
    border-radius: 12px;
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.55);
    z-index: 101;
    overflow: hidden;
    font-family: var(--sans);
  }
  input {
    width: 100%;
    border: 0;
    border-bottom: 1px solid var(--hair);
    background: transparent;
    color: var(--t1);
    caret-color: var(--acc);
    padding: 14px 16px;
    font-size: 15px;
    font-family: var(--sans);
    outline: none;
    box-sizing: border-box;
  }
  input::placeholder {
    color: var(--t4);
  }
  .scopebar {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding: 5px 16px 0;
  }
  .scopelabel {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
  }
  .trunc {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--orange);
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 6px;
    max-height: 320px;
    overflow-y: auto;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 10px;
    width: 100%;
    border: 0;
    background: transparent;
    color: var(--t2);
    padding: 9px 10px;
    border-radius: 8px;
    cursor: pointer;
    text-align: left;
    font-size: 14px;
  }
  .row .title {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .hitline {
    display: block;
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t4);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  li.sel .row {
    background: color-mix(in srgb, var(--acc) 14%, transparent);
    color: var(--t1);
  }
  .group {
    flex: none;
    color: var(--t4);
    font-size: 11px;
    font-family: var(--mono);
    letter-spacing: .3px;
  }
  .empty {
    color: var(--t4);
    padding: 12px;
    font-size: 14px;
  }
</style>
