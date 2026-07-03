<script lang="ts">
  // 驾驶舱左侧栏(承 FanBox,阶段3.5 结构#2):搜索入口(⌘K)、快速入口、
  // 收藏星标、Agent 项目+活跃度徽章;三个列表统一高亮「当前所在目录」。
  import { cockpit } from './cockpit.svelte'
  import { layout } from '../layout.svelte'

  const HOME = '~'
  const QUICK: { label: string; path: string }[] = [
    { label: 'Home', path: HOME },
    { label: '桌面', path: '~/Desktop' },
    { label: '文稿', path: '~/Documents' },
    { label: '下载', path: '~/Downloads' },
  ]

  function go(path: string) {
    cockpit.manualTakeover()
    void cockpit.browse(path)
  }

  function name(p: string): string {
    return p.split('/').filter(Boolean).pop() ?? p
  }

  function isActive(p: string): boolean {
    const cwd = cockpit.cwd
    if (!cwd) return false
    if (p === HOME) return /^\/(Users|home)\/[^/]+$/.test(cwd)
    return cwd.endsWith(p.slice(1)) // '~/Desktop' → 以 '/Desktop' 结尾
  }

  // 活跃度标签(承 FanBox fmtTime):刚刚/N 分钟前/N 小时前/N 天前
  let nowTick = $state(Date.now())
  $effect(() => {
    const t = setInterval(() => (nowTick = Date.now()), 30_000)
    return () => clearInterval(t)
  })

  function ago(ms: number | undefined): string {
    if (!ms) return ''
    const diff = nowTick - ms
    if (diff < 60_000) return '刚刚'
    if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m`
    if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h`
    return `${Math.floor(diff / 86_400_000)}d`
  }
</script>

<aside class="side" aria-label="驾驶舱侧栏">
  <button class="search" onclick={() => layout.openPalette()}>
    <span>搜索文件…</span>
    <kbd>⌘K</kbd>
  </button>

  <div class="sec">快速入口 / QUICK</div>
  <ul>
    {#each QUICK as q (q.path)}
      <li>
        <button class="row" class:active={isActive(q.path)} onclick={() => go(q.path)}>
          <span class="glyph">›</span>{q.label}
        </button>
      </li>
    {/each}
  </ul>

  <div class="sec">收藏 / FAV</div>
  <ul>
    {#each cockpit.favorites as f (f)}
      <li>
        <button class="row" class:active={cockpit.cwd === f} onclick={() => go(f)}>
          <span class="glyph">★</span><span class="nm" title={f}>{name(f)}</span>
        </button>
        <button class="unfav" aria-label={`取消收藏 ${name(f)}`} onclick={() => cockpit.toggleFavorite(f)}>×</button>
      </li>
    {:else}
      <li class="hint">右键目录 → 收藏</li>
    {/each}
  </ul>

  <div class="sec">Agent 项目 / PROJ</div>
  <ul>
    {#each cockpit.projects as pr (pr.path)}
      <li>
        <button class="row" class:active={cockpit.cwd === pr.path} onclick={() => go(pr.path)}>
          <span class="glyph">⌁</span><span class="nm" title={pr.path}>{pr.name}</span>
          {#if ago(cockpit.projectActivity[pr.path])}
            <span class="act">{ago(cockpit.projectActivity[pr.path])}</span>
          {/if}
        </button>
      </li>
    {:else}
      <li class="hint">还没有项目</li>
    {/each}
  </ul>
</aside>

<style>
  .side {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-height: 0;
    overflow-y: auto;
    border-right: 1px solid var(--hair);
    padding: 10px 0;
    background: var(--panel);
  }
  .search {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin: 0 10px 8px;
    padding: 6px 10px;
    background: var(--tile);
    border: 1px solid var(--line);
    color: var(--t4);
    font-size: 12px;
    cursor: pointer;
    text-align: left;
  }
  .search:hover {
    color: var(--t2);
    border-color: var(--acc);
  }
  .search kbd {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
  }
  .sec {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--t4);
    padding: 10px 12px 4px;
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  li {
    display: flex;
    align-items: center;
  }
  .row {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 7px;
    min-width: 0;
    background: transparent;
    border: 0;
    border-left: 2px solid transparent;
    color: var(--t2);
    font-size: 12px;
    padding: 4px 12px;
    cursor: pointer;
    text-align: left;
  }
  .row:hover {
    color: var(--t1);
    background: var(--tile);
  }
  .row.active {
    color: var(--t1);
    border-left-color: var(--acc);
    background: var(--tile);
  }
  .glyph {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t4);
    flex: none;
  }
  .row.active .glyph {
    color: var(--acc-ink);
  }
  .nm {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .act {
    margin-left: auto;
    flex: none;
    font-family: var(--mono);
    font-size: 9px;
    color: var(--green);
    font-variant-numeric: tabular-nums;
  }
  .unfav {
    background: transparent;
    border: 0;
    color: var(--t4);
    font-size: 11px;
    padding: 0 10px 0 4px;
    cursor: pointer;
    opacity: 0;
  }
  li:hover .unfav {
    opacity: 1;
  }
  .unfav:hover {
    color: var(--red, #d33);
  }
  .hint {
    color: var(--t4);
    font-size: 11px;
    padding: 3px 12px;
  }
</style>
