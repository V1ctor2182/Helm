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
    <h1>记忆</h1>
    <span class="hd">事实 · 偏好 · 决策 · 知识库</span>
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
    font: 800 22px/1.2 var(--sans);
    letter-spacing: -0.2px;
    color: var(--t1);
    margin: 0;
  }
  .head .hd {
    font: 400 13px/1 var(--sans);
    color: var(--t4);
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
    display: inline-flex;
    gap: 4px;
    background: var(--card);
    border-radius: var(--radius-pill);
    padding: 4px;
    box-shadow: var(--shadow);
    margin: 6px 18px 12px;
  }
  .seg button {
    font: 500 13px/1 var(--sans);
    color: var(--t3);
    background: transparent;
    border: 0;
    border-radius: var(--radius-pill);
    padding: 8px 18px;
    cursor: pointer;
  }
  .seg button:hover { color: var(--t1); }
  .seg button.active {
    background: var(--t1);
    color: var(--onink);
    font-weight: 600;
  }
  .panel {
    flex: 1;
    min-height: 0;
  }
</style>
