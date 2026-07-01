<script lang="ts">
  import Rail from './Rail.svelte'
  import ContextPanel from './ContextPanel.svelte'
  import CommandPalette from './CommandPalette.svelte'
  import QuickCapture from './QuickCapture.svelte'
  import Today from './Today.svelte'
  import Chat from './chat/Chat.svelte'
  import BrainPanel from './memory/BrainPanel.svelte'
  import Research from './research/Research.svelte'
  import JournalView from './notes/JournalView.svelte'
  import CockpitView from './cockpit/CockpitView.svelte'
  import Terminal from './cockpit/terminal/Terminal.svelte'
  import { applyShortcut } from './keymap'
  import { cockpit } from './cockpit/cockpit.svelte'
  import { layout } from './layout.svelte'

  let { backendStatus = 'connecting…' }: { backendStatus?: string } = $props()

  function onGlobalKey(e: KeyboardEvent) {
    if (applyShortcut(e, layout)) e.preventDefault()
  }
</script>

<svelte:window onkeydown={onGlobalKey} />

<div class="shell" class:immersive={layout.immersive}>
  <!-- titlebar: 交通灯 + wordmark + 路径 + 会话 meta（承 helm-pro.html） -->
  <header class="titlebar">
    <span class="tl r" aria-hidden="true"></span>
    <span class="tl y" aria-hidden="true"></span>
    <span class="tl g" aria-hidden="true"></span>
    <span class="wm">HELM</span>
    <span class="path">~/helm</span>
    <span class="meta">SESSION · RES 1440×900 · LOCAL</span>
  </header>

  <Rail {layout} />

  {#if !layout.contextCollapsed}
    <aside class="context" aria-label="Context panel">
      <ContextPanel />
    </aside>
  {/if}

  <main class="center" aria-label="Workspace">
    {#if layout.mode === 'today'}
      <Today />
    {:else if layout.mode === 'cockpit'}
      <CockpitView />
    {:else if layout.mode === 'chat'}
      <Chat />
    {:else if layout.mode === 'memory'}
      <BrainPanel />
    {:else if layout.mode === 'research'}
      <Research />
    {:else if layout.mode === 'journal'}
      <JournalView />
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

  <!-- statusbar: CLI 面包屑 / 遥测 HUD（承 helm-pro.html） -->
  <footer class="statusbar">
    <button class="seg" onclick={() => layout.toggleContext()}>⟨ 上下文</button>
    <span class="seg"><span class="live" aria-hidden="true">●</span> ~/helm</span>
    <span class="seg">⎇ main <span class="num">↑0</span></span>
    <span class="seg">{backendStatus}</span>
    <span class="grow"></span>
    <button class="seg" onclick={() => layout.toggleTerminal()}>终端 ⟩</button>
    <button class="seg k" onclick={() => layout.openPalette()}>⌘K 命令面板</button>
    <button class="seg k" onclick={() => layout.openCapture()}>⌘N 速记</button>
  </footer>

  <CommandPalette />
  <QuickCapture />
</div>

<style>
  .shell {
    height: 100vh;
    display: grid;
    grid-template-columns: var(--rail-w) auto 1fr auto;
    grid-template-rows: var(--titlebar-h) 1fr var(--statusbar-h);
    grid-template-areas:
      'title title title title'
      'rail context center terminal'
      'status status status status';
    background: var(--bg);
    color: var(--t2);
    font-family: var(--sans);
  }

  /* titlebar */
  .titlebar {
    grid-area: title;
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 0 12px;
    background: var(--chrome);
    border-bottom: 1px solid var(--hair);
  }
  .tl {
    width: 11px;
    height: 11px;
    border-radius: 50%;
  }
  .tl.r { background: #ff5f57; }
  .tl.y { background: #febc2e; }
  .tl.g { background: #28c840; }
  .titlebar .wm {
    margin-left: 10px;
    font-family: var(--mono);
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 3px;
    color: var(--t2);
  }
  .titlebar .path {
    margin-left: 8px;
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t4);
    letter-spacing: .3px;
  }
  .titlebar .meta {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .3px;
  }

  :global(.shell > nav.rail) {
    grid-area: rail;
  }

  /* context panel */
  .context {
    grid-area: context;
    width: var(--ctx-w);
    padding: 14px;
    background: var(--panel);
    border-right: 1px solid var(--hair);
    overflow: hidden;
  }

  /* center */
  .center {
    grid-area: center;
    display: flex;
    flex-direction: column;
    min-width: 0;
    background: var(--bg);
  }
  .tabbar {
    display: flex;
    gap: 2px;
    padding: 6px 6px 0;
    border-bottom: 1px solid var(--hair);
    overflow-x: auto;
  }
  .tab {
    display: flex;
    align-items: center;
    border: 1px solid var(--line);
    border-bottom: none;
    background: var(--panel);
  }
  .tab.active {
    background: var(--tile);
  }
  .tab-label {
    border: 0;
    background: transparent;
    color: var(--t2);
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
    color: var(--t4);
  }
  .tab-close:hover { color: var(--t2); }
  .content {
    flex: 1;
    display: grid;
    place-items: center;
    color: var(--t3);
  }
  .empty {
    color: var(--t4);
  }

  /* terminal */
  .terminal {
    grid-area: terminal;
    width: var(--term-w);
    padding: 12px;
    background: #050506;
    border-left: 1px solid var(--hair);
    color: var(--t3);
    font-family: var(--mono);
    font-size: 11px;
  }
  .term-hint { color: var(--t4); }

  /* statusbar · CLI 面包屑 HUD */
  .statusbar {
    grid-area: status;
    display: flex;
    align-items: center;
    background: var(--chrome);
    border-top: 1px solid var(--hair);
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t3);
    letter-spacing: .2px;
  }
  .statusbar .seg {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 0 12px;
    height: var(--statusbar-h);
    border-right: 1px solid var(--hair);
    background: transparent;
    color: var(--t3);
    font-family: var(--mono);
    font-size: 11px;
    cursor: default;
  }
  button.seg {
    border: 0;
    cursor: pointer;
  }
  button.seg:hover {
    color: var(--t1);
  }
  .statusbar .seg.k {
    border-right: none;
    border-left: 1px solid var(--hair);
    color: var(--t4);
  }
  .statusbar .live {
    color: var(--acc-ink);
  }
  .statusbar .num {
    color: var(--t3);
    font-variant-numeric: tabular-nums;
  }
  .statusbar .grow {
    flex: 1;
  }
</style>
