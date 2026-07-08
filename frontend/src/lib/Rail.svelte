<script lang="ts">
  // NOMI 白侧栏（阶段 4 R02，source: helm-journal-pro.html 侧栏块）。
  // 旧 ORAGE 细丝 Rail 退场;导航=图标+中文标签胶囊,底部圆形动作钮。
  import { MODES, type LayoutStore, type ModeId } from './layout.svelte'
  import { notes } from './notes/notesStore.svelte'
  import { chat } from './chat/chatStore.svelte'

  let { layout }: { layout: LayoutStore } = $props()

  // 单色 SVG 图标(禁 emoji,承约束 7ed866af)。
  const ICONS: Record<ModeId, string> = {
    today: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M3 11l9-7 9 7v9a1 1 0 01-1 1h-5v-6h-6v6H4a1 1 0 01-1-1z"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M21 12a8 8 0 01-8 8H4l2.4-2.4A8 8 0 1121 12z"/></svg>',
    research: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    memory: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="6" cy="7" r="2.3"/><circle cx="17" cy="6" r="2.3"/><circle cx="13" cy="17" r="2.3"/><path d="M8 8l4 8M15 8l-2 8"/></svg>',
    journal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 7h8M8 11h8M8 15h5"/></svg>',
    cockpit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="3" y="4" width="18" height="14" rx="2"/><path d="M7 9l3 3-3 3M13 15h4"/></svg>',
    settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="3"/><path d="M19.4 13.5a7.8 7.8 0 000-3l2-1.5-2-3.4-2.3 1a7.7 7.7 0 00-2.6-1.5L14 1.5h-4l-.5 2.6a7.7 7.7 0 00-2.6 1.5l-2.3-1-2 3.4 2 1.5a7.8 7.8 0 000 3l-2 1.5 2 3.4 2.3-1a7.7 7.7 0 002.6 1.5l.5 2.6h4l.5-2.6a7.7 7.7 0 002.6-1.5l2.3 1 2-3.4z"/></svg>',
  }
  // 中文标签(设计稿导航词);memory 设计稿未画,保留入口(功能不减)。
  const ZH: Record<ModeId, string> = {
    today: '今日', chat: '对话', research: '研究', memory: '记忆',
    journal: '记录', cockpit: '驾驶舱', settings: '设置',
  }
  // 用户娃娃脸 logo(#271C11 / 深色下反白)。
  const LOGO =
    '<svg viewBox="0 0 24 18" fill="none"><path d="M22.222 0.888916H0.888672V16.9254H22.222V0.888916Z" stroke="currentColor" stroke-width="1.77778"/><path d="M4.02295 10.074H5.82473C7.83554 10.074 9.46562 11.7041 9.46562 13.7149V14.0588H4.02295V10.074Z" fill="currentColor"/><path d="M12.7217 10.074H14.5235C16.5343 10.074 18.1644 11.7041 18.1644 13.7149V14.0588H12.7217V10.074Z" fill="currentColor"/><path d="M3.24561 8.89044C4.3147 8.09671 7.05548 6.9855 9.4658 8.89044" stroke="currentColor" stroke-width="1.77778" stroke-linecap="round"/><path d="M12.333 8.89044C13.4021 8.09671 16.1429 6.9855 18.5532 8.89044" stroke="currentColor" stroke-width="1.77778" stroke-linecap="round"/></svg>'
</script>

