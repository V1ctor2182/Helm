<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import { cockpit } from './cockpit.svelte'
  import { iconFor } from './fileIcons'

  let pathInput = $state('')

  // ── 右键菜单 + 自绘对话框(承 FanBox app:1384-1453/1638-1677) ──────────
  interface Menu {
    x: number
    y: number
    entry: import('./cockpit.svelte').Entry | null // null = 空白处
  }
  let menu = $state<Menu | null>(null)
  interface Dialog {
    kind: 'rename' | 'newfile' | 'newdir' | 'trashdir'
    target?: string // rename/trashdir 的路径
    value: string
    label: string
  }
  let dialog = $state<Dialog | null>(null)

  function openMenu(e: MouseEvent, entry: Menu['entry']) {
    e.preventDefault()
    e.stopPropagation()
    // 钳制在窗口内(菜单约 180×窗高)
    const x = Math.min(e.clientX, window.innerWidth - 190)
    const y = Math.min(e.clientY, window.innerHeight - 230)
    menu = { x, y, entry }
  }

  function closeMenu() {
    menu = null
  }

  function onWinKey(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      if (dialog) dialog = null
      else if (menu) closeMenu()
    }
  }

  async function copyPath(p: string) {
    try {
      await navigator.clipboard.writeText(p)
    } catch {
      /* clipboard 不可用忽略 */
    }
    closeMenu()
  }

  function askRename(path: string, current: string) {
    closeMenu()
    dialog = { kind: 'rename', target: path, value: current, label: '重命名为' }
  }

  function askTrash(entry: NonNullable<Menu['entry']>) {
    closeMenu()
    if (entry.is_dir) {
      // 文件夹弹一次轻确认;文件秒删(废纸篓可恢复)
      dialog = { kind: 'trashdir', target: entry.path, value: '', label: `丢进废纸篓:${entry.name}?` }
    } else {
      void cockpit.trash(entry.path)
    }
  }

  async function dialogSubmit() {
    const d = dialog
    if (!d) return
    if (d.kind === 'rename' && d.target) await cockpit.renameEntry(d.target, d.value)
    else if (d.kind === 'newfile') await cockpit.newFile(d.value)
    else if (d.kind === 'newdir') await cockpit.mkdir(d.value)
    else if (d.kind === 'trashdir' && d.target) await cockpit.trash(d.target)
    dialog = null
  }

  onMount(() => {
    void cockpit.loadProjects()
  })

  onDestroy(() => {
    cockpit.stopWatching()
  })

  function openInput(e: Event) {
    e.preventDefault()
    if (pathInput.trim()) void cockpit.openProject(pathInput.trim())
  }

  function parentOf(p: string): string | null {
    const i = p.replace(/\/+$/, '').lastIndexOf('/')
    return i > 0 ? p.slice(0, i) : i === 0 ? '/' : null
  }

  const parent = $derived(cockpit.cwd ? parentOf(cockpit.cwd) : null)

  function fmtSize(n: number): string {
    if (n < 1024) return `${n} B`
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`
    return `${(n / 1024 / 1024).toFixed(1)} MB`
  }
</script>

<svelte:window onkeydown={onWinKey} onmousedown={() => menu && closeMenu()} />

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="browser" role="region" aria-label="文件浏览" oncontextmenu={(e) => cockpit.cwd && openMenu(e, null)}>
  <form class="bar" onsubmit={openInput}>
    {#if cockpit.cwd}
      <button
        type="button"
        class="up"
        disabled={!parent}
        onclick={() => parent && cockpit.browse(parent)}>↑</button
      >
      <span class="cwd" title={cockpit.cwd}>{cockpit.cwd}</span>
      <button
        type="button"
        class="follow"
        class:on={cockpit.followMode}
        aria-pressed={cockpit.followMode}
        title="跟随模式：自动预览 agent 正在改的文件"
        onclick={() => cockpit.toggleFollow()}>跟随{cockpit.followMode ? ' ●' : ''}</button
      >
    {:else}
      <input
        bind:value={pathInput}
        placeholder="打开项目文件夹（绝对路径，⏎）"
        aria-label="项目路径"
      />
      <button type="submit">打开</button>
    {/if}
  </form>

  {#if cockpit.error}
    <p class="error">{cockpit.error}</p>
  {/if}

  {#if !cockpit.cwd}
    <h3 class="section">最近项目</h3>
    {#if cockpit.projects.length === 0}
      <p class="muted">还没有项目 — 在上方打开一个文件夹。</p>
    {:else}
      <div class="grid">
        {#each cockpit.projects as p (p.path)}
          <button class="card project" onclick={() => cockpit.openProject(p.path)}>
            <span class="card-name">{p.name}</span>
            <span class="badges">
              {#each p.badges as b (b)}<span class="badge">{b}</span>{/each}
            </span>
          </button>
        {/each}
      </div>
    {/if}
  {:else}
    <div class="grid">
      {#each cockpit.entries as e (e.path)}
        {@const ic = iconFor(e)}
        <button
          class="card"
          class:selected={cockpit.selected?.path === e.path}
          class:changed={cockpit.changedPaths.has(e.path)}
          onclick={() => cockpit.select(e)}
          oncontextmenu={(ev) => openMenu(ev, e)}
        >
          <span class="icon" style="color:{ic.color}">{ic.glyph}</span>
          <span class="card-name" title={e.name}>{e.name}</span>
          <span class="meta">{e.is_dir ? '文件夹' : fmtSize(e.size)}</span>
        </button>
      {/each}
    </div>
  {/if}

  {#if menu}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="ctx" style={`left:${menu.x}px;top:${menu.y}px`} onmousedown={(e) => e.stopPropagation()}>
      {#if menu.entry}
        {@const en = menu.entry}
        <button class="mi" onclick={() => { cockpit.select(en); closeMenu() }}>{en.is_dir ? '打开' : '预览'}</button>
        <button class="mi" onclick={() => copyPath(en.path)}>复制路径</button>
        <button class="mi" onclick={() => askRename(en.path, en.name)}>重命名</button>
        <div class="msep"></div>
        <button class="mi danger" onclick={() => askTrash(en)}>丢进废纸篓</button>
      {:else}
        <button class="mi" onclick={() => { closeMenu(); dialog = { kind: 'newfile', value: '', label: '新建文件' } }}>新建文件</button>
        <button class="mi" onclick={() => { closeMenu(); dialog = { kind: 'newdir', value: '', label: '新建文件夹' } }}>新建文件夹</button>
        {#if cockpit.cwd}<button class="mi" onclick={() => copyPath(cockpit.cwd!)}>复制当前路径</button>{/if}
      {/if}
    </div>
  {/if}

  {#if dialog}
    <div class="dlg">
      <div class="dl">{dialog.label}</div>
      {#if dialog.kind !== 'trashdir'}
        <!-- svelte-ignore a11y_autofocus -->
        <input
          class="di"
          bind:value={dialog.value}
          autofocus
          aria-label={dialog.label}
          onkeydown={(e) => {
            if (e.key === 'Enter') void dialogSubmit()
          }}
        />
      {/if}
      <div class="da">
        <button class="act pri" onclick={dialogSubmit} disabled={dialog.kind !== 'trashdir' && !dialog.value.trim()}>
          {dialog.kind === 'trashdir' ? '丢进废纸篓' : '确定'}
        </button>
        <button class="act" onclick={() => (dialog = null)}>取消</button>
      </div>
    </div>
  {/if}
</div>

<style>
  .ctx {
    position: fixed;
    z-index: 60;
    min-width: 150px;
    background: var(--panel);
    border: 1px solid var(--line);
    padding: 4px 0;
  }
  .mi {
    display: block;
    width: 100%;
    text-align: left;
    background: transparent;
    border: 0;
    padding: 6px 14px;
    font-size: 12.5px;
    color: var(--t2);
    cursor: pointer;
  }
  .mi:hover {
    color: var(--t1);
    background: var(--tile);
  }
  .mi.danger:hover {
    color: var(--red);
  }
  .msep {
    height: 1px;
    background: var(--hair);
    margin: 4px 0;
  }
  .dlg {
    position: fixed;
    z-index: 61;
    top: 20%;
    left: 50%;
    transform: translateX(-50%);
    min-width: 300px;
    background: var(--panel);
    border: 1px solid var(--line);
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .dl {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t2);
  }
  .di {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-size: 13px;
    padding: 3px 0 6px;
  }
  .di:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .da {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }
  .act {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 10px;
    cursor: pointer;
  }
  .act:hover:not(:disabled) {
    color: var(--t1);
  }
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
    cursor: default;
  }

  .browser {
    height: 100%;
    overflow: auto;
    padding: 14px;
    box-sizing: border-box;
    font-family: var(--sans);
    color: var(--t2);
  }
  .bar {
    display: flex;
    gap: 10px;
    align-items: center;
    margin-bottom: 12px;
  }
  .bar input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 12px;
    padding: 4px 0 7px;
    min-width: 0;
  }
  .bar input::placeholder {
    color: var(--t4);
    font-family: var(--sans);
    font-size: 13px;
  }
  .bar input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .bar button {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 10px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .bar button:hover:not(:disabled) {
    color: var(--t1);
  }
  .up {
    padding: 4px 8px;
  }
  .up:disabled {
    opacity: 0.4;
    cursor: default;
  }
  .cwd {
    color: var(--t3);
    font-family: var(--mono);
    font-size: 11px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .error {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
  }
  .section {
    margin: 4px 0 10px;
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--t3);
    font-weight: 700;
  }
  .muted {
    color: var(--t4);
    font-size: 13px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 8px;
  }
  /* 文件瓦片:1px 线框、零圆角(仪表瓦片,非填充卡) */
  .card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
    border: 1px solid var(--hair);
    background: transparent;
    padding: 10px 11px;
    cursor: pointer;
    text-align: left;
    min-height: 72px;
    transition: border-color .12s var(--ease);
  }
  .card:hover {
    border-color: var(--line);
  }
  .card.selected {
    border-color: var(--acc-ink);
  }
  .card.changed {
    animation: flash 1.2s ease-out;
  }
  @keyframes flash {
    0% {
      border-color: var(--green);
      box-shadow: 0 0 0 1px var(--green);
    }
    100% {
      border-color: var(--hair);
      box-shadow: none;
    }
  }
  .follow {
    margin-left: auto;
    flex: none;
  }
  .follow.on {
    border-color: var(--green) !important;
    color: var(--green) !important;
  }
  .icon {
    font-family: var(--mono);
    font-weight: 700;
    font-size: 13px;
  }
  .card-name {
    font-size: 12.5px;
    color: var(--t2);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
  }
  .card.selected .card-name {
    color: var(--t1);
  }
  .meta {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .badges {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .badge {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    padding: 0 4px;
  }
</style>
