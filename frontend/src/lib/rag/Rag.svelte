<script lang="ts">
  import { onMount } from 'svelte'
  import { rag } from './ragStore.svelte'

  let path = $state('')

  onMount(() => void rag.load())

  async function add() {
    const created = await rag.addSource(path)
    if (created) path = ''
  }
</script>

<section class="rag" aria-label="知识库">
  <div class="toolrow">
    <div class="h">知识库 / KNOWLEDGE</div>
    {#if rag.stats}
      <span class="stats">
        {rag.stats.sources} 源 · {rag.stats.files} 文件 · {rag.stats.chunks} 块
        {#if rag.stats.vector_count === 0}<span class="off" title="向量索引未启用">(向量关)</span>{/if}
      </span>
    {/if}
  </div>

  <form
    class="compose"
    onsubmit={(e) => {
      e.preventDefault()
      void add()
    }}
  >
    <span class="car" aria-hidden="true"></span>
    <input
      class="path"
      placeholder="本地目录或文件路径(PDF / Office / Markdown / 代码)…"
      bind:value={path}
      aria-label="文档路径"
    />
    <button class="act pri" type="submit" disabled={rag.busy || !path.trim()}>{rag.busy ? '索引中…' : '添加并索引'}</button>
  </form>

  <div class="compose search">
    <input
      placeholder="检索知识库(语义)…"
      bind:value={rag.query}
      onkeydown={(e) => e.key === 'Enter' && rag.search()}
      aria-label="检索"
    />
    <button class="act" onclick={() => rag.search()}>检索</button>
    {#if rag.results !== null}
      <button class="act" onclick={() => rag.clearSearch()}>清除</button>
    {/if}
  </div>

  {#if rag.error}
    <p class="err" role="alert">{rag.error}</p>
  {/if}

  {#if rag.results !== null}
    <!-- retrieval results -->
    {#if rag.results.length === 0}
      <p class="empty">没有匹配的片段。</p>
    {:else}
      <ul class="list">
        {#each rag.results as h, i (i)}
          <li class="hit">
            <div class="meta">
              <span class="mpath">{h.path}</span>
              <span class="score">{h.score}</span>
            </div>
            <p class="snippet">{h.text}</p>
          </li>
        {/each}
      </ul>
    {/if}
  {:else if rag.sources.length === 0}
    <p class="empty">还没有文档源 — 在上面添加一个本地目录或文件。</p>
  {:else}
    <ul class="list">
      {#each rag.sources as s (s.id)}
        <li class="source">
          <span class="mpath">{s.path}</span>
          <span class="badge {s.status}">{s.status}</span>
          <span class="counts">{s.file_count} 文件 · {s.chunk_count} 块{#if s.error} · ERR {s.error}{/if}</span>
          <span class="acts">
            <button class="act" onclick={() => rag.reindex(s.id)} disabled={rag.busy} title="重新索引">重索引</button>
            <button class="act del" aria-label={`移除 ${s.path}`} onclick={() => rag.removeSource(s.id)}>×</button>
          </span>
        </li>
      {/each}
    </ul>
  {/if}
</section>

<style>
  .rag {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px 24px 18px 18px;
    overflow: auto;
    height: 100%;
    box-sizing: border-box;
    font-family: var(--sans);
    color: var(--t2);
  }
  .toolrow {
    display: flex;
    align-items: baseline;
    gap: 12px;
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .stats {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .off {
    color: var(--orange);
  }
  .act {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 10px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .act:hover:not(:disabled) {
    color: var(--t1);
  }
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
    cursor: default;
  }
  .compose {
    display: flex;
    align-items: center;
    gap: 9px;
  }
  .car {
    width: 2px;
    height: 14px;
    background: var(--acc);
    flex: none;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .compose input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 12px;
    padding: 3px 0 6px;
    min-width: 0;
  }
  .compose input::placeholder {
    color: var(--t4);
    font-family: var(--sans);
    font-size: 13px;
  }
  .compose input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .search {
    padding-left: 11px;
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .source {
    display: flex;
    align-items: baseline;
    gap: 10px;
    padding: 5px 0;
    border-top: 1px solid var(--hair);
    font-size: 13px;
  }
  .source:first-child {
    border-top: none;
  }
  .mpath {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t2);
    word-break: break-all;
  }
  .badge {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    text-transform: uppercase;
    color: var(--t4);
    border: 1px solid var(--line);
    padding: 0 5px;
    flex: none;
  }
  .badge.indexed {
    color: var(--green);
    border-color: var(--green);
  }
  .badge.indexing {
    color: var(--orange);
    border-color: var(--orange);
  }
  .badge.error {
    color: var(--red);
    border-color: var(--red);
  }
  .counts {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .acts {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: 6px;
    flex: none;
  }
  .act.del {
    border: 0;
    padding: 2px 4px;
  }
  .act.del:hover {
    color: var(--red);
  }
  .hit {
    padding: 6px 0;
    border-top: 1px solid var(--hair);
  }
  .hit:first-child {
    border-top: none;
  }
  .meta {
    display: flex;
    justify-content: space-between;
    gap: 8px;
  }
  .score {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .snippet {
    margin: 4px 0 0;
    font-size: 12.5px;
    color: var(--t3);
    white-space: pre-wrap;
    max-height: 6em;
    overflow: hidden;
  }
  .err {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
    margin: 0;
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
  }
</style>
