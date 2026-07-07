<script lang="ts">
  // 记录详情弹层(R16,用户:每条都可以点开看详情)。
  // 白大卡:完整内容 + AI meta 全量(大图/摘要/标签/来源/链接) + 时间 + 快捷操作。
  import type { Note } from './notesStore.svelte'
  import { localDateTime } from '../time'

  let {
    note,
    onclose,
    onedit,
    totask,
  }: {
    note: Note
    onclose: () => void
    onedit?: (n: Note) => void
    totask?: (n: Note) => void
  } = $props()

  const KIND_ZH: Record<string, string> = {
    note: '速记', journal: '日记', task: '待办', focus: '专注',
  }
  const TYPE_ZH: Record<string, string> = {
    youtube: '视频', paper: '论文', article: '网页', inspiration: '灵感', text: '速记',
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose()
  }
</script>

<svelte:window {onkeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="scrim" role="presentation" onclick={onclose}>
  <div class="sheet" role="dialog" aria-label="记录详情" tabindex="-1" onclick={(e) => e.stopPropagation()}>
    <header class="dh">
      <span class="kind">{TYPE_ZH[note.meta?.type ?? ''] ?? KIND_ZH[note.kind] ?? note.kind}</span>
      <span class="when">{note.created_at ? localDateTime(note.created_at) : ''}</span>
      <button class="x" aria-label="关闭" onclick={onclose}>×</button>
    </header>

    {#if note.meta?.image}
      <img class="hero" src={note.meta.image} alt="" />
    {/if}

    <div class="body">
      {#if note.meta?.title}
        <h2 class="ti">{note.meta.title}</h2>
      {/if}
      <p class="content">{note.content}</p>
      {#if note.meta?.summary}
        <div class="sumbox">
          <span class="spark" aria-hidden="true"></span>
          <p class="sum">{note.meta.summary}</p>
        </div>
      {/if}
      <div class="metarow">
        {#if note.meta?.site}<span class="site">{note.meta.site}</span>{/if}
        {#each note.meta?.tags ?? [] as t (t)}<span class="tag">#{t}</span>{/each}
        {#if note.meta?.when}<span class="kv">时间线索 · {note.meta.when}</span>{/if}
        {#if note.meta?.where}<span class="kv">地点线索 · {note.meta.where}</span>{/if}
      </div>
    </div>

    <footer class="acts">
      {#if note.meta?.url}
        <a class="pri" href={note.meta.url} target="_blank" rel="noreferrer">打开原链接</a>
      {/if}
      {#if onedit}<button onclick={() => { onedit?.(note); onclose() }}>编辑</button>{/if}
      {#if totask && note.kind !== 'journal'}<button onclick={() => { totask?.(note); onclose() }}>→任务</button>{/if}
      <button onclick={onclose}>关闭</button>
    </footer>
  </div>
</div>

<style>
  .scrim {
    position: fixed;
    inset: 0;
    background: color-mix(in srgb, var(--t1) 26%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 90;
    padding: 32px;
  }
  .sheet {
    width: min(560px, 92vw);
    max-height: 84vh;
    overflow-y: auto;
    background: var(--card);
    border-radius: 20px;
    box-shadow: var(--shadow-lg);
    display: flex;
    flex-direction: column;
  }
  .dh {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 18px 10px;
  }
  .kind {
    font: 600 11px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 5px 11px;
  }
  .when {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .x {
    margin-left: auto;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 0;
    background: var(--pill);
    color: var(--t3);
    font-size: 15px;
    cursor: pointer;
  }
  .x:hover { color: var(--t1); }
  .hero {
    width: 100%;
    max-height: 240px;
    object-fit: cover;
  }
  .body {
    padding: 14px 18px 6px;
  }
  .ti {
    font: 700 17px/1.35 var(--sans);
    color: var(--t1);
    margin: 0 0 8px;
  }
  .content {
    font: 400 13.5px/1.6 var(--sans);
    color: var(--t2);
    white-space: pre-wrap;
    word-break: break-word;
    margin: 0;
  }
  .sumbox {
    display: flex;
    gap: 9px;
    background: var(--bg);
    border-radius: var(--radius-sm);
    padding: 11px 13px;
    margin-top: 12px;
  }
  .spark {
    width: 13px;
    height: 13px;
    border-radius: 50%;
    flex: none;
    margin-top: 2px;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .sum {
    font: 400 12.5px/1.6 var(--sans);
    color: var(--t3);
    margin: 0;
  }
  .metarow {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    align-items: center;
  }
  .tag { color: var(--cyan); }
  .kv {
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 4px 10px;
  }
  .acts {
    display: flex;
    gap: 8px;
    padding: 14px 18px 16px;
    align-items: center;
  }
  .acts button,
  .acts a {
    font: 500 12px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 8px 15px;
    cursor: pointer;
    text-decoration: none;
  }
  .acts button:hover,
  .acts a:hover { color: var(--t1); }
  .acts .pri {
    color: #fff;
    background: var(--grad);
    font-weight: 600;
  }
</style>
