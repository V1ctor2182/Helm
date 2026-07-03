<script lang="ts">
  import { projects } from './project.svelte'

  // 上下文面板（承 helm-pro.html `.ctx`）：当前项目 + 会话遥测块 + 坐标 chip
  // + LOCAL 角标。原 TODAY 导航列与左侧 Rail 重复,2026-07-03 用户拍板删除。
  // 遥测仍 mock(F8 账上待真流)。
  const projName = $derived(projects.current?.name ?? 'helm')
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
