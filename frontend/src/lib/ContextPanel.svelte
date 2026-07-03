<script lang="ts">
  import { projects } from './project.svelte'
  import { tasks } from './notes/tasksStore.svelte'
  import { notes } from './notes/notesStore.svelte'
  import { agent } from './orchestration/agentStore.svelte'

  // 上下文面板(承 helm-pro.html `.ctx`,内容重做):原 TODAY 导航与 Rail 重复
  // 已删;原遥测块全是阶段1假数据,2026-07-03 同日换真仪表——每行都有数据源,
  // 没有的行宁可不显示(真能用,不画饼)。
  const projName = $derived(projects.current?.name ?? 'helm')

  let backendLabel = $state('…')

  $effect(() => {
    void tasks.load()
    void notes.load()
    void agent.loadRuns()
    void (async () => {
      try {
        const r = await fetch('/healthz')
        const j = (await r.json()) as { version?: string }
        backendLabel = r.ok ? `OK · v${j.version ?? '?'}` : `HTTP ${r.status}`
      } catch {
        backendLabel = '离线'
      }
    })()
  })

  const enabledTasks = $derived(tasks.tasks.filter((t) => t.enabled).length)
  const todayNotes = $derived.by(() => {
    const today = new Date().toDateString()
    return notes.notes.filter((n) => n.created_at && new Date(n.created_at).toDateString() === today).length
  })
  const runningRuns = $derived(agent.runs.filter((r) => r.status === 'running').length)

  const telem = $derived([
    ['BACKEND', backendLabel],
    ['任务', `${enabledTasks} 启用 / ${tasks.tasks.length}`],
    ['今日记录', `${todayNotes} 条`],
    ['AGENT', `${runningRuns} 运行 / ${agent.runs.length} 历史`],
  ])
</script>

<div class="ctxbody">
  <div class="cproj">
    <span class="pic" aria-hidden="true"></span>
    <div>
      <div class="pn">{projName}</div>
      {#if projects.current?.path}
        <div class="pb" title={projects.current.path}>{projects.current.path}</div>
      {/if}
    </div>
  </div>

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
    max-width: 190px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
                .telem {
    font-variant-numeric: tabular-nums;
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
