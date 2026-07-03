<script lang="ts">
  // Dock 宿主(用户拍板:全模块拖拽吸附)。渲染三 zone 网格 + tab 栈 + 分隔条;
  // 四个模块组件只挂载一次,换 zone 靠 appendChild 迁移 DOM(xterm 的 WS/缓冲
  // 不能因布局调整而断);拖标题 tab → zone 高亮 → 松手吸附。皮肤全 token。
  import { dock, MODULE_LABEL } from './dock.svelte'
  import type { ModuleId, ZoneId } from './dock.svelte'
  import { untrack } from 'svelte'
  import { cockpit } from './cockpit.svelte'
  import FileBrowser from './FileBrowser.svelte'
  import PreviewPane from './PreviewPane.svelte'
  import Terminal from './terminal/Terminal.svelte'
  import AgentView from '../orchestration/AgentView.svelte'

  const MODS: ModuleId[] = ['files', 'preview', 'terminal', 'agent']
  const ZONES: ZoneId[] = ['main', 'right', 'bottom']

  const l = $derived(dock.layout)
  const rightShown = $derived(l.zones.right.length > 0)
  const bottomShown = $derived(l.zones.bottom.length > 0)

  // 拖拽中给空/折叠 zone 撑出最小落区——尺寸为 0 就永远拖不进去
  const cols = $derived.by(() => {
    if (!rightShown) return dock.dragging ? 'minmax(0,1fr) 0 120px' : 'minmax(0,1fr) 0 0'
    if (l.collapsed.right) return `minmax(0,1fr) 0 ${dock.dragging ? '120px' : '26px'}`
    return `minmax(0,1fr) 5px ${l.rightW}px`
  })
  const rows = $derived.by(() => {
    if (!bottomShown) return dock.dragging ? 'minmax(0,1fr) 0 90px' : 'minmax(0,1fr) 0 0'
    if (l.collapsed.bottom) return `minmax(0,1fr) 0 ${dock.dragging ? '90px' : '28px'}`
    return `minmax(0,1fr) 5px ${l.bottomH}px`
  })

  let rootEl = $state<HTMLElement | null>(null)
  // $state:zbody 折叠重建/首挂时 bind 赋值要能触发归位 effect
  const bodies = $state<Partial<Record<ZoneId, HTMLElement>>>({})
  const hosts = $state<Partial<Record<ModuleId, HTMLElement>>>({})

  // 模块归位:所在 zone 的 body 里(inactive=display:none 停靠原地不重挂)
  $effect(() => {
    void dock.layout
    let moved = false
    for (const m of MODS) {
      const host = hosts[m]
      const body = bodies[dock.zoneOf(m)]
      if (!host || !body) continue
      if (host.parentElement !== body) {
        body.appendChild(host)
        moved = true
      }
      host.style.display = dock.isVisible(m) ? '' : 'none'
    }
    // xterm 靠 window resize 重排;迁移/显隐后补一发让它 fit 新容器。
    // 必须挪出本次 flush(setTimeout):同步派发会让 xterm fit 的异常
    // 打断 Svelte 的 effect 队列,其他组件的模板更新全被吞掉。
    if (moved) setTimeout(() => window.dispatchEvent(new Event('resize')), 0)
  })

  // 选中文件 → 预览模块自动现身(按需语义并入 dock)。
  // untrack:本效果只跟 selected 走;reveal 读写 dock.layout,若被追踪
  // 会形成 layout→effect→layout 自激循环(Svelte 直接掐掉整棵 effect 树)。
  $effect(() => {
    const sel = cockpit.selected
    if (sel) untrack(() => dock.reveal('preview'))
  })

  // ── tab 拖拽吸附 ─────────────────────────────────────────────
  let dragStart: { x: number; y: number; mod: ModuleId } | null = null

  function zoneAt(x: number, y: number): ZoneId | null {
    if (!rootEl) return null
    for (const z of ZONES) {
      const el = rootEl.querySelector(`[data-zone="${z}"]`)
      if (!el) continue
      const r = el.getBoundingClientRect()
      if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) return z
    }
    return null
  }

  function tabDown(e: PointerEvent, mod: ModuleId) {
    dragStart = { x: e.clientX, y: e.clientY, mod }
    const move = (ev: PointerEvent) => {
      if (!dragStart) return
      if (!dock.dragging) {
        // 4px 阈值:超过才算拖,否则是点击切 tab
        if (Math.hypot(ev.clientX - dragStart.x, ev.clientY - dragStart.y) < 4) return
        dock.dragging = dragStart.mod
      }
      dock.hoverZone = zoneAt(ev.clientX, ev.clientY)
    }
    const up = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
      if (dock.dragging && dock.hoverZone) {
        dock.move(dock.dragging, dock.hoverZone)
      } else if (dragStart) {
        dock.activate(dock.zoneOf(dragStart.mod), dragStart.mod) // 点击=切 tab
      }
      dock.dragging = null
      dock.hoverZone = null
      dragStart = null
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }

  // ── 分隔条拖尺寸 ────────────────────────────────────────────
  function resizeDown(e: PointerEvent, which: 'right' | 'bottom') {
    e.preventDefault()
    const move = (ev: PointerEvent) => {
      const r = rootEl?.getBoundingClientRect()
      if (!r) return
      if (which === 'right') dock.resize('right', r.right - ev.clientX)
      else dock.resize('bottom', r.bottom - ev.clientY)
    }
    const up = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }

  function shortLabel(m: ModuleId): string {
    return MODULE_LABEL[m].split(' / ')[0]
  }
