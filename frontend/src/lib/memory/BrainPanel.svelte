<script lang="ts">
  // The "memory" mode hosts both halves of the memory-rag-skills room: personal
  // Memory and the document knowledge base (RAG). A segmented control switches
  // between them so they share one Rail slot without squatting on the research
  // mode (which belongs to the deep-research room).
  import { memory } from './memoryStore.svelte'
  import { rag } from '../rag/ragStore.svelte'
  import { skills } from '../skills/skillsStore.svelte'
  import Memory from './Memory.svelte'
  import Rag from '../rag/Rag.svelte'
  import Skills from '../skills/Skills.svelte'

  let view = $state<'memory' | 'rag' | 'skills'>('memory')

  const pad3 = (n: number) => String(n).padStart(3, '0')
</script>

<div class="brain">
  <header class="head">
    <h1>MEMORY</h1>
    <span class="hd">大脑</span>
    <span class="pg">{pad3(memory.items.length)} MEMORIES · {pad3(rag.sources.length)} SOURCES · {pad3(skills.skills.length)} SKILLS</span>
  </header>
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
    <button
      role="tab"
      aria-selected={view === 'skills'}
      class:active={view === 'skills'}
      onclick={() => (view = 'skills')}>Skills</button
    >
  </div>
  <div class="panel">
    {#if view === 'memory'}
      <Memory />
    {:else if view === 'rag'}
      <Rag />
    {:else}
      <Skills />
    {/if}
  </div>
</div>

<style>
  .brain {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    font-family: var(--sans);
    color: var(--t2);
    max-width: 860px;
  }
  .head {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding: 18px 24px 6px 18px;
  }
  .head h1 {
    font-family: var(--mono);
    font-size: 24px;
    font-weight: 800;
    letter-spacing: 1px;
    color: var(--t1);
    margin: 0;
  }
  .head .hd {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--acc-ink);
    font-weight: 700;
  }
  .head .pg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .5px;
    font-variant-numeric: tabular-nums;
  }
  .seg {
    display: flex;
    gap: 18px;
    padding: 0 18px;
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
  .panel {
    flex: 1;
    min-height: 0;
  }
</style>
