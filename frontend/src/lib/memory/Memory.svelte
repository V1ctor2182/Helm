<script lang="ts">
  import { onMount } from 'svelte'
  import { memory, CATEGORIES, type Category } from './memoryStore.svelte'

  let draft = $state('')
  let draftCat = $state<Category>('fact')

  // The browse list, or search results when a query is active.
  const shown = $derived(memory.results ?? memory.items)

  onMount(() => void memory.load())

  async function add() {
    const created = await memory.add(draft, draftCat)
    if (created) draft = ''
  }

  function downloadExport(text: string) {
    // Browser-only side effect; guarded so unit tests (jsdom) don't need it.
    if (typeof URL.createObjectURL !== 'function') return
    const blob = new Blob([text], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'helm-memories.json'
    a.click()
    URL.revokeObjectURL(url)
  }

  async function doExport() {
    const text = await memory.exportJSON()
    if (text) downloadExport(text)
  }

  async function onImportFile(e: Event) {
    const input = e.target as HTMLInputElement
    const file = input.files?.[0]
    if (!file) return
    const n = await memory.importJSON(await file.text())
    input.value = ''
    if (n) memory.clearSearch()
  }
</script>

<section class="memory" aria-label="Memory">
  <header>
    <h2>🧠 记忆</h2>
    <div class="io">
      <button onclick={doExport}>导出 JSON</button>
      <label class="import">
        导入
        <input type="file" accept="application/json" onchange={onImportFile} />
      </label>
    </div>
  </header>

  <form
    class="add"
    onsubmit={(e) => {
      e.preventDefault()
      void add()
    }}
  >
    <input
      class="text"
      placeholder="记住点什么…(事实 / 偏好 / 决策)"
      bind:value={draft}
      aria-label="记忆内容"
    />
    <select bind:value={draftCat} aria-label="分类">
      {#each CATEGORIES as c (c)}
        <option value={c}>{c}</option>
      {/each}
    </select>
    <button type="submit" disabled={!draft.trim()}>添加</button>
  </form>

  <div class="search">
    <input
      placeholder="搜索记忆(关键词 + 语义)…"
      bind:value={memory.query}
      onkeydown={(e) => e.key === 'Enter' && memory.search()}
      aria-label="搜索"
    />
    <button onclick={() => memory.search()}>搜索</button>
    {#if memory.results !== null}
      <button onclick={() => memory.clearSearch()}>清除</button>
    {/if}
  </div>

  <div class="filters" role="tablist" aria-label="分类筛选">
    <button class:active={memory.filter === 'all'} onclick={() => memory.setFilter('all')}>全部</button>
    {#each CATEGORIES as c (c)}
      <button class:active={memory.filter === c} onclick={() => memory.setFilter(c)}>{c}</button>
    {/each}
  </div>

  {#if memory.error}
    <p class="err" role="alert">{memory.error}</p>
  {/if}

  {#if shown.length === 0}
    <p class="empty">
      {memory.results !== null ? '没有匹配的记忆。' : '还没有记忆 — 在上面添加第一条。'}
    </p>
  {:else}
    <ul class="list">
      {#each shown as m (m.id)}
        <li class="item" class:pinned={m.pinned}>
          <div class="meta">
            <span class="cat">{m.category}</span>
            {#if 'score' in m}<span class="score">{(m as { score: number }).score}</span>{/if}
          </div>
          <p class="body">{m.text}</p>
          <div class="actions">
            <button
              class="pin"
              aria-pressed={m.pinned}
              title={m.pinned ? '取消置顶' : '置顶'}
              onclick={() => memory.togglePin(m)}>{m.pinned ? '📌' : '📍'}</button
            >
            <button class="del" aria-label={`删除 ${m.text}`} onclick={() => memory.remove(m.id)}
              >🗑</button
            >
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</section>

<style>
  .memory {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 14px;
    overflow: auto;
    height: 100%;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  header h2 {
    margin: 0;
    font-size: 1.05rem;
  }
  .io {
    display: flex;
    gap: 6px;
  }
  .import {
    font-size: 0.8rem;
    cursor: pointer;
  }
  .import input {
    display: none;
  }
  .add,
  .search {
    display: flex;
    gap: 6px;
  }
  .add .text,
  .search input {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .filters {
    display: flex;
    gap: 4px;
  }
  .filters button {
    border: 1px solid #e5e4e7;
    background: #f4f3f5;
    border-radius: 999px;
    padding: 3px 10px;
    cursor: pointer;
    font-size: 0.8rem;
  }
  .filters button.active {
    background: #fff;
    border-color: #cfcdd4;
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .item {
    border: 1px solid #eceaef;
    border-radius: 10px;
    padding: 8px 10px;
    background: #fff;
  }
  .item.pinned {
    border-color: #d9b8ff;
    background: #faf6ff;
  }
  .meta {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .cat {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: #8a7fa3;
  }
  .score {
    font-size: 0.7rem;
    color: #aaa;
  }
  .body {
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
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
  }
</style>
