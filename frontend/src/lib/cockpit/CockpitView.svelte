<script lang="ts">
  import FileBrowser from './FileBrowser.svelte'
  import PreviewPane from './PreviewPane.svelte'
  import AgentView from '../orchestration/AgentView.svelte'
  import Lightbox from './Lightbox.svelte'
  import { cockpit } from './cockpit.svelte'

  // 预览按需面板(承 FanBox,阶段3.5 结构#1):文件区永远是主角——
  // 无选中铺满全宽;选中才滑出预览;Esc/✕ 关闭回全宽;中缝可拖存比例。
  // Agent 观察台不依赖选中,由 rightTab 固定打开。
  const showRight = $derived(cockpit.rightTab === 'agent' || cockpit.selected !== null)

  function loadSplit(): number {
    try {
      return Math.min(0.72, Math.max(0.28, Number(localStorage.getItem('helm-ck-split') ?? 0.46)))
    } catch {
      return 0.46 // jsdom/隐私模式兜底
    }
  }
  let split = $state(loadSplit())
  let rootEl = $state<HTMLDivElement | null>(null)
  let dragging = $state(false)

  function startDrag(e: MouseEvent) {
    e.preventDefault()
    dragging = true
    const move = (ev: MouseEvent) => {
      const r = rootEl?.getBoundingClientRect()
      if (!r) return
      split = Math.min(0.72, Math.max(0.28, (ev.clientX - r.left) / r.width))
    }
    const up = () => {
      dragging = false
      try {
        localStorage.setItem('helm-ck-split', String(split))
      } catch {
        /* 存不了就算了 */
      }
      window.removeEventListener('mousemove', move)
      window.removeEventListener('mouseup', up)
    }
    window.addEventListener('mousemove', move)
    window.addEventListener('mouseup', up)
  }

  function closeRight() {
    cockpit.selected = null
    cockpit.rightTab = 'preview'
  }
</script>

<div
  class="split"
  class:dragging
  bind:this={rootEl}
  style={showRight ? `grid-template-columns: ${(split * 100).toFixed(2)}% 5px 1fr` : ''}
>
  <div class="left"><FileBrowser /></div>
  {#if showRight}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div
      class="divider"
      role="separator"
      aria-orientation="vertical"
      aria-label="调整预览宽度"
      onmousedown={startDrag}
    ></div>
    <div class="right">
      <div class="seg" role="tablist" aria-label="预览 / Agent">
        <button
          role="tab"
          aria-selected={cockpit.rightTab === 'preview'}
          class:active={cockpit.rightTab === 'preview'}
          onclick={() => (cockpit.rightTab = 'preview')}>预览</button
        >
        <button
          role="tab"
          aria-selected={cockpit.rightTab === 'agent'}
          class:active={cockpit.rightTab === 'agent'}
          onclick={() => (cockpit.rightTab = 'agent')}>Agent</button
        >
        <button class="close" aria-label="关闭面板" onclick={closeRight}>×</button>
      </div>
      <div class="pane">
        {#if cockpit.rightTab === 'preview'}
          <PreviewPane />
        {:else}
          <AgentView />
        {/if}
      </div>
    </div>
  {/if}
</div>

<Lightbox />

<style>
  .split {
    display: grid;
    grid-template-columns: 1fr;
    height: 100%;
    min-height: 0;
    font-family: var(--sans);
    color: var(--t2);
  }
  .split.dragging {
    cursor: col-resize;
    user-select: none;
  }
  .left,
  .right {
    min-height: 0;
    min-width: 0;
  }
  .divider {
    cursor: col-resize;
    background: transparent;
    border-left: 1px solid var(--hair);
    transition: border-color .12s var(--ease);
  }
  .divider:hover,
  .split.dragging .divider {
    border-left-color: var(--acc);
  }
  .right {
    display: flex;
    flex-direction: column;
  }
  .seg {
    display: flex;
    gap: 18px;
    align-items: center;
    padding: 6px 14px 0;
    border-bottom: 1px solid var(--hair);
  }
  .seg button {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 1px;
    color: var(--t3);
    background: transparent;
    border: 0;
    border-bottom: 2px solid transparent;
    padding: 4px 1px 6px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .seg button:hover {
    color: var(--t1);
  }
  .seg button.active {
    color: var(--t1);
    border-bottom-color: var(--acc);
  }
  .seg .close {
    margin-left: auto;
    border-bottom: 0;
    font-size: 11px;
  }
  .pane {
    flex: 1;
    min-height: 0;
  }
</style>
