<script lang="ts">
  import { MODES, type LayoutStore, type ModeId } from './layout.svelte'

  let { layout }: { layout: LayoutStore } = $props()

  // 单色 SVG 图标（禁 emoji，承约束 7ed866af）——同 helm-pro.html 字形。
  const ICONS: Record<ModeId, string> = {
    today: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M4 5h16v11H8l-4 4z"/></svg>',
    research: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/></svg>',
    memory: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="6" cy="7" r="2.3"/><circle cx="17" cy="6" r="2.3"/><circle cx="13" cy="17" r="2.3"/><path d="M8 8l4 8M15 8l-2 8"/></svg>',
    journal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M5 4h11l3 3v13H5z"/><path d="M8 9h7M8 13h7"/></svg>',
    cockpit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9l3 3-3 3M13 15h4"/></svg>',
    settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="3"/><path d="M19.4 13.5a7.8 7.8 0 000-3l2-1.5-2-3.4-2.3 1a7.7 7.7 0 00-2.6-1.5L14 1.5h-4l-.5 2.6a7.7 7.7 0 00-2.6 1.5l-2.3-1-2 3.4 2 1.5a7.8 7.8 0 000 3l-2 1.5 2 3.4 2.3-1a7.7 7.7 0 002.6 1.5l.5 2.6h4l.5-2.6a7.7 7.7 0 002.6-1.5l2.3 1 2-3.4z"/></svg>',
  }
  const LOGO =
    '<svg viewBox="0 0 24 24"><rect x="2.5" y="2.5" width="19" height="19" rx="5.5" fill="currentColor"/><path d="M8 7.5v9M16 7.5v9M8 12h8" stroke="var(--bg)" stroke-width="2" stroke-linecap="round"/></svg>'

  const mainModes = MODES.filter((m) => m.id !== 'settings')
  const settingsMode = MODES.find((m) => m.id === 'settings')

  let railEl: HTMLElement | undefined = $state()
  let anchorTop = $state(46)
  const btns: Partial<Record<ModeId, HTMLElement>> = {}

  // 细丝锚点跟随激活图标：读其 offset 让锚点滑移对齐（settings 在底部也自动跟到）。
  $effect(() => {
    const el = btns[layout.mode]
    if (el) anchorTop = el.offsetTop + el.offsetHeight / 2 - 16
  })
</script>

<nav class="rail" aria-label="Modes" bind:this={railEl}>
  <span class="lg" aria-hidden="true">{@html LOGO}</span>
  <span class="fil" aria-hidden="true"></span>
  <span class="anchor" style="top:{anchorTop}px" aria-hidden="true"></span>
  <span class="pulse" aria-hidden="true"></span>

  {#each mainModes as m (m.id)}
    <button
      class="ric"
      class:on={layout.mode === m.id}
      title={m.label}
      aria-label={m.label}
      aria-current={layout.mode === m.id ? 'page' : undefined}
      bind:this={btns[m.id]}
      onclick={() => layout.setMode(m.id)}
    >{@html ICONS[m.id]}</button>
  {/each}

  <span class="spacer"></span>

  {#if settingsMode}
    <button
      class="ric"
      class:on={layout.mode === 'settings'}
      title={settingsMode.label}
      aria-label={settingsMode.label}
      aria-current={layout.mode === 'settings' ? 'page' : undefined}
      bind:this={btns['settings']}
      onclick={() => layout.setMode('settings')}
    >{@html ICONS.settings}</button>
  {/if}
</nav>

<style>
  .rail {
    width: 100%;
    height: 100%;
    background: var(--bg);
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 12px 0;
    gap: 3px;
  }
  .lg {
    width: 22px;
    height: 22px;
    color: var(--acc);
    margin-bottom: 8px;
    display: flex;
  }
  .lg :global(svg) {
    width: 22px;
    height: 22px;
  }
  /* 细丝：内缘 1px 活线 */
  .fil {
    position: absolute;
    top: 8px;
    bottom: 8px;
    right: 0;
    width: 1px;
    background: var(--line);
  }
  /* 激活锚点：滑移对齐激活图标 */
  .anchor {
    position: absolute;
    right: -0.5px;
    width: 2px;
    height: 32px;
    background: var(--acc);
    border-radius: 2px;
    box-shadow: 0 0 12px -1px var(--acc);
    transition: top var(--dur-slide) var(--ease);
  }
  /* agent 脉冲：光点沿线向上（mock 活动） */
  .pulse {
    position: absolute;
    right: -0.5px;
    width: 2px;
    height: 12px;
    border-radius: 2px;
    background: linear-gradient(180deg, transparent, var(--acc), transparent);
    animation: filpulse 2.6s var(--ease) infinite;
  }
  @keyframes filpulse {
    0% { top: 78%; opacity: 0; }
    12% { opacity: 0.9; }
    80% { opacity: 0.5; }
    100% { top: 12%; opacity: 0; }
  }
  .ric {
    width: 34px;
    height: 34px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--t4);
    background: transparent;
    border: 0;
    cursor: pointer;
    transition: color var(--dur-micro) var(--ease), background var(--dur-micro) var(--ease);
  }
  .ric :global(svg) {
    width: 18px;
    height: 18px;
  }
  .ric:hover {
    color: var(--t2);
    background: var(--hair);
  }
  .ric.on {
    color: var(--t1);
  }
  .spacer {
    flex: 1;
  }
</style>
