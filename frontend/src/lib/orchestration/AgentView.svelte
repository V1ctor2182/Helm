<script lang="ts">
  import { onMount } from 'svelte'
  import { agent, type AcpEvent } from './agentStore.svelte'
  import { cockpit } from '../cockpit/cockpit.svelte'

  let prompt = $state('')

  onMount(() => void agent.loadRuns())

  function run() {
    agent.start(prompt, cockpit.cwd)
  }

  // One-line summary per ACP event for the live stream.
  function line(e: AcpEvent): { icon: string; text: string } {
    const d = e.data as Record<string, unknown>
    switch (e.type) {
      case 'status':
        return { icon: '🟢', text: `会话开始 · ${(d.model as string) ?? ''}` }
      case 'message':
        return { icon: '💬', text: String(d.text ?? '') }
      case 'tool_call': {
        const input = d.input as Record<string, unknown> | undefined
        const target = input?.file_path ?? input?.path ?? input?.command ?? ''
        return { icon: '🔧', text: `${d.name as string} ${target ?? ''}`.trim() }
      }
      case 'tool_result':
        return { icon: d.is_error ? '⚠️' : '✓', text: String(d.content ?? '').slice(0, 200) }
      case 'permission_request':
        return { icon: '🔐', text: '请求权限确认' }
      case 'rate_limit': {
        const blocked = d.status !== 'allowed'
        const overageOut = d.overage_status === 'rejected'
        const reset =
          typeof d.resets_at === 'number'
            ? new Date(d.resets_at * 1000).toLocaleTimeString()
            : ''
        const warn = blocked || overageOut
        const parts = [d.limit_type as string, overageOut ? '超额额度已用尽' : '', reset ? `${reset} 重置` : '']
        return {
          icon: warn ? '⏳' : '📊',
          text: `${blocked ? '额度受限' : '额度状态'}${parts.filter(Boolean).length ? ' · ' + parts.filter(Boolean).join(' · ') : ''}`,
        }
      }
      case 'session_end':
        return { icon: d.is_error ? '🔴' : '🏁', text: String(d.result ?? '运行结束') }
      default:
        return { icon: '•', text: e.type }
    }
  }
</script>

<section class="agent" aria-label="Agent 观测">
  <header>
    <h3>🤖 Agent</h3>
    <span class="status status-{agent.status}">{agent.status}</span>
  </header>

  <form
    class="run"
    onsubmit={(e) => {
      e.preventDefault()
      run()
    }}
  >
    <input
      placeholder={cockpit.cwd ? `在 ${cockpit.cwd} 里让 Claude Code 做…` : '先在左侧选一个项目目录…'}
      bind:value={prompt}
      aria-label="Agent 指令"
    />
    <button type="submit" disabled={agent.status === 'running' || !prompt.trim()}>
      {agent.status === 'running' ? '运行中…' : '运行'}
    </button>
  </form>

  {#if agent.error}
    <p class="err" role="alert">{agent.error}</p>
  {/if}

  {#if agent.events.length === 0}
    <p class="empty">
      {agent.status === 'running' ? '等待 agent 输出…' : '运行一条指令,这里实时显示 agent 的工具调用与消息。'}
    </p>
  {:else}
    <ul class="stream">
      {#each agent.events as e, i (i)}
        {@const l = line(e)}
        <li class="evt evt-{e.type}">
          <span class="icon" aria-hidden="true">{l.icon}</span>
          <span class="text">{l.text}</span>
        </li>
      {/each}
    </ul>
  {/if}

  {#if agent.runs.length > 0}
    <details class="history">
      <summary>历史运行 ({agent.runs.length})</summary>
      <ul>
        {#each agent.runs as r (r.id)}
          <li>
            <span class="badge {r.status}">{r.status}</span>
            <span class="hprompt">{r.prompt ?? ''}</span>
          </li>
        {/each}
      </ul>
    </details>
  {/if}
</section>

<style>
  .agent {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
    height: 100%;
    overflow: auto;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  header h3 {
    margin: 0;
    font-size: 0.95rem;
  }
  .status {
    font-size: 0.72rem;
    text-transform: uppercase;
    border-radius: 999px;
    padding: 1px 8px;
    background: #eee;
    color: #666;
  }
  .status-running {
    background: #fff3d6;
    color: #9a6b00;
  }
  .status-done {
    background: #e6f6ec;
    color: #1c7a40;
  }
  .status-error {
    background: #fbe8e6;
    color: #c0392b;
  }
  .run {
    display: flex;
    gap: 6px;
  }
  .run input {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .stream {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.85rem;
  }
  .evt {
    display: flex;
    gap: 8px;
    padding: 4px 6px;
    border-radius: 6px;
    background: #fafafa;
  }
  .evt-tool_call {
    background: #f0f4ff;
    font-family: ui-monospace, monospace;
  }
  .evt-session_end {
    background: #f3fff6;
  }
  .icon {
    flex: none;
  }
  .text {
    white-space: pre-wrap;
    word-break: break-word;
  }
  .history summary {
    cursor: pointer;
    font-size: 0.8rem;
    color: #777;
  }
  .history ul {
    list-style: none;
    margin: 6px 0 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 0.8rem;
  }
  .history li {
    display: flex;
    gap: 6px;
    align-items: center;
  }
  .badge {
    font-size: 0.66rem;
    border-radius: 999px;
    padding: 0 6px;
    background: #eee;
    color: #555;
  }
  .badge.completed {
    background: #e6f6ec;
    color: #1c7a40;
  }
  .badge.failed {
    background: #fbe8e6;
    color: #c0392b;
  }
  .hprompt {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
    font-size: 0.85rem;
  }
</style>
