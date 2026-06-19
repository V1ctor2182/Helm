<script lang="ts">
  import Rail from './Rail.svelte'
  import CommandPalette from './CommandPalette.svelte'
  import QuickCapture from './QuickCapture.svelte'
  import Today from './Today.svelte'
  import CockpitView from './cockpit/CockpitView.svelte'
  import Terminal from './cockpit/terminal/Terminal.svelte'
  import { applyShortcut } from './keymap'
  import { cockpit } from './cockpit/cockpit.svelte'
  import { layout, MODES } from './layout.svelte'

  let { backendStatus = 'connecting…' }: { backendStatus?: string } = $props()

  const modeLabel = $derived(
    MODES.find((m) => m.id === layout.mode)?.label ?? layout.mode,
  )

  function onGlobalKey(e: KeyboardEvent) {
    if (applyShortcut(e, layout)) e.preventDefault()
  }
</script>

<svelte:window onkeydown={onGlobalKey} />

<div class="shell" class:immersive={layout.immersive}>
  <Rail {layout} />

  {#if !layout.contextCollapsed}
    <aside class="context" aria-label="Context panel">
      <header>{modeLabel}</header>
      <p class="hint">{modeLabel} 面板将由对应 Room 提供。</p>
      <button onclick={() => layout.openTab(`${modeLabel} ${layout.tabs.length + 1}`)}>
        + 打开一个 {modeLabel} Tab
      </button>
    </aside>
  {/if}

  <main class="center" aria-label="Workspace">
    {#if layout.mode === 'today'}
      <Today />
    {:else if layout.mode === 'cockpit'}
      <CockpitView />
    {:else}
      <div class="tabbar" role="tablist">
      {#each layout.tabs as tab (tab.id)}
        <div class="tab" class:active={tab.id === layout.activeTabId}>
          <button
            class="tab-label"
            role="tab"
            id={`tab-${tab.id}`}
            aria-selected={tab.id === layout.activeTabId}
            aria-controls="workspace-panel"
            onclick={() => layout.selectTab(tab.id)}
          >
            {tab.title}
          </button>
          <button
            class="tab-close"
            aria-label={`关闭 ${tab.title}`}
            onclick={() => layout.closeTab(tab.id)}><span aria-hidden="true">×</span></button
          >
        </div>
      {/each}
    </div>
    <div
      class="content"
      id="workspace-panel"
      role="tabpanel"
      aria-label="工作区"
      tabindex="0"
    >
      {#if layout.activeTab}
        <p>{layout.activeTab.title}</p>
      {:else}
        <p class="empty">没有打开的 Tab — 从左侧面板打开一个。</p>
      {/if}
      </div>
    {/if}
  </main>

  {#if !layout.terminalCollapsed}
    <aside class="terminal" aria-label="Terminal panel">
      {#if layout.mode === 'cockpit'}
        {#key cockpit.cwd}
          <Terminal />
        {/key}
      {:else}
        <span class="term-hint">终端在驾驶舱模式下可用</span>
      {/if}
    </aside>
  {/if}

  <footer class="statusbar">
    <button onclick={() => layout.toggleContext()}>⟨ 上下文</button>
    <button onclick={() => layout.toggleTerminal()}>终端 ⟩</button>
    <button onclick={() => layout.openPalette()}>⌘K</button>
    <button onclick={() => layout.openCapture()}>⌘N 速记</button>
    <span class="status">{backendStatus}</span>
  </footer>

  <CommandPalette />
  <QuickCapture />
</div>

<style>
  .shell {
    height: 100vh;
    display: grid;
    grid-template-columns: auto auto 1fr auto;
    grid-template-rows: 1fr 28px;
    grid-template-areas:
      'rail context center terminal'
      'status status status status';
  }
  :global(.shell > nav.rail) {
    grid-area: rail;
  }
  .context {
    grid-area: context;
    width: 240px;
    padding: 12px;
    border-right: 1px solid #e5e4e7;
    overflow: auto;
  }
  .context header {
    font-weight: 600;
    margin-bottom: 6px;
  }
  .hint {
    color: #888;
    font-size: 0.85rem;
  }
  .center {
    grid-area: center;
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .tabbar {
    display: flex;
    gap: 2px;
    padding: 6px 6px 0;
    border-bottom: 1px solid #e5e4e7;
    overflow-x: auto;
  }
  .tab {
    display: flex;
    align-items: center;
    border: 1px solid #e5e4e7;
    border-bottom: none;
    border-radius: 8px 8px 0 0;
    background: #f4f3f5;
  }
  .tab.active {
    background: #fff;
  }
  .tab-label {
    border: 0;
    background: transparent;
    padding: 6px 8px;
    cursor: pointer;
    max-width: 160px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .tab-close {
    border: 0;
    background: transparent;
    cursor: pointer;
    padding: 0 6px;
    color: #999;
  }
  .content {
    flex: 1;
    display: grid;
    place-items: center;
    color: #444;
  }
  .empty {
    color: #aaa;
  }
  .terminal {
    grid-area: terminal;
    width: 320px;
    padding: 12px;
    border-left: 1px solid #e5e4e7;
    background: #1e1e1e;
    color: #ddd;
    font-family: ui-monospace, monospace;
    font-size: 0.85rem;
  }
  .statusbar {
    grid-area: status;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 10px;
    border-top: 1px solid #e5e4e7;
    background: #f1f0f3;
    font-size: 0.8rem;
  }
  .statusbar button {
    border: 0;
    background: transparent;
    cursor: pointer;
    color: #555;
    font-size: 0.8rem;
  }
  .statusbar .status {
    margin-left: auto;
    color: #888;
  }
</style>
