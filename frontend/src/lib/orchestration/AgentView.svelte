<script lang="ts">
  import { onMount } from 'svelte'
  import { agent, type AcpEvent } from './agentStore.svelte'
  import { cockpit } from '../cockpit/cockpit.svelte'

  let prompt = $state('')

  onMount(() => void agent.loadRuns())

  function run() {
    agent.start(prompt, cockpit.cwd)
  }

  // One-line summary per ACP event: mono type tag + tone (no emoji — cockpit rule).
  function line(e: AcpEvent): { tag: string; tone: 'ok' | 'err' | 'warn' | 'acc' | 'dim'; text: string } {
    const d = e.data as Record<string, unknown>
    switch (e.type) {
      case 'status':
        return { tag: 'SESS', tone: 'ok', text: `会话开始 · ${(d.model as string) ?? ''}` }
      case 'message':
        return { tag: 'MSG', tone: 'dim', text: String(d.text ?? '') }
      case 'tool_call': {
        const input = d.input as Record<string, unknown> | undefined
        const target = input?.file_path ?? input?.path ?? input?.command ?? ''
        return { tag: 'TOOL', tone: 'acc', text: `${d.name as string} ${target ?? ''}`.trim() }
      }
      case 'tool_result':
        return { tag: d.is_error ? 'ERR' : 'OK', tone: d.is_error ? 'err' : 'ok', text: String(d.content ?? '').slice(0, 200) }
      case 'permission_request':
        return { tag: 'PERM', tone: 'warn', text: '请求权限确认' }
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
          tag: 'RATE',
          tone: warn ? 'warn' : 'dim',
          text: `${blocked ? '额度受限' : '额度状态'}${parts.filter(Boolean).length ? ' · ' + parts.filter(Boolean).join(' · ') : ''}`,
        }
      }
      case 'session_end':
        return { tag: 'END', tone: d.is_error ? 'err' : 'ok', text: String(d.result ?? '运行结束') }
      default:
        return { tag: 'EVT', tone: 'dim', text: e.type }
    }
  }
</script>

<section class="agent" aria-label="Agent 观测">
  <div class="toolrow">
    <div class="h">AGENT 观测</div>
    <span class="status s-{agent.status}">{agent.status}</span>
  </div>

  <form
    class="compose"
    onsubmit={(e) => {
      e.preventDefault()
      run()
    }}
  >
    <span class="car" aria-hidden="true"></span>
    <input
      placeholder={cockpit.cwd ? `在 ${cockpit.cwd} 里让 Claude Code 做…` : '先在左侧选一个项目目录…'}
      bind:value={prompt}
      aria-label="Agent 指令"
    />
    <button class="act pri" type="submit" disabled={agent.status === 'running' || !prompt.trim()}>
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
    <ul class="stream framed">
      {#each agent.events as e, i (i)}
        {@const l = line(e)}
        <li class="evt">
          <span class="tag t-{l.tone}" aria-hidden="true">{l.tag}</span>
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
    gap: 10px;
    padding: 12px 14px;
    height: 100%;
    overflow: auto;
    box-sizing: border-box;
    font-family: var(--sans);
    color: var(--t2);
  }
  .toolrow {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .status {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    text-transform: uppercase;
    color: var(--t4);
    border: 1px solid var(--line);
    padding: 0 6px;
  }
  .status.s-running {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .status.s-done {
    color: var(--green);
    border-color: var(--green);
  }
  .status.s-error {
    color: var(--red);
    border-color: var(--red);
  }
  .compose {
    display: flex;
    align-items: center;
    gap: 9px;
  }
  .car {
    width: 2px;
    height: 14px;
    background: var(--acc);
    flex: none;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .compose input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-size: 13px;
    padding: 3px 0 6px;
    min-width: 0;
  }
  .compose input::placeholder {
    color: var(--t4);
  }
  .compose input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .act {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 1px solid var(--line);
    padding: 4px 10px;
    cursor: pointer;
    flex: none;
    transition: color .12s var(--ease);
  }
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
    cursor: default;
  }
  /* 事件流 = 框选视口(活的 agent 输出),mono 类型标签左槽 */
  .framed {
    position: relative;
    border: 1px solid var(--line);
  }
  .framed::before,
  .framed::after {
    content: '';
    position: absolute;
    width: 9px;
    height: 9px;
    border: 1.4px solid var(--acc-ink);
  }
  .framed::before {
    top: -1px;
    left: -1px;
    border-right: none;
    border-bottom: none;
  }
  .framed::after {
    bottom: -1px;
    right: -1px;
    border-left: none;
    border-top: none;
  }
  .stream {
    list-style: none;
    margin: 0;
    padding: 8px 10px;
    display: flex;
    flex-direction: column;
    font-size: 12px;
  }
  .evt {
    display: flex;
    gap: 10px;
    padding: 3px 0;
    border-top: 1px solid var(--hair);
    align-items: baseline;
  }
  .evt:first-child {
    border-top: none;
  }
  .tag {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    flex: none;
    min-width: 34px;
    color: var(--t4);
  }
  .tag.t-ok {
    color: var(--green);
  }
  .tag.t-err {
    color: var(--red);
  }
  .tag.t-warn {
    color: var(--orange);
  }
  .tag.t-acc {
    color: var(--acc-ink);
  }
  .text {
    white-space: pre-wrap;
    word-break: break-word;
    color: var(--t2);
  }
  .history summary {
    cursor: pointer;
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: .5px;
    color: var(--t3);
  }
  .history ul {
    list-style: none;
    margin: 6px 0 0;
    padding: 0;
    font-size: 12px;
  }
  .history li {
    display: flex;
    gap: 8px;
    align-items: center;
    padding: 3px 0;
    border-top: 1px solid var(--hair);
  }
  .history li:first-child {
    border-top: none;
  }
  .badge {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    text-transform: uppercase;
    border: 1px solid var(--line);
    padding: 0 5px;
    color: var(--t4);
    flex: none;
  }
  .badge.completed {
    color: var(--green);
    border-color: var(--green);
  }
  .badge.failed {
    color: var(--red);
    border-color: var(--red);
  }
  .hprompt {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--t3);
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
