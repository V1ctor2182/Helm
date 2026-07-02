<script lang="ts">
  import FileBrowser from './FileBrowser.svelte'
  import PreviewPane from './PreviewPane.svelte'
  import AgentView from '../orchestration/AgentView.svelte'

  // Right pane shows the file preview or the live agent observation (ACP events
  // streamed from the run WS). Both belong to the cockpit; a segmented control
  // keeps them in one pane.
  let right = $state<'preview' | 'agent'>('preview')
</script>

<div class="split">
  <div class="left"><FileBrowser /></div>
  <div class="right">
    <div class="seg" role="tablist" aria-label="预览 / Agent">
      <button
        role="tab"
        aria-selected={right === 'preview'}
        class:active={right === 'preview'}
        onclick={() => (right = 'preview')}>预览</button
      >
      <button
        role="tab"
        aria-selected={right === 'agent'}
        class:active={right === 'agent'}
        onclick={() => (right = 'agent')}>Agent</button
      >
    </div>
    <div class="pane">
      {#if right === 'preview'}
        <PreviewPane />
      {:else}
        <AgentView />
      {/if}
    </div>
  </div>
</div>

<style>
  .split {
    display: grid;
    grid-template-columns: minmax(260px, 1fr) minmax(280px, 1.2fr);
    height: 100%;
    min-height: 0;
    font-family: var(--sans);
    color: var(--t2);
  }
  .left,
  .right {
    min-height: 0;
    min-width: 0;
  }
  .right {
    display: flex;
    flex-direction: column;
    border-left: 1px solid var(--hair);
  }
  .seg {
    display: flex;
    gap: 18px;
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
  .pane {
    flex: 1;
    min-height: 0;
  }
</style>
