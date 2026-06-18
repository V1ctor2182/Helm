<script lang="ts">
  import { MODES, type LayoutStore } from './layout.svelte'

  let { layout }: { layout: LayoutStore } = $props()
</script>

<nav class="rail" aria-label="Modes">
  {#each MODES as m (m.id)}
    <button
      class="mode"
      class:active={layout.mode === m.id}
      title={m.label}
      aria-label={m.label}
      aria-current={layout.mode === m.id ? 'page' : undefined}
      onclick={() => layout.setMode(m.id)}
    >
      <span class="icon">{m.icon}</span>
    </button>
  {/each}
</nav>

<style>
  .rail {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 8px 6px;
    background: #f1f0f3;
    border-right: 1px solid #e5e4e7;
  }
  .mode {
    width: 40px;
    height: 40px;
    border: 0;
    border-radius: 10px;
    background: transparent;
    font-size: 18px;
    cursor: pointer;
    display: grid;
    place-items: center;
  }
  .mode:hover {
    background: #e3e1e6;
  }
  .mode.active {
    background: #fff;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
  }
</style>
