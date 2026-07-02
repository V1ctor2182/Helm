<script lang="ts">
  // 设置模式:主题(黑/白/跟随 + 每日 accent)+ 后端连接 + MCP 注入状态。
  // 本机 hook / 媒体源属 notch 伴侣 app 侧,这里不重复(见 backlog)。
  import { onMount } from 'svelte'
  import { theme, PALETTE, type ThemeMode } from './theme.svelte'
  import { jsonFetch } from './api'

  const MODES: { id: ThemeMode; label: string }[] = [
    { id: 'system', label: '跟随系统' },
    { id: 'dark', label: '暗' },
    { id: 'light', label: '亮' },
  ]

  let backend = $state<{ ok: boolean; version?: string } | null>(null)
  let mcp = $state<{ config_path: string; exists: boolean; injected: boolean; error?: string | null } | null>(null)
  let mcpMsg = $state('')

  onMount(() => {
    void probe()
  })

  async function probe() {
    const h = (await jsonFetch('/healthz')) as { status: string; version: string } | null
    backend = h ? { ok: h.status === 'ok', version: h.version } : { ok: false }
    mcp = (await jsonFetch('/api/orchestration/mcp')) as typeof mcp
  }

  async function inject() {
    mcpMsg = ''
    const r = await jsonFetch('/api/orchestration/mcp', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ enabled: true }),
    })
    mcpMsg = r ? '已注入(合并+备份,不覆盖原有项)' : '注入失败(检查 .mcp.json 是否损坏)'
    await probe()
  }
</script>

<section class="settings" aria-label="设置">
  <header class="head">
    <h1>SETTINGS</h1>
    <span class="hd">设置</span>
    <span class="pg">LOCAL · NO CLOUD</span>
  </header>

  <div class="row">
    <div class="gut"><span class="tm">主题</span></div>
    <div>
      <div class="h">主题 / THEME</div>
      <div class="modes" role="radiogroup" aria-label="主题模式">
        {#each MODES as m (m.id)}
          <button
            class="act"
            class:on={theme.mode === m.id}
            role="radio"
            aria-checked={theme.mode === m.id}
            onclick={() => theme.setMode(m.id)}>{m.label}</button
          >
        {/each}
      </div>
      <div class="h ha">今日 ACCENT</div>
      <div class="swatches" role="radiogroup" aria-label="accent 颜色">
        {#each PALETTE as c (c)}
          <button
            class="sw"
            class:on={theme.accent === c}
            style={`background:${c}`}
            role="radio"
            aria-checked={theme.accent === c}
            aria-label={`accent ${c}`}
            onclick={() => theme.setAccent(c)}
          ></button>
        {/each}
      </div>
      <p class="note">每日自动轮换一色;手动选择仅本次会话生效(午夜回到当日色)。</p>
    </div>
  </div>

  <div class="row">
    <div class="gut"><span class="tm">连接</span></div>
    <div>
      <div class="h">后端 / BACKEND</div>
      {#if backend}
        <div class="line">
          <span class="dot" class:ok={backend.ok} class:bad={!backend.ok} aria-hidden="true"></span>
          <span class="mono">127.0.0.1:8769</span>
          <span class="mono dim">{backend.ok ? `ok · v${backend.version}` : '不可达'}</span>
        </div>
      {:else}
        <p class="empty">探测中…</p>
      {/if}
    </div>
  </div>

  <div class="row">
    <div class="gut"><span class="tm">MCP</span></div>
    <div>
      <div class="h">终端 AGENT 接入 / MCP</div>
      {#if mcp}
        <div class="line">
          <span class="dot" class:ok={mcp.injected} aria-hidden="true"></span>
          <span class="mono dim">{mcp.config_path}</span>
          <span class="badge" class:okb={mcp.injected}>{mcp.injected ? 'INJECTED' : 'NOT INJECTED'}</span>
        </div>
        {#if mcp.error}<p class="err">{mcp.error}</p>{/if}
        {#if !mcp.injected}
          <button class="act pri" onclick={inject}>注入 helm MCP 到 Claude Code(.mcp.json,合并+备份)</button>
        {/if}
        {#if mcpMsg}<p class="note ok-note">{mcpMsg}</p>{/if}
      {:else}
        <p class="empty">读取中…</p>
      {/if}
      <p class="note">让终端里的 Claude Code 直接读 Helm 的记忆 / RAG(helm_memory_* / helm_rag_search)。</p>
    </div>
  </div>
</section>

<style>
  .settings {
    height: 100%;
    overflow: auto;
    padding: 18px 24px 24px 0;
    font-family: var(--sans);
    color: var(--t2);
    max-width: 860px;
    box-sizing: border-box;
  }
  .head {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding-left: var(--gutter-w);
    margin-bottom: 6px;
  }
  .head h1 {
    font-family: var(--mono);
    font-size: 24px;
    font-weight: 800;
    letter-spacing: 1px;
    color: var(--t1);
    margin: 0;
  }
  .head .hd {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--acc-ink);
    font-weight: 700;
  }
  .head .pg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .5px;
  }
  .row {
    display: grid;
    grid-template-columns: var(--gutter-w) 1fr;
    border-top: 1px solid var(--hair);
    padding: 12px 0;
  }
  .row:first-of-type {
    border-top: none;
  }
  .gut {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    padding-top: 3px;
    letter-spacing: .3px;
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 8px;
  }
  .h.ha {
    margin-top: 14px;
  }
  .modes {
    display: flex;
    gap: 8px;
  }
  .act {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 12px;
    cursor: pointer;
    transition: color .12s var(--ease);
  }
  .act:hover {
    color: var(--t1);
  }
  .act.on,
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .swatches {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .sw {
    width: 16px;
    height: 16px;
    border: 1px solid transparent;
    border-radius: 3px; /* 色块允许 3px(DESIGN.md 例外) */
    cursor: pointer;
    padding: 0;
  }
  .sw.on {
    outline: 1.4px solid var(--t1);
    outline-offset: 2px;
  }
  .note {
    font-size: 11px;
    color: var(--t4);
    margin: 8px 0 0;
  }
  .note.ok-note {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--green);
  }
  .line {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 13px;
    margin-bottom: 8px;
  }
  .dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--t4);
    flex: none;
  }
  .dot.ok {
    background: var(--green);
  }
  .dot.bad {
    background: var(--red);
  }
  .mono {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t2);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .mono.dim {
    color: var(--t4);
  }
  .badge {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    border: 1px solid var(--line);
    padding: 0 5px;
    color: var(--t4);
    flex: none;
  }
  .badge.okb {
    color: var(--green);
    border-color: var(--green);
  }
  .err {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
    margin: 0 0 6px;
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
  }
</style>
