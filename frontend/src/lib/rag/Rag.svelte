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
  <header>
    <h2>📚 知识库</h2>
    {#if rag.stats}
      <span class="stats">
        {rag.stats.sources} 源 · {rag.stats.files} 文件 · {rag.stats.chunks} 块
        {#if rag.stats.vector_count === 0}<span class="off" title="向量索引未启用">(向量关)</span>{/if}
      </span>
    {/if}
  </header>

  <form
    class="add"
    onsubmit={(e) => {
      e.preventDefault()
      void add()
    }}
  >
    <input
      class="path"
      placeholder="本地目录或文件路径(PDF / Office / Markdown / 代码)…"
      bind:value={path}
      aria-label="文档路径"
    />
    <button type="submit" disabled={rag.busy || !path.trim()}>{rag.busy ? '索引中…' : '添加并索引'}</button>
  </form>

  <div class="search">
    <input
      placeholder="检索知识库(语义)…"
      bind:value={rag.query}
      onkeydown={(e) => e.key === 'Enter' && rag.search()}
      aria-label="检索"
    />
    <button onclick={() => rag.search()}>检索</button>
    {#if rag.results !== null}
      <button onclick={() => rag.clearSearch()}>清除</button>
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
      <ul class="hits">
        {#each rag.results as h, i (i)}
          <li class="hit">
            <div class="meta">
              <span class="hpath">{h.path}</span>
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
    <ul class="sources">
      {#each rag.sources as s (s.id)}
        <li class="source">
          <div class="info">
            <span class="spath">{s.path}</span>
            <span class="badge {s.status}">{s.status}</span>
          </div>
          <div class="counts">{s.file_count} 文件 · {s.chunk_count} 块{#if s.error} · ⚠ {s.error}{/if}</div>
          <div class="actions">
            <button onclick={() => rag.reindex(s.id)} disabled={rag.busy} title="重新索引">↻</button>
            <button class="del" aria-label={`移除 ${s.path}`} onclick={() => rag.removeSource(s.id)}>🗑</button>
          </div>
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
    padding: 14px;
    overflow: auto;
    height: 100%;
  }
  header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 8px;
  }
  header h2 {
    margin: 0;
    font-size: 1.05rem;
  }
  .stats {
    font-size: 0.8rem;
    color: #888;
  }
  .off {
    color: #c08a00;
  }
  .add,
  .search {
    display: flex;
    gap: 6px;
  }
  .add .path,
  .search input {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .sources,
  .hits {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .source {
    border: 1px solid #eceaef;
    border-radius: 10px;
    padding: 8px 10px;
    background: #fff;
  }
  .info {
    display: flex;
    align-items: center;
    gap: 8px;
    justify-content: space-between;
  }
  .spath,
  .hpath {
    font-family: ui-monospace, monospace;
    font-size: 0.82rem;
    word-break: break-all;
  }
  .badge {
    font-size: 0.68rem;
    text-transform: uppercase;
    border-radius: 999px;
    padding: 1px 8px;
    background: #eee;
    color: #666;
  }
  .badge.indexed {
    background: #e6f6ec;
    color: #1c7a40;
  }
  .badge.error {
    background: #fbe8e6;
    color: #c0392b;
  }
  .counts {
    font-size: 0.78rem;
    color: #888;
    margin: 4px 0;
  }
  .actions {
    display: flex;
    gap: 6px;
    justify-content: flex-end;
  }
  .actions button {
    border: 0;
    background: transparent;
    cursor: pointer;
  }
  .hit {
    border: 1px solid #eceaef;
    border-radius: 10px;
    padding: 8px 10px;
    background: #fff;
  }
  .meta {
    display: flex;
    justify-content: space-between;
    gap: 8px;
  }
  .score {
    font-size: 0.72rem;
    color: #aaa;
  }
  .snippet {
    margin: 4px 0 0;
    font-size: 0.88rem;
    white-space: pre-wrap;
    max-height: 6em;
    overflow: hidden;
  }
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
  }
</style>
