<script lang="ts">
  import { onMount } from 'svelte'
  import { cockpit } from './cockpit.svelte'
  import { iconFor } from './fileIcons'

  let pathInput = $state('')

  onMount(() => {
    void cockpit.loadProjects()
  })

  function openInput(e: Event) {
    e.preventDefault()
    if (pathInput.trim()) void cockpit.openProject(pathInput.trim())
  }

  function parentOf(p: string): string | null {
    const i = p.replace(/\/+$/, '').lastIndexOf('/')
    return i > 0 ? p.slice(0, i) : i === 0 ? '/' : null
  }

  const parent = $derived(cockpit.cwd ? parentOf(cockpit.cwd) : null)

  function fmtSize(n: number): string {
    if (n < 1024) return `${n} B`
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`
    return `${(n / 1024 / 1024).toFixed(1)} MB`
  }
</script>

<div class="browser">
  <form class="bar" onsubmit={openInput}>
    {#if cockpit.cwd}
      <button
        type="button"
        class="up"
        disabled={!parent}
        onclick={() => parent && cockpit.browse(parent)}>⬆</button
      >
      <span class="cwd" title={cockpit.cwd}>{cockpit.cwd}</span>
    {:else}
      <input
        bind:value={pathInput}
        placeholder="打开项目文件夹（绝对路径，⏎）"
        aria-label="项目路径"
      />
      <button type="submit">打开</button>
    {/if}
  </form>

  {#if cockpit.error}
    <p class="error">{cockpit.error}</p>
  {/if}

  {#if !cockpit.cwd}
    <h3 class="section">最近项目</h3>
    {#if cockpit.projects.length === 0}
      <p class="muted">还没有项目 — 在上方打开一个文件夹。</p>
    {:else}
      <div class="grid">
        {#each cockpit.projects as p (p.path)}
          <button class="card project" onclick={() => cockpit.openProject(p.path)}>
            <span class="card-name">{p.name}</span>
            <span class="badges">
              {#each p.badges as b (b)}<span class="badge">{b}</span>{/each}
            </span>
          </button>
        {/each}
      </div>
    {/if}
  {:else}
    <div class="grid">
      {#each cockpit.entries as e (e.path)}
        {@const ic = iconFor(e)}
        <button
          class="card"
          class:selected={cockpit.selected?.path === e.path}
          onclick={() => cockpit.select(e)}
        >
          <span class="icon" style="color:{ic.color}">{ic.glyph}</span>
          <span class="card-name" title={e.name}>{e.name}</span>
          <span class="meta">{e.is_dir ? '文件夹' : fmtSize(e.size)}</span>
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .browser {
    height: 100%;
    overflow: auto;
    padding: 16px;
    box-sizing: border-box;
  }
  .bar {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-bottom: 12px;
  }
  .bar input {
    flex: 1;
    border: 1px solid #e5e4e7;
    border-radius: 8px;
    padding: 8px 10px;
    font: inherit;
  }
  .bar button {
    border: 1px solid #e5e4e7;
    background: #fff;
    border-radius: 8px;
    padding: 7px 12px;
    cursor: pointer;
  }
  .up:disabled {
    opacity: 0.4;
    cursor: default;
  }
  .cwd {
    color: #555;
    font-size: 0.85rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .error {
    color: #e5484d;
    font-size: 0.85rem;
  }
  .section {
    margin: 4px 0 10px;
    font-size: 0.85rem;
    color: #888;
    font-weight: 600;
  }
  .muted {
    color: #aaa;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 10px;
  }
  .card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
    border: 1px solid #e5e4e7;
    border-radius: 10px;
    background: #fff;
    padding: 12px;
    cursor: pointer;
    text-align: left;
    min-height: 76px;
  }
  .card:hover {
    border-color: #c9c8cf;
  }
  .card.selected {
    border-color: #4250ff;
    background: #f5f6ff;
  }
  .icon {
    font-weight: 700;
    font-size: 14px;
  }
  .card-name {
    font-size: 0.85rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
  }
  .meta {
    color: #999;
    font-size: 0.75rem;
  }
  .badges {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .badge {
    font-size: 0.7rem;
    background: #eef1ff;
    color: #4250ff;
    border-radius: 4px;
    padding: 1px 5px;
  }
</style>
