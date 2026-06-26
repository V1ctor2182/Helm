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
  }
  .left,
  .right {
    min-height: 0;
    min-width: 0;
  }
  .right {
    display: flex;
    flex-direction: column;
  }
  .seg {
    display: flex;
    gap: 4px;
    padding: 6px 8px 0;
    border-bottom: 1px solid #e5e4e7;
  }
  .seg button {
    border: 1px solid #e5e4e7;
    border-bottom: none;
    background: #f4f3f5;
    border-radius: 8px 8px 0 0;
    padding: 4px 12px;
    cursor: pointer;
    font-size: 0.82rem;
  }
  .seg button.active {
    background: #fff;
    font-weight: 600;
  }
  .pane {
    flex: 1;
    min-height: 0;
  }
</style>
