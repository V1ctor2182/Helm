<script lang="ts">
  import { commands } from './commands.svelte'
  import { layout } from './layout.svelte'

  let query = $state('')
  let selected = $state(0)
  let inputEl = $state<HTMLInputElement>()

  const results = $derived(commands.search(query))

  // Focus on open; reset query/selection on close.
  $effect(() => {
    if (layout.paletteOpen) {
      inputEl?.focus()
    } else {
      query = ''
      selected = 0
    }
  })

  // Keep the highlighted row within range as results shrink.
  $effect(() => {
    if (selected > results.length - 1) selected = Math.max(0, results.length - 1)
  })

  function runAt(i: number) {
    const cmd = results[i]
    if (!cmd) return
    layout.closePalette()
    cmd.run()
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      layout.closePalette()
    } else if (e.key === 'ArrowDown') {
      e.preventDefault()
      selected = Math.min(selected + 1, results.length - 1)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      selected = Math.max(selected - 1, 0)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      runAt(selected)
    }
  }
</script>

{#if layout.paletteOpen}
  <!-- Backdrop is a real button so outside-click + keyboard both dismiss; the
       palette is a sibling (not nested) to avoid interactive nesting. -->
  <button class="overlay" aria-label="关闭命令面板" onclick={() => layout.closePalette()}
  ></button>
  <div class="palette" role="dialog" aria-modal="true" aria-label="命令面板">
    <input
      bind:this={inputEl}
      bind:value={query}
      {onkeydown}
      placeholder="输入命令…  (↑↓ 选择 · ⏎ 执行 · Esc 关闭)"
      aria-label="命令"
    />
    <ul role="listbox" aria-label="命令结果">
      {#each results as cmd, i (cmd.id)}
        <li role="option" aria-selected={i === selected} class:sel={i === selected}>
          <button class="row" onclick={() => runAt(i)} onmouseenter={() => (selected = i)}>
            <span class="title">{cmd.title}</span>
            <span class="group">{cmd.group}</span>
          </button>
        </li>
      {:else}
        <li class="empty">无匹配命令</li>
      {/each}
    </ul>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    border: 0;
    padding: 0;
    background: rgba(0, 0, 0, 0.5);
    -webkit-backdrop-filter: blur(6px);
    backdrop-filter: blur(6px);
    cursor: default;
    z-index: 100;
  }
  .palette {
    position: fixed;
    top: 18vh;
    left: 50%;
    transform: translateX(-50%);
    width: min(560px, 92vw);
    background: var(--chrome);
    border: 1px solid var(--line);
    border-radius: 12px;
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.55);
    z-index: 101;
    overflow: hidden;
    font-family: var(--sans);
  }
  input {
    width: 100%;
    border: 0;
    border-bottom: 1px solid var(--hair);
    background: transparent;
    color: var(--t1);
    caret-color: var(--acc);
    padding: 14px 16px;
    font-size: 15px;
    font-family: var(--sans);
    outline: none;
    box-sizing: border-box;
  }
  input::placeholder {
    color: var(--t4);
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 6px;
    max-height: 320px;
    overflow-y: auto;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    border: 0;
    background: transparent;
    color: var(--t2);
    padding: 9px 10px;
    border-radius: 8px;
    cursor: pointer;
    text-align: left;
    font-size: 14px;
  }
  li.sel .row {
    background: color-mix(in srgb, var(--acc) 14%, transparent);
    color: var(--t1);
  }
  .group {
    color: var(--t4);
    font-size: 11px;
    font-family: var(--mono);
    letter-spacing: .3px;
  }
  .empty {
    color: var(--t4);
    padding: 12px;
    font-size: 14px;
  }
</style>
