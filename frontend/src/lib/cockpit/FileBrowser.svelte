<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import { cockpit } from './cockpit.svelte'
  import { iconFor } from './fileIcons'
  import { previewKind } from './previewKind'
  import { layout } from '../layout.svelte'
  import { localHHMM } from '../time'

  let pathInput = $state('')

  // ── 右键菜单 + 自绘对话框(承 FanBox app:1384-1453/1638-1677) ──────────
  interface Menu {
    x: number
    y: number
    entry: import('./cockpit.svelte').Entry | null // null = 空白处
  }
  let menu = $state<Menu | null>(null)
  // 键盘光标(承 FanBox:光标≠选中,Enter 才打开;目录不因光标扫过而误入)
  let cursorIdx = $state(-1)
  let gridEl = $state<HTMLElement | null>(null)
  let inboxOpen = $state(false)
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

  // 网格实测列数(offsetTop 同第一行的个数;列表=1)
  function measureCols(): number {
    if (cockpit.viewMode === 'list' || !gridEl) return 1
    const items = gridEl.querySelectorAll('.card')
    if (!items.length) return 1
    const top0 = (items[0] as HTMLElement).offsetTop
    let c = 0
    for (const it of items) {
      if ((it as HTMLElement).offsetTop === top0) c++
      else break
    }
    return Math.max(1, c)
  }

  function moveCursor(d: number) {
    const n = sortedEntries.length
    if (!n) return
    cursorIdx = cursorIdx < 0 ? 0 : Math.min(n - 1, Math.max(0, cursorIdx + d))
    // 光标滚到可视区
    const el = document.querySelector(`[data-idx="${cursorIdx}"]`)
    el?.scrollIntoView({ block: 'nearest' })
  }

  function cursorEnter() {
    const e = sortedEntries[cursorIdx]
    if (!e) return
    cockpit.select(e) // dir→browse,file→选中预览(store 语义)
  }

  function parentUp() {
    if (parent) void cockpit.browse(parent)
  }

  // Esc 分层退出 + 主区键盘导航(承 FanBox app:2152-2185,一次退一层)
  function onWinKey(e: KeyboardEvent) {
    // ① 右键菜单
    if (e.key === 'Escape' && menu) {
      closeMenu()
      return
    }
    // ② 自绘对话框
    if (e.key === 'Escape' && dialog) {
      dialog = null
      return
    }
    // ③ 命令面板自管(开着时这里不抢)
    if (layout.paletteOpen) return
    // ④ 灯箱(Lightbox 组件自己也处理,这里让位)
    if (cockpit.lightboxPath) return
    const ae = document.activeElement
    const inInput =
      !!ae && (['INPUT', 'TEXTAREA', 'SELECT'].includes(ae.tagName) || (ae as HTMLElement).isContentEditable)
    // ⑤ 输入框里 Esc 先退出输入,别越级关预览
    if (e.key === 'Escape' && inInput) {
      ;(ae as HTMLElement).blur()
      return
    }
    // ⑥ 关预览(取消选中)
    if (e.key === 'Escape' && cockpit.selected) {
      cockpit.selected = null
      return
    }
    if (inInput || !cockpit.cwd) return
    // 主区键盘导航
    const cols = measureCols()
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      moveCursor(cols)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      moveCursor(-cols)
    } else if (e.key === 'ArrowRight') {
      e.preventDefault()
      moveCursor(1)
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault()
      moveCursor(-1)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      cursorEnter()
    } else if ((e.metaKey || e.ctrlKey) && (e.key === 'Backspace' || e.key === 'Delete')) {
      e.preventDefault()
      const it = sortedEntries[cursorIdx]
      if (it) askTrash(it)
    } else if (e.key === 'Backspace') {
      e.preventDefault()
      parentUp()
    } else if (e.key === 'F2') {
      e.preventDefault()
      const it = sortedEntries[cursorIdx]
      if (it) askRename(it.path, it.name)
    }
  }

  // 目录变了 → 光标复位
  $effect(() => {
    void cockpit.entries
    cursorIdx = -1
  })

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

  // 排序:目录永远在前;name=zh locale+numeric,mtime/size 降序(承 FanBox)
  const sortedEntries = $derived(
    [...cockpit.entries].sort((a, b) => {
      if (a.is_dir !== b.is_dir) return a.is_dir ? -1 : 1
      if (cockpit.sortKey === 'mtime') return (b.mtime ?? 0) - (a.mtime ?? 0)
      if (cockpit.sortKey === 'size') return b.size - a.size
      return a.name.localeCompare(b.name, 'zh', { numeric: true, sensitivity: 'base' })
    }),
  )

  // 双击分流(承 FanBox onItemOpen):图片→灯箱;pdf/压缩包/未知→系统 App;
  // 文本/代码保持分栏预览(全屏预览在 P2 账上)。
  // 拖拽源:路径喂终端;图片额外带 text/html 原路径(否则浏览器抓低清 thumb 链接)
  function onDragStart(ev: DragEvent, e: import('./cockpit.svelte').Entry) {
    if (!ev.dataTransfer) return
    ev.dataTransfer.setData('text/plain', e.path)
    ev.dataTransfer.setData('application/x-helm-path', e.path)
    if (!e.is_dir && THUMB_EXTS.has(e.ext)) {
      ev.dataTransfer.setData('text/html', `<img src="${encodeURI(e.path)}" alt="${e.name}">`)
    }
    ev.dataTransfer.effectAllowed = 'copy'
  }

  function onOpen(e: import('./cockpit.svelte').Entry) {
    if (e.is_dir) return
    const k = previewKind(e.ext)
    if (k === 'image') {
      cockpit.select(e)
      cockpit.lightboxPath = e.path
    } else if (k === 'pdf' || k === 'zip' || k === 'none') {
      void cockpit.openWithSystem(e.path)
    }
  }

  const THUMB_EXTS = new Set(['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tif', 'tiff'])
  const thumbW = $derived(cockpit.gridSize === 'sm' ? 200 : cockpit.gridSize === 'lg' ? 360 : 280)
  function thumbUrl(path: string): string {
    return `/api/cockpit/thumb?path=${encodeURIComponent(path)}&w=${thumbW}`
  }

  function fmtTime(mtime?: number): string {
    if (!mtime) return '—'
    const d = new Date(mtime * 1000)
    const p = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
  }

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

  {#if cockpit.cwd}
    <div class="viewbar">
      <span class="vseg" role="tablist" aria-label="视图">
        <button class="vact" class:on={cockpit.viewMode === 'grid'} role="tab" aria-selected={cockpit.viewMode === 'grid'} onclick={() => cockpit.setViewMode('grid')}>网格</button>
        <button class="vact" class:on={cockpit.viewMode === 'list'} role="tab" aria-selected={cockpit.viewMode === 'list'} onclick={() => cockpit.setViewMode('list')}>列表</button>
      </span>
      {#if cockpit.viewMode === 'grid'}
        <span class="vseg" role="radiogroup" aria-label="网格尺寸">
          {#each ['sm', 'md', 'lg'] as g (g)}
            <button class="vact" class:on={cockpit.gridSize === g} role="radio" aria-checked={cockpit.gridSize === g} onclick={() => cockpit.setGridSize(g as 'sm' | 'md' | 'lg')}>{g.toUpperCase()}</button>
          {/each}
        </span>
      {/if}
      <select
        class="vsel"
        aria-label="排序"
        value={cockpit.sortKey}
        onchange={(e) => cockpit.setSortKey((e.target as HTMLSelectElement).value as 'name' | 'mtime' | 'size')}
      >
        <option value="name">按名称</option>
        <option value="mtime">按修改时间</option>
        <option value="size">按大小</option>
      </select>
      <button class="vact inboxbtn" class:on={inboxOpen} onclick={() => (inboxOpen = !inboxOpen)} aria-label="变更收件箱">
        变更{cockpit.inbox.length ? ` ${cockpit.inbox.length}` : ''}
      </button>
      <label class="vhid">
        <input type="checkbox" class="vcbx" checked={cockpit.showHidden} onchange={() => void cockpit.toggleHidden()} aria-label="显示隐藏文件" />
        隐藏文件
      </label>
    </div>
  {/if}

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
    {#if cockpit.viewMode === 'list'}
      <div class="flist" role="table" aria-label="文件列表">
        <div class="fhead" role="row">
          <span class="fname">名称</span><span class="ftime">修改时间</span><span class="fsize">大小</span>
        </div>
        {#each sortedEntries as e, idx (e.path)}
          {@const ic = iconFor(e)}
          <button
            class="frow"
            data-idx={idx}
            draggable="true"
            ondragstart={(ev) => onDragStart(ev, e)}
            class:cursor={cursorIdx === idx}
            class:selected={cockpit.selected?.path === e.path}
            class:changed={cockpit.changedPaths.has(e.path)}
            onclick={() => cockpit.select(e)}
            ondblclick={() => onOpen(e)}
            oncontextmenu={(ev) => openMenu(ev, e)}
            role="row"
          >
            <span class="fname"><span class="icon" style="color:{ic.color}">{ic.glyph}</span> {e.name}
              {#if cockpit.changeHeat[e.path]}
                {@const h = cockpit.changeHeat[e.path]}
                <span class="chg inline" title={'刚变更:\n' + h.files.join('\n')} style={`--heat:${Math.min(1, 0.4 + h.count * 0.12).toFixed(2)}`}>{h.count > 1 ? `改·${h.count}` : '改'}</span>
              {/if}
            </span>
            <span class="ftime">{fmtTime(e.mtime)}</span>
            <span class="fsize">{e.is_dir ? '—' : fmtSize(e.size)}</span>
          </button>
        {/each}
      </div>
    {:else}
    <div class="grid g-{cockpit.gridSize}" bind:this={gridEl}>
      {#each sortedEntries as e, idx (e.path)}
        {@const ic = iconFor(e)}
        <button
          class="card"
          data-idx={idx}
          draggable="true"
          ondragstart={(ev) => onDragStart(ev, e)}
          class:cursor={cursorIdx === idx}
          class:selected={cockpit.selected?.path === e.path}
          class:changed={cockpit.changedPaths.has(e.path)}
          onclick={() => cockpit.select(e)}
          ondblclick={() => onOpen(e)}
          oncontextmenu={(ev) => openMenu(ev, e)}
        >
          {#if cockpit.changeHeat[e.path]}
            {@const h = cockpit.changeHeat[e.path]}
            <span class="chg" title={'刚变更:\n' + h.files.join('\n')} style={`--heat:${Math.min(1, 0.4 + h.count * 0.12).toFixed(2)}`}>
              {h.count > 1 ? `改·${h.count}` : '改'}
            </span>
          {/if}
          {#if !e.is_dir && THUMB_EXTS.has(e.ext)}
            <!-- 缩略图,失败回退字形不留裂图(承 FanBox) -->
            <img
              class="thumb"
              src={thumbUrl(e.path)}
              alt=""
              loading="lazy"
              onerror={(ev) => (ev.currentTarget as HTMLImageElement).classList.add('dead')}
            />
            <span class="icon thumbfall" style="color:{ic.color}">{ic.glyph}</span>
          {:else}
            <span class="icon" style="color:{ic.color}">{ic.glyph}</span>
          {/if}
          <span class="card-name" title={e.name}>{e.name}</span>
          <span class="meta">{e.is_dir ? '文件夹' : fmtSize(e.size)}</span>
        </button>
      {/each}
    </div>
    {/if}
  {/if}

  {#if inboxOpen}
    <div class="inbox" role="region" aria-label="变更收件箱">
      <div class="ih">
        <span>变更 / CHANGES({cockpit.inbox.length})</span>
        <button class="vact" onclick={() => cockpit.clearInbox()} disabled={!cockpit.inbox.length}>清空</button>
        <button class="vact" onclick={() => (inboxOpen = false)}>×</button>
      </div>
      {#if cockpit.inbox.length === 0}
        <p class="iempty">本会话还没有变更 — agent 写文件会记在这里。</p>
      {:else}
        {#each cockpit.inbox as it (it.path)}
          <button
            class="irow"
            onclick={() => {
              cockpit.openPath(it.path, false)
              inboxOpen = false
            }}
          >
            <span class="in">{it.name}</span>
            {#if it.count > 1}<span class="ic">×{it.count}</span>{/if}
            <span class="it">{localHHMM(new Date(it.ts).toISOString())}</span>
          </button>
        {/each}
      {/if}
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
  .grid.g-sm {
    grid-template-columns: repeat(auto-fill, minmax(96px, 1fr));
  }
  .grid.g-lg {
    grid-template-columns: repeat(auto-fill, minmax(156px, 1fr));
  }
  .viewbar {
    display: flex;
    align-items: center;
    gap: 14px;
    margin-bottom: 10px;
    flex-wrap: wrap;
  }
  .vseg {
    display: flex;
    gap: 6px;
  }
  .vact {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 2px 8px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .vact:hover {
    color: var(--t1);
  }
  .vact.on {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .vsel {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t3);
    font-family: var(--mono);
    font-size: 10px;
    padding: 2px 0 4px;
  }
  .vsel option {
    background: var(--panel);
    color: var(--t1);
  }
  .vsel:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .vhid {
    display: flex;
    align-items: center;
    gap: 6px;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    cursor: pointer;
    margin-left: auto;
  }
  .vcbx {
    appearance: none;
    width: 12px;
    height: 12px;
    border: 1.4px solid var(--t4);
    background: transparent;
    cursor: pointer;
    margin: 0;
  }
  .vcbx:checked {
    border-color: var(--acc-ink);
    background: var(--acc);
  }
  /* 列表视图:发丝行 + mono 列 */
  .flist {
    display: flex;
    flex-direction: column;
  }
  .fhead {
    display: grid;
    grid-template-columns: 1fr 150px 80px;
    gap: 10px;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    text-transform: uppercase;
    color: var(--t4);
    padding: 3px 6px 5px;
    border-bottom: 1px solid var(--hair);
  }
  .frow {
    display: grid;
    grid-template-columns: 1fr 150px 80px;
    gap: 10px;
    align-items: center;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    padding: 4px 6px;
    cursor: pointer;
    text-align: left;
    font-size: 12.5px;
    color: var(--t2);
  }
  .frow:hover {
    color: var(--t1);
  }
  .frow.selected {
    border-left: 2px solid var(--acc);
    padding-left: 4px;
  }
  .frow.changed {
    animation: flash 1.2s ease-out;
  }
  .frow .fname {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .frow .ftime,
  .frow .fsize,
  .fhead .ftime,
  .fhead .fsize {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
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
  /* 「改·N」热度徽章:绿光随 count 变强,4.5s 消退(承 FanBox --heat) */
  .chg {
    position: absolute;
    top: 4px;
    right: 4px;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--green);
    border: 1px solid var(--green);
    padding: 0 4px;
    background: var(--bg);
    box-shadow: 0 0 calc(var(--heat, .4) * 10px) rgba(52, 199, 89, calc(var(--heat, .4) * .8));
  }
  .chg.inline {
    position: static;
    margin-left: 6px;
  }
  .card {
    position: relative;
  }
  .inboxbtn.on {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .inbox {
    position: fixed;
    top: 70px;
    right: 16px;
    z-index: 55;
    width: 300px;
    max-height: 50vh;
    overflow: auto;
    background: var(--panel);
    border: 1px solid var(--line);
    padding: 8px 0;
  }
  .ih {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px 6px;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t3);
    border-bottom: 1px solid var(--hair);
  }
  .ih span {
    margin-right: auto;
  }
  .irow {
    display: flex;
    align-items: baseline;
    gap: 8px;
    width: 100%;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    padding: 5px 12px;
    cursor: pointer;
    text-align: left;
    font-size: 12px;
    color: var(--t2);
  }
  .irow:hover {
    color: var(--t1);
  }
  .irow .in {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .irow .ic {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--green);
    flex: none;
  }
  .irow .it {
    margin-left: auto;
    flex: none;
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .iempty {
    padding: 10px 12px;
    font-size: 12px;
    color: var(--t4);
  }
  .card.cursor,
  .frow.cursor {
    outline: 1px dashed var(--acc-ink);
    outline-offset: -1px;
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
  .thumb {
    width: 100%;
    height: 72px;
    object-fit: cover;
    display: block;
    background: var(--tile);
  }
  .grid.g-sm .thumb {
    height: 54px;
  }
  .grid.g-lg .thumb {
    height: 100px;
  }
  .thumb.dead {
    display: none;
  }
  .thumb:not(.dead) + .thumbfall {
    display: none;
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
