<script lang="ts">
  import { projects } from './project.svelte'
  import { layout } from './layout.svelte'
  import { tasks } from './notes/tasksStore.svelte'
  import { agent } from './orchestration/agentStore.svelte'
  import { cockpit } from './cockpit/cockpit.svelte'

  // 上下文面板（承 helm-pro.html `.ctx`）：当前项目 + Today 导航（真计数+可点跳转）
  // + 会话遥测块 + 坐标 chip + LOCAL 角标。遥测仍 mock（F8 账上待真流）。
  const projName = $derived(projects.current?.name ?? 'helm')

  $effect(() => {
    void tasks.load()
    void agent.loadRuns()
  })

  // 真计数:任务=启用中;Agent 收件箱=运行中(与 Today 视图同源)
  const todayNav = $derived([
    {
      label: '今日概览',
      ct: '⌘1',
      on: layout.mode === 'today',
      go: () => layout.setMode('today'),
    },
    {
      label: '任务',
      ct: String(tasks.tasks.filter((t) => t.enabled).length),
      on: layout.mode === 'journal',
      go: () => {
        layout.journalIntent = 'tasks'
        layout.setMode('journal')
      },
    },
    {
      label: 'Agent 收件箱',
      ct: String(agent.runs.filter((r) => r.status === 'running').length),
      on: layout.mode === 'cockpit' && cockpit.rightTab === 'agent',
      go: () => {
        cockpit.rightTab = 'agent'
        layout.setMode('cockpit')
      },
    },
  ])
  const telem = [
    ['SESSION', 'AAN·541GAQ'],
    ['MODEL', 'claude-opus-4.8'],
    ['TOKENS', '14213 / 1.0M'],
    ['AGENTS', '2 LIVE / 5 IDLE'],
    ['RAG', 'IDLE · 0 QUEUED'],
    ['UPTIME', '10:58:23 · LOCAL'],
  ]
</script>

<div class="ctxbody">
  <div class="cproj">
    <span class="pic" aria-hidden="true"></span>
    <div>
      <div class="pn">{projName}</div>
      <div class="pb">⎇ feat/notch-media</div>
    </div>
  </div>

  <div class="slab">Today</div>
  {#each todayNav as n (n.label)}
    <button class="nrow" class:on={n.on} onclick={n.go}>
      <span class="dot" aria-hidden="true"></span>{n.label}<span class="ct">{n.ct}</span>
    </button>
  {/each}

  <div class="telem">
    {#each telem as [k, v] (k)}
      <div><b>{k}</b> {v}</div>
    {/each}
  </div>

  <span class="coord" aria-hidden="true">X:0206 Y:0243</span>
  <div class="cornertag"><span class="live" aria-hidden="true">●</span> LOCAL · NO CLOUD</div>
</div>

<style>
  .ctxbody {
    position: relative;
    height: 100%;
  }
  .cproj {
    display: flex;
    align-items: center;
    gap: 9px;
    padding: 8px 9px;
    border: 1px solid var(--line);
    margin-bottom: 14px;
  }
  .cproj .pic {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    background: linear-gradient(135deg, #e8a07a, #b56a8f 55%, #6a4f8f);
    flex: none;
  }
  .cproj .pn {
    font-size: 13px;
    font-weight: 700;
    color: var(--t1);
  }
  .cproj .pb {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    margin-top: 1px;
  }
  .slab {
    font-family: var(--mono);
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--t3);
    margin: 16px 0 8px;
  }
  .nrow {
    display: flex;
    align-items: center;
    gap: 9px;
    font-size: 12.5px;
    color: var(--t3);
    padding: 6px 8px;
    width: 100%;
    background: transparent;
    border: 0;
    cursor: pointer;
    text-align: left;
    font-family: var(--sans);
  }
  .nrow:hover {
    color: var(--t1);
    background: var(--tile);
  }
  .nrow.on {
    color: var(--t1);
  }
  .nrow .dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: var(--t4);
  }
  .nrow.on .dot {
    background: var(--acc);
    box-shadow: 0 0 6px var(--acc);
  }
  .nrow .ct {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
  }
  .telem {
    margin-top: 18px;
    font-family: var(--mono);
    font-size: 10px;
    line-height: 1.75;
    color: var(--t3);
    letter-spacing: .3px;
  }
  .telem b {
    color: var(--t3);
    font-weight: 600;
  }
  .coord {
    position: absolute;
    right: 0;
    top: 0;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--t4);
    background: var(--chrome);
    border: 1px solid var(--hair);
    padding: 2px 5px;
  }
  .cornertag {
    position: absolute;
    left: 0;
    bottom: 6px;
    display: flex;
    align-items: center;
    gap: 5px;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--t4);
    border: 1px solid var(--hair);
    padding: 3px 7px;
  }
  .cornertag .live {
    color: var(--acc-ink);
  }
</style>
