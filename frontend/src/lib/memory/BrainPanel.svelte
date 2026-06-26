<script lang="ts">
  // The "memory" mode hosts both halves of the memory-rag-skills room: personal
  // Memory and the document knowledge base (RAG). A segmented control switches
  // between them so they share one Rail slot without squatting on the research
  // mode (which belongs to the deep-research room).
  import Memory from './Memory.svelte'
  import Rag from '../rag/Rag.svelte'

  let view = $state<'memory' | 'rag'>('memory')
</script>

<div class="brain">
  <div class="seg" role="tablist" aria-label="记忆 / 知识库">
    <button
      role="tab"
      aria-selected={view === 'memory'}
      class:active={view === 'memory'}
      onclick={() => (view = 'memory')}>记忆</button
    >
    <button
      role="tab"
      aria-selected={view === 'rag'}
      class:active={view === 'rag'}
      onclick={() => (view = 'rag')}>知识库</button
    >
  </div>
  <div class="panel">
    {#if view === 'memory'}
      <Memory />
    {:else}
      <Rag />
    {/if}
  </div>
</div>

<style>
  .brain {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
  }
  .seg {
    display: flex;
    gap: 4px;
    padding: 8px 12px 0;
    border-bottom: 1px solid #e5e4e7;
  }
  .seg button {
    border: 1px solid #e5e4e7;
    border-bottom: none;
    background: #f4f3f5;
    border-radius: 8px 8px 0 0;
    padding: 5px 14px;
    cursor: pointer;
    font-size: 0.85rem;
  }
  .seg button.active {
    background: #fff;
    font-weight: 600;
  }
  .panel {
    flex: 1;
    min-height: 0;
  }
</style>
