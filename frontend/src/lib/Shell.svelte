<script lang="ts">
  import Rail from './Rail.svelte'
import Resizer from './Resizer.svelte'
  import ContextPanel from './ContextPanel.svelte'
  import CommandPalette from './CommandPalette.svelte'
  import QuickCapture from './QuickCapture.svelte'
  import Today from './Today.svelte'
  import Chat from './chat/Chat.svelte'
  import BrainPanel from './memory/BrainPanel.svelte'
  import Research from './research/Research.svelte'
  import JournalView from './notes/JournalView.svelte'
  import Settings from './Settings.svelte'
  import CockpitView from './cockpit/CockpitView.svelte'
  import { dock } from './cockpit/dock.svelte'

  // 桌面壳检测(macos/ 的 WKWebView 会在 UA 里带 HelmShell 标记)
  const inShell =
    navigator.userAgent.includes('HelmShell') ||
    (window as unknown as { __HELM_SHELL__?: boolean }).__HELM_SHELL__ === true

  function titlebarDrag(e: MouseEvent) {
    // 只有壳内才把标题栏当拖拽把手;点在按钮/链接上不抢
    if (!inShell || (e.target as HTMLElement).closest('button, a, input')) return
    interface DragBridge {
      webkit?: { messageHandlers?: { helmDrag?: { postMessage: (m: string) => void } } }
    }
    ;(window as unknown as DragBridge).webkit?.messageHandlers?.helmDrag?.postMessage('drag')
  }
  import { applyShortcut } from './keymap'
  import { cockpit } from './cockpit/cockpit.svelte'
  import { layout } from './layout.svelte'

  let { backendStatus = 'connecting…' }: { backendStatus?: string } = $props()

  function onGlobalKey(e: KeyboardEvent) {
    if (applyShortcut(e, layout)) e.preventDefault()
  }
</script>

<svelte:window onkeydown={onGlobalKey}  ondragover={(e) => e.preventDefault()} ondrop={(e) => e.preventDefault()} />

<div class="shell" class:immersive={layout.immersive}>
  <!-- titlebar: 交通灯 + wordmark + 路径 + 会话 meta（承 helm-pro.html）。
       壳内(HelmShell UA):假灯隐藏、给原生真灯让位、整条变成窗口拖拽把手 -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <header class="titlebar" class:inshell={inShell} onmousedown={titlebarDrag}>
    <span class="grow"></span>
    <span class="meta"><span class="live" aria-hidden="true">●</span> {backendStatus}</span>
  </header>

  <Rail {layout} />
  <Resizer cssVar="--side-w" storageKey="helm.ui.sideW" min={180} max={360} initial={250}
    style={`left:calc(var(--side-w) - 3px);top:var(--titlebar-h);bottom:var(--statusbar-h)`} />
  {#if !layout.contextCollapsed}
    <Resizer cssVar="--ctx-w" storageKey="helm.ui.ctxW" min={180} max={420} initial={250}
      style={`left:calc(var(--side-w) + var(--ctx-w) - 3px);top:var(--titlebar-h);bottom:var(--statusbar-h)`} />
  {/if}

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
    {:else if layout.mode === 'settings'}
      <Settings />
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

  <!-- 终端已迁入驾驶舱 dock(底栏默认,可拖拽换位);边条退役,statusbar 按钮直达 -->

  <!-- statusbar: CLI 面包屑 / 遥测 HUD（承 helm-pro.html） -->
  <footer class="statusbar">
    <button class="seg" onclick={() => layout.toggleContext()}>‹ 上下文</button>
    <span class="grow"></span>
    <button
      class="seg"
      onclick={() => {
        dock.reveal('terminal')
        layout.setMode('cockpit')
      }}>终端</button
    >
    <button class="seg" onclick={() => layout.openPalette()}>⌘K 命令面板</button>
    <button class="seg" onclick={() => layout.openCapture()}>⌘N 速记</button>
  </footer>

  <CommandPalette />
  <QuickCapture />
</div>

<style>
  .shell {
    position: relative;
    height: 100vh;
    display: grid;
    grid-template-columns: var(--side-w) auto 1fr; /* NOMI 白侧栏(R02) */
    grid-template-rows: var(--titlebar-h) 1fr var(--statusbar-h);
    grid-template-areas:
      'title title title'
      'rail context center'
      'status status status';
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
  .titlebar.inshell {
    padding-left: 84px;
  }
  .titlebar .live {
    color: var(--green);
    font-size: 8px;
  }
  .titlebar .meta {
    display: flex;
    align-items: center;
    gap: 6px;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
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

  /* center + ORAGE 点阵底纹（背景层，避免 z-index 覆盖内容） */
  .center {
    grid-area: center;
    position: relative;
    display: flex;
    flex-direction: column;
    min-width: 0;
    background:
      radial-gradient(var(--grid) 1px, transparent 1px) 0 0 / 22px 22px,
      var(--bg);
  }
  /* 散落准星 + 坐标 chip：pointer-events none，弱默认只显少量 */
  /* 强模式才显的额外准星 */
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

  /* statusbar · CLI 面包屑 HUD */
  .statusbar {
    grid-area: status;
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 0 10px;
    background: var(--chrome);
    border-top: 1px solid var(--hair);
  }
  .statusbar .seg {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    background: transparent;
    border: 0;
    border-radius: var(--radius-pill);
    padding: 5px 10px;
    cursor: pointer;
  }
  button.seg {
    border: 0;
    cursor: pointer;
  }
  button.seg:hover {
    color: var(--t1);
  }
  .statusbar .grow {
    flex: 1;
  }
</style>
