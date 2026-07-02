<script lang="ts">
  import { onMount } from 'svelte'
  import { memory, CATEGORIES, type Category } from './memoryStore.svelte'
  import { ConfirmGate } from '../confirm.svelte'

  let draft = $state('')
  const del = new ConfirmGate()
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
  <div class="toolrow">
    <div class="filters" role="tablist" aria-label="分类筛选">
      <button class="chip" class:active={memory.filter === 'all'} onclick={() => memory.setFilter('all')}>全部</button>
      {#each CATEGORIES as c (c)}
        <button class="chip" class:active={memory.filter === c} onclick={() => memory.setFilter(c)}>{c}</button>
      {/each}
    </div>
    <div class="io">
      <button class="act" onclick={doExport}>导出 JSON</button>
      <label class="act import">
        导入
        <input type="file" accept="application/json" onchange={onImportFile} />
      </label>
    </div>
  </div>

  <form
    class="compose"
    onsubmit={(e) => {
      e.preventDefault()
      void add()
    }}
  >
    <span class="car" aria-hidden="true"></span>
    <input class="text" placeholder="记住点什么…(事实 / 偏好 / 决策)" bind:value={draft} aria-label="记忆内容" />
    <select bind:value={draftCat} aria-label="分类">
      {#each CATEGORIES as c (c)}
        <option value={c}>{c}</option>
      {/each}
    </select>
    <button class="act pri" type="submit" disabled={!draft.trim()}>添加</button>
  </form>

  <div class="compose search">
    <input
      placeholder="搜索记忆(关键词 + 语义)…"
      bind:value={memory.query}
      onkeydown={(e) => e.key === 'Enter' && memory.search()}
      aria-label="搜索"
    />
    <button class="act" onclick={() => memory.search()}>搜索</button>
    {#if memory.results !== null}
      <button class="act" onclick={() => memory.clearSearch()}>清除</button>
    {/if}
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
          <span class="cat">{m.category}</span>
          <p class="body">{m.text}</p>
          <span class="acts">
            {#if 'score' in m}<span class="score">{(m as { score: number }).score}</span>{/if}
            <button
              class="act pin"
              class:on={m.pinned}
              aria-pressed={m.pinned}
              title={m.pinned ? '取消置顶' : '置顶'}
              onclick={() => memory.togglePin(m)}>PIN</button
            >
            <button
              class="act del"
              class:armed={del.pending === `m-${m.id}`}
              aria-label={`删除 ${m.text}`}
              onclick={() => del.confirm(`m-${m.id}`) && memory.remove(m.id)}
            >{del.pending === `m-${m.id}` ? '确认' : '×'}</button>
          </span>
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
    padding: 12px 24px 18px 18px;
    overflow: auto;
    height: 100%;
    box-sizing: border-box;
  }
  .toolrow {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .filters {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .chip {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: .5px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 3px 9px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .chip:hover {
    color: var(--t1);
  }
  .chip.active {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .io {
    margin-left: auto;
    display: flex;
    gap: 8px;
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
  .act:hover {
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
  .import {
    display: inline-flex;
    align-items: center;
  }
  .import input {
    display: none;
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
    font-family: var(--sans);
    font-size: 13px;
    padding: 3px 0 6px;
    min-width: 0;
  }
  .compose input::placeholder {
    color: var(--t4);
  }
  .compose input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .compose select {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 11px;
    padding: 3px 0 5px;
  }
  .compose select option {
    background: var(--panel);
    color: var(--t1);
  }
  .compose select:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .search {
    padding-left: 11px; /* 与 compose 的 caret 对齐 */
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .item {
    display: flex;
    align-items: baseline;
    gap: 10px;
    padding: 5px 0;
    border-top: 1px solid var(--hair);
    font-size: 13px;
  }
  .item:first-child {
    border-top: none;
  }
  .item.pinned {
    border-left: 2px solid var(--acc);
    padding-left: 8px;
  }
  .cat {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    text-transform: uppercase;
    color: var(--t4);
    flex: none;
    min-width: 62px;
  }
  .body {
    margin: 0;
    flex: 1;
    color: var(--t2);
    word-break: break-word;
  }
  .acts {
    display: flex;
    align-items: center;
    gap: 6px;
    flex: none;
  }
  .score {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .act.pin,
  .act.del {
    border: 0;
    padding: 2px 4px;
  }
  .act.pin.on {
    color: var(--acc-ink);
  }
  .act.del:hover,
  .act.del.armed {
    color: var(--red);
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
