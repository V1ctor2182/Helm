<script lang="ts">
  import { onMount } from 'svelte'
  import { skills } from './skillsStore.svelte'

  onMount(() => void skills.load())
</script>

<section class="skills" aria-label="Skills">
  <header>
    <h2>⚡ Skills 透视</h2>
    {#if skills.total > 0}
      <span class="counts">
        {skills.total} 个 · <span class="ok">{skills.healthy} 健康</span>
        {#if skills.unhealthy > 0}· <span class="bad">{skills.unhealthy} 异常</span>{/if}
      </span>
    {/if}
  </header>

  {#if skills.error}
    <p class="err" role="alert">{skills.error}</p>
  {/if}

  {#if skills.skills.length === 0}
    <p class="empty">没有发现 skills(默认扫描 ~/.claude/skills 与项目 .claude/skills)。</p>
  {:else}
    <ul class="list">
      {#each skills.skills as s (s.name)}
        <li class="skill" class:disabled={!s.enabled} class:unhealthy={!s.healthy}>
          <div class="top">
            <span class="name">{s.name}</span>
            <span class="badge" class:ok={s.healthy} class:bad={!s.healthy}>
              {s.healthy ? '健康' : '异常'}
            </span>
            <label class="switch" title={s.enabled ? '已启用' : '已停用'}>
              <input
                type="checkbox"
                checked={s.enabled}
                aria-label={`启用 ${s.name}`}
                onchange={() => skills.toggle(s)}
              />
              <span class="track" aria-hidden="true"></span>
            </label>
          </div>
          <p class="desc">{s.description || (s.error ?? '—')}</p>
          <div class="foot">
            <span class="uses">触发 {s.uses} 次{#if s.last_used} · 最近 {s.last_used.slice(0, 10)}{/if}</span>
            <span class="path">{s.path}</span>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</section>

<style>
  .skills {
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
  .counts {
    font-size: 0.8rem;
    color: #888;
  }
  .ok {
    color: #1c7a40;
  }
  .bad {
    color: #c0392b;
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .skill {
    border: 1px solid #eceaef;
    border-radius: 10px;
    padding: 8px 10px;
    background: #fff;
  }
  .skill.disabled {
    opacity: 0.55;
  }
  .skill.unhealthy {
    border-color: #f3c9c4;
  }
  .top {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .name {
    font-weight: 600;
    font-family: ui-monospace, monospace;
  }
  .badge {
    font-size: 0.68rem;
    border-radius: 999px;
    padding: 1px 8px;
  }
  .badge.ok {
    background: #e6f6ec;
    color: #1c7a40;
  }
  .badge.bad {
    background: #fbe8e6;
    color: #c0392b;
  }
  .switch {
    margin-left: auto;
    cursor: pointer;
  }
  .switch input {
    accent-color: #7a5cff;
  }
  .desc {
    margin: 4px 0;
    font-size: 0.88rem;
    color: #444;
  }
  .foot {
    display: flex;
    justify-content: space-between;
    gap: 8px;
    font-size: 0.72rem;
    color: #999;
  }
  .path {
    font-family: ui-monospace, monospace;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 50%;
  }
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
  }
</style>
