<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import { cockpit } from './cockpit.svelte'
  import { iconFor } from './fileIcons'

  let pathInput = $state('')

  onMount(() => {
    void cockpit.loadProjects()
  })

  onDestroy(() => {
    cockpit.stopWatching()
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
        onclick={() => parent && cockpit.browse(parent)}>↑</button
      >
      <span class="cwd" title={cockpit.cwd}>{cockpit.cwd}</span>
      <button
        type="button"
        class="follow"
        class:on={cockpit.followMode}
        aria-pressed={cockpit.followMode}
        title="跟随模式：自动预览 agent 正在改的文件"
        onclick={() => cockpit.toggleFollow()}>跟随{cockpit.followMode ? ' ●' : ''}</button
      >
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
          class:changed={cockpit.changedPaths.has(e.path)}
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
    padding: 14px;
    box-sizing: border-box;
    font-family: var(--sans);
    color: var(--t2);
  }
  .bar {
    display: flex;
    gap: 10px;
    align-items: center;
    margin-bottom: 12px;
  }
  .bar input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 12px;
    padding: 4px 0 7px;
    min-width: 0;
  }
  .bar input::placeholder {
    color: var(--t4);
    font-family: var(--sans);
    font-size: 13px;
  }
  .bar input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .bar button {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 10px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .bar button:hover:not(:disabled) {
    color: var(--t1);
  }
  .up {
    padding: 4px 8px;
  }
  .up:disabled {
    opacity: 0.4;
    cursor: default;
  }
  .cwd {
    color: var(--t3);
    font-family: var(--mono);
    font-size: 11px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .error {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
  }
  .section {
    margin: 4px 0 10px;
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--t3);
    font-weight: 700;
  }
  .muted {
    color: var(--t4);
    font-size: 13px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 8px;
  }
  /* 文件瓦片:1px 线框、零圆角(仪表瓦片,非填充卡) */
  .card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
    border: 1px solid var(--hair);
    background: transparent;
    padding: 10px 11px;
    cursor: pointer;
    text-align: left;
    min-height: 72px;
    transition: border-color .12s var(--ease);
  }
  .card:hover {
    border-color: var(--line);
  }
  .card.selected {
    border-color: var(--acc-ink);
  }
  .card.changed {
    animation: flash 1.2s ease-out;
  }
  @keyframes flash {
    0% {
      border-color: var(--green);
      box-shadow: 0 0 0 1px var(--green);
    }
    100% {
      border-color: var(--hair);
      box-shadow: none;
    }
  }
  .follow {
    margin-left: auto;
    flex: none;
  }
  .follow.on {
    border-color: var(--green) !important;
    color: var(--green) !important;
  }
  .icon {
    font-family: var(--mono);
    font-weight: 700;
    font-size: 13px;
  }
  .card-name {
    font-size: 12.5px;
    color: var(--t2);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
  }
  .card.selected .card-name {
    color: var(--t1);
  }
  .meta {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .badges {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .badge {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    padding: 0 4px;
  }
</style>