</script>

<div
  class="dockhost"
  class:dragging={dock.dragging !== null}
  bind:this={rootEl}
  style={`grid-template-columns:${cols};grid-template-rows:${rows}`}
>
  {#each ZONES as z (z)}
    {@const mods = l.zones[z]}
    <section
      class={`zone z-${z}`}
      class:droptarget={dock.hoverZone === z && dock.dragging !== null}
      class:zcollapsed={l.collapsed[z]}
      data-zone={z}
    >
      {#if l.collapsed[z] && z !== 'main'}
        <button class="strip" onclick={() => dock.toggleCollapse(z)}>
          {mods.map((m) => shortLabel(m)).join(' · ')} ⟩
        </button>
      {:else}
        <div class="ztabs">
          {#each mods as m (m)}
            <button
              class="ztab"
              class:on={l.active[z] === m}
              class:ghost={dock.dragging === m}
              onpointerdown={(e) => tabDown(e, m)}
            >
              {MODULE_LABEL[m]}
            </button>
          {/each}
          {#if z !== 'main' && mods.length > 0}
            <button class="zfold" aria-label={`折叠${z === 'right' ? '右栏' : '底栏'}`} onclick={() => dock.toggleCollapse(z)}>⟩</button>
          {/if}
        </div>
        <div class="zbody" bind:this={bodies[z]}></div>
      {/if}
      <div class="drophint">松手放到{z === 'main' ? '主区' : z === 'right' ? '右栏' : '底栏'}</div>
    </section>
  {/each}

  {#if rightShown && !l.collapsed.right}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div class="vres" role="separator" aria-orientation="vertical" aria-label="调右栏宽" onpointerdown={(e) => resizeDown(e, 'right')}></div>
  {/if}
  {#if bottomShown && !l.collapsed.bottom}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div class="hres" role="separator" aria-orientation="horizontal" aria-label="调底栏高" onpointerdown={(e) => resizeDown(e, 'bottom')}></div>
  {/if}

  <!-- 模块常驻宿主:首挂在此,随 zone 变化被 appendChild 迁走,永不销毁 -->
  <div class="parking" aria-hidden="false">
    <div class="modhost" bind:this={hosts.files}><FileBrowser /></div>
    <div class="modhost" bind:this={hosts.preview}><PreviewPane /></div>
    <div class="modhost" bind:this={hosts.terminal}>
      {#key cockpit.cwd}
        <Terminal />
      {/key}
    </div>
    <div class="modhost" bind:this={hosts.agent}><AgentView /></div>
  </div>
</div>

<style>
  .dockhost {
    display: grid;
    grid-template-areas:
      'main vres right'
      'hres vres right'
      'bottom vres right';
    height: 100%;
    min-height: 0;
    min-width: 0;
    position: relative;
    font-family: var(--sans);
    color: var(--t2);
  }
  .dockhost.dragging {
    cursor: grabbing;
    user-select: none;
  }
  .zone {
    position: relative;
    display: flex;
    flex-direction: column;
    min-height: 0;
    min-width: 0;
    overflow: hidden;
  }
  .z-main {
    grid-area: main;
  }
  .z-right {
    grid-area: right;
    border-left: 1px solid var(--hair);
  }
  .z-bottom {
    grid-area: bottom;
    border-top: 1px solid var(--hair);
  }
  .ztabs {
    display: flex;
    align-items: center;
    gap: 2px;
    border-bottom: 1px solid var(--hair);
    padding: 0 6px;
    flex: none;
  }
  .ztab {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--t4);
    background: transparent;
    border: 0;
    border-bottom: 2px solid transparent;
    padding: 6px 8px 5px;
    cursor: grab;
    white-space: nowrap;
  }
  .ztab:hover {
    color: var(--t1);
  }
  .ztab.on {
    color: var(--t1);
    border-bottom-color: var(--acc);
  }
  .ztab.ghost {
    opacity: .35;
  }
  .zfold {
    margin-left: auto;
    background: transparent;
    border: 0;
    color: var(--t4);
    font-family: var(--mono);
    font-size: 10px;
    cursor: pointer;
    padding: 4px 6px;
  }
  .zfold:hover {
    color: var(--t1);
  }
  .zbody {
    flex: 1;
    min-height: 0;
    position: relative;
  }
  .zbody > :global(.modhost) {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  .zbody > :global(.modhost > *) {
    flex: 1;
    min-height: 0;
  }
  /* 折叠竖/横条 */
  .strip {
    flex: 1;
    background: transparent;
    border: 0;
    color: var(--t4);
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 2px;
    cursor: pointer;
  }
  .z-right .strip {
    writing-mode: vertical-rl;
    padding: 10px 0;
  }
  .strip:hover {
    color: var(--acc-ink);
  }
  /* 吸附高亮 */
  .drophint {
    display: none;
  }
  .dockhost.dragging .zone:empty::after,
  .dockhost.dragging .z-right:not(:has(.ztabs)):not(:has(.strip))::after {
    content: '';
    position: absolute;
    inset: 3px;
    border: 1px dashed var(--hair);
    pointer-events: none;
  }
  .zone.droptarget::after {
    content: '';
    position: absolute;
    inset: 3px;
    border: 1px dashed var(--acc-ink);
    background: color-mix(in srgb, var(--acc) 7%, transparent);
    pointer-events: none;
    z-index: 30;
  }
  .zone.droptarget .drophint {
    display: block;
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 31;
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: .5px;
    color: var(--acc-ink);
    background: var(--bg);
    border: 1px solid var(--acc-ink);
    padding: 5px 10px;
    pointer-events: none;
  }
  /* 分隔条 */
  .vres {
    grid-area: vres;
    cursor: col-resize;
    background: transparent;
  }
  .hres {
    grid-area: hres;
    cursor: row-resize;
    background: transparent;
  }
  .vres:hover,
  .hres:hover {
    background: var(--acc);
    opacity: .5;
  }
  /* 常驻停车场:自身不可见,子元素被迁走后这里是空的 */
  .parking {
    display: none;
  }
</style>
