<script lang="ts">
  import { layout, type ModeId } from './layout.svelte'
  import { projects } from './project.svelte'

  // Today aggregates "what to look at / do now". Each module is a placeholder
  // here; its owning feature Room fills in real data (tasks→F6, recent
  // projects/agent→F1, urgent mail→F7). Clicking a module enters its mode.
  interface Module {
    title: string
    blurb: string
    mode: ModeId
  }

  const modules: Module[] = [
    { title: '今日任务 / 提醒', blurb: '到期任务与提醒（记录 Room）', mode: 'journal' },
    { title: '日记 · 今日小结', blurb: '写两行 + AI 小结（记录 Room）', mode: 'journal' },
    { title: '最近项目', blurb: '续上 agent 会话（驾驶舱）', mode: 'cockpit' },
    { title: 'Agent 活动 / 变更收件箱', blurb: '看 agent 改了什么（驾驶舱）', mode: 'cockpit' },
    { title: '日历 / 日程', blurb: '事件与 CalDAV 同步（记录 Room）', mode: 'journal' },
  ]

  function go(mode: ModeId) {
    layout.setMode(mode)
  }

  function newChat() {
    layout.setMode('chat')
    layout.openTab('New Chat', 'chat')
  }

  function newResearch() {
    layout.setMode('research')
    layout.openTab('Research', 'research')
  }
</script>

<div class="today">
  <header class="top">
    <h1>Today</h1>
    <div class="project">
      {#if projects.current}
        当前项目：<strong>{projects.current.name}</strong>
      {:else}
        <span class="muted">未选择项目</span>
      {/if}
    </div>
  </header>

  <section class="quick" aria-label="快速动作">
    <button onclick={newChat}>＋ 新建 Chat</button>
    <button onclick={newResearch}>🔍 发起研究</button>
    <button onclick={() => layout.openCapture()}>📝 速记</button>
  </section>

  <section class="grid" aria-label="今日聚合">
    {#each modules as m (m.title)}
      <button class="card" onclick={() => go(m.mode)}>
        <span class="card-title">{m.title}</span>
        <span class="card-blurb">{m.blurb}</span>
      </button>
    {/each}
  </section>
</div>

<style>
  .today {
    height: 100%;
    overflow: auto;
    padding: 24px;
    box-sizing: border-box;
  }
  .top {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    margin-bottom: 16px;
  }
  h1 {
    margin: 0;
    font-weight: 600;
  }
  .project {
    font-size: 0.9rem;
    color: #555;
  }
  .muted {
    color: #aaa;
  }
  .quick {
    display: flex;
    gap: 8px;
    margin-bottom: 20px;
  }
  .quick button {
    border: 1px solid #e5e4e7;
    background: #fff;
    border-radius: 10px;
    padding: 8px 14px;
    cursor: pointer;
    font-size: 14px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 12px;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: 6px;
    text-align: left;
    border: 1px solid #e5e4e7;
    border-radius: 12px;
    background: #fff;
    padding: 14px;
    cursor: pointer;
    min-height: 84px;
  }
  .card:hover {
    border-color: #c9c8cf;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  }
  .card-title {
    font-weight: 600;
    font-size: 0.95rem;
  }
  .card-blurb {
    color: #888;
    font-size: 0.82rem;
  }
</style>