<nav class="rail" aria-label="Modes">
  <div class="brand">
    <span class="lg" aria-hidden="true">{@html LOGO}</span>
    <span class="nm">Helm</span>
  </div>

  <div class="navs">
    {#each MODES as m (m.id)}
      <button
        class="nv"
        class:on={layout.mode === m.id}
        aria-label={m.label}
        aria-current={layout.mode === m.id ? 'page' : undefined}
        onclick={() => layout.setMode(m.id)}
      >
        <span class="ic" aria-hidden="true">{@html ICONS[m.id]}</span>{ZH[m.id]}
        {#if m.id === 'journal' && notes.notes.length > 0}<span class="k">{notes.notes.length}</span>
        {:else if m.id === 'chat' && chat.sessions.length > 0}<span class="k">{chat.sessions.length}</span>{/if}
      </button>
    {/each}
  </div>

  {#if layout.mode === 'journal'}
    <div class="cats" aria-label="记录分类">
      <div class="subhead">记录</div>
      <!-- 「全部」退场(2026-07-08 用户反馈),速记为默认落地 -->
      {#each [['note', '速记'], ['journal', '日记'], ['task', '任务']] as [f, label] (f)}
        <button class="cat" class:on={layout.journalFilter === f} onclick={() => (layout.journalFilter = f as typeof layout.journalFilter)}>{label}</button>
      {/each}
      <div class="subhead">收藏</div>
      {#each [['collect', '全部收藏'], ['youtube', '视频'], ['paper', '论文'], ['inspiration', '灵感']] as [f, label] (f)}
        <button class="cat" class:on={layout.journalFilter === f} onclick={() => (layout.journalFilter = f as typeof layout.journalFilter)}>{label}</button>
      {/each}
    </div>
  {/if}

  <div class="foot">
    <button class="roundbtn" title="记一条 · ⌘N" aria-label="记一条" onclick={() => layout.openCapture()}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 4h8a2 2 0 012 2v12a2 2 0 01-2 2H8a2 2 0 01-2-2V6a2 2 0 012-2z"/><path d="M12 9v6M9 12h6"/></svg>
    </button>
    <button class="roundbtn" title="命令面板 · ⌘K" aria-label="命令面板" onclick={() => layout.openPalette()}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M6 4a2 2 0 012 2v4H6a2 2 0 110-4zM18 4a2 2 0 00-2 2v4h2a2 2 0 100-4zM6 20a2 2 0 002-2v-4H6a2 2 0 100 4zM18 20a2 2 0 01-2-2v-4h2a2 2 0 110 4z"/><rect x="8" y="10" width="8" height="4"/></svg>
    </button>
  </div>
</nav>

<style>
  .rail {
    width: 100%;
    height: 100%;
    background: var(--chrome);
    border-right: 1px solid var(--hair);
    display: flex;
    flex-direction: column;
    padding: 22px 18px;
    overflow: hidden;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 24px;
  }
  .lg {
    display: flex;
    color: var(--t1);
  }
  .lg :global(svg) {
    width: 26px;
    height: 20px;
  }
  .nm {
    font: 700 15px/1 var(--sans);
    color: var(--t1);
  }
  .navs {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .nv {
    display: flex;
    align-items: center;
    gap: 11px;
    font: 400 13.5px/1 var(--sans);
    color: var(--t3);
    background: transparent;
    border: 0;
    border-radius: var(--radius-sm);
    padding: 9px 14px;
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-micro) var(--ease), color var(--dur-micro) var(--ease);
  }
  .nv:hover {
    background: var(--pill);
    color: var(--t1);
  }
  .nv.on {
    background: var(--pill);
    color: var(--t1);
    font-weight: 600;
  }
  .ic {
    display: flex;
    flex: none;
  }
  .ic :global(svg) {
    width: 17px;
    height: 17px;
  }
  .k {
    margin-left: auto;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    font-variant-numeric: tabular-nums;
  }
  .cats {
    display: flex;
    flex-direction: column;
    gap: 2px;
    margin-top: 14px;
    overflow-y: auto;
    min-height: 0;
  }
  .subhead {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    letter-spacing: 0.4px;
    margin: 12px 14px 6px;
  }
  .cat {
    font: 400 13px/1 var(--sans);
    color: var(--t3);
    background: transparent;
    border: 0;
    border-radius: 10px;
    padding: 7px 14px;
    cursor: pointer;
    text-align: left;
  }
  .cat:hover {
    background: var(--pill);
    color: var(--t1);
  }
  .cat.on {
    background: var(--pill);
    color: var(--t1);
    font-weight: 600;
  }
  .foot {
    margin-top: auto;
    display: flex;
    gap: 10px;
  }
  .roundbtn {
    width: 44px;
    height: 44px;
    border-radius: 50%;
    border: 1px solid var(--hair);
    background: var(--card);
    color: var(--t3);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: border-color var(--dur-micro) var(--ease), color var(--dur-micro) var(--ease);
  }
  .roundbtn:hover {
    border-color: var(--t4);
    color: var(--t1);
  }
  .roundbtn :global(svg) {
    width: 18px;
    height: 18px;
  }
</style>
