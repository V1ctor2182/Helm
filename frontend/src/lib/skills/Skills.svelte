<script lang="ts">
  import { onMount } from 'svelte'
  import { skills } from './skillsStore.svelte'

  onMount(() => void skills.load())
</script>

<section class="skills" aria-label="Skills">
  <div class="toolrow">
    <div class="h">SKILLS 透视</div>
    {#if skills.total > 0}
      <span class="counts">
        {skills.total} 个 · <span class="ok">{skills.healthy} 健康</span>
        {#if skills.unhealthy > 0}· <span class="bad">{skills.unhealthy} 异常</span>{/if}
      </span>
    {/if}
  </div>

  {#if skills.error}
    <p class="err" role="alert">{skills.error}</p>
  {/if}

  {#if skills.skills.length === 0}
    <p class="empty">没有发现 skills(默认扫描 ~/.claude/skills 与项目 .claude/skills)。</p>
  {:else}
    <ul class="list">
      {#each skills.skills as s (s.name)}
        <li class="skill" class:off={!s.enabled}>
          <div class="top">
            <input
              type="checkbox"
              class="cbx"
              checked={s.enabled}
              aria-label={`启用 ${s.name}`}
              onchange={() => skills.toggle(s)}
            />
            <span class="name">{s.name}</span>
            <span class="badge" class:okb={s.healthy} class:badb={!s.healthy}>
              {s.healthy ? '健康' : '异常'}
            </span>
            <span class="uses">触发 {s.uses} 次{#if s.last_used} · 最近 {s.last_used.slice(0, 10)}{/if}</span>
          </div>
          <p class="desc">{s.description || (s.error ?? '—')}</p>
          <span class="path">{s.path}</span>
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
  .counts {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .ok {
    color: var(--green);
  }
  .bad {
    color: var(--red);
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .skill {
    padding: 7px 0;
    border-top: 1px solid var(--hair);
  }
  .skill:first-child {
    border-top: none;
  }
  .skill.off .name,
  .skill.off .desc {
    color: var(--t4);
  }
  .top {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .cbx {
    appearance: none;
    width: 13px;
    height: 13px;
    border: 1.4px solid var(--t4);
    background: transparent;
    flex: none;
    cursor: pointer;
    margin: 0;
  }
  .cbx:checked {
    border-color: var(--acc-ink);
    background: var(--acc);
  }
  .name {
    font-family: var(--mono);
    font-size: 12px;
    font-weight: 600;
    color: var(--t1);
  }
  .badge {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    border: 1px solid var(--line);
    padding: 0 5px;
    color: var(--t4);
  }
  .badge.okb {
    color: var(--green);
    border-color: var(--green);
  }
  .badge.badb {
    color: var(--red);
    border-color: var(--red);
  }
  .uses {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .desc {
    margin: 3px 0 2px 23px;
    font-size: 12.5px;
    color: var(--t3);
  }
  .path {
    display: block;
    margin-left: 23px;
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
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
