<script lang="ts">
  import { onMount } from 'svelte'
  import { research } from './researchStore.svelte'
  import { cockpit } from '../cockpit/cockpit.svelte'

  let question = $state('')

  onMount(() => {
    void research.loadProviders()
    void research.loadSessions()
  })

  function go() {
    research.start(question)
  }

  // Map a claim's source URLs to [n] citation indices into the report's source list.
  function citeIndex(url: string): number {
    const srcs = research.current?.report?.sources ?? []
    return srcs.findIndex((s) => s.url === url) + 1
  }

  const pad3 = (n: number) => String(n).padStart(3, '0')
</script>

<section class="research" aria-label="Deep Research">
  <header class="head">
    <h1>RESEARCH</h1>
    <span class="hd">研究</span>
    <span class="status s-{research.status}">{research.status}</span>
    <span class="pg">{pad3(research.sessions.length)} SESSIONS</span>
  </header>

  <form
    class="ask"
    onsubmit={(e) => {
      e.preventDefault()
      go()
    }}
  >
    <div class="askrow">
      <span class="car" aria-hidden="true"></span>
      <textarea
        placeholder="输入一个研究问题,引擎会多轮搜索、阅读、综合,产出带引用的报告…"
        bind:value={question}
        aria-label="研究问题"
        rows="2"
      ></textarea>
    </div>
    <div class="controls">
      <select
        aria-label="模型 provider"
        value={research.providerId ?? ''}
        onchange={(e) => research.selectProvider(Number((e.target as HTMLSelectElement).value))}
      >
        {#each research.providers as p (p.id)}
          <option value={p.id}>{p.name}</option>
        {/each}
      </select>
      <select bind:value={research.model} aria-label="模型">
        {#each research.providers.find((p) => p.id === research.providerId)?.models ?? [] as m (m)}
          <option value={m}>{m}</option>
        {/each}
      </select>
      {#if research.status === 'running'}
        <button type="button" class="act stop" onclick={() => research.stop()}>停止</button>
      {:else}
        <button type="submit" class="act pri" disabled={!question.trim() || research.providerId === null}>开始研究</button>
      {/if}
    </div>
  </form>

  {#if research.error}
    <p class="err" role="alert">{research.error}</p>
  {/if}

  {#if research.status === 'running'}
    <ul class="progress framed" aria-label="进度">
      {#each research.progress as p, i (i)}
        <li>{p.kind}{#if p.round} · 第 {p.round} 轮{/if}{#if p.url} · {p.url}{/if}</li>
      {/each}
    </ul>
  {/if}

  {#if research.current?.report}
    {@const r = research.current.report}
    <article class="report">
      <h3>{r.question}</h3>
      <p class="summary">{r.summary}</p>
      {#if r.claims.length}
        <div class="h">关键结论 / CLAIMS</div>
        <ul class="claims">
          {#each r.claims as c (c.text)}
            <li>
              {c.text}
              {#each c.sources as u (u)}<a class="cite" href={u} target="_blank" rel="noreferrer">[{citeIndex(u)}]</a>{/each}
            </li>
          {/each}
        </ul>
      {/if}
      {#if r.sources.length}
        <div class="h">来源 / SOURCES ({r.sources.length})</div>
        <ol class="sources">
          {#each r.sources as s (s.url)}
            <li><a href={s.url} target="_blank" rel="noreferrer">{s.title || s.url}</a></li>
          {/each}
        </ol>
      {/if}
      <p class="meta">迭代 {r.rounds} 轮 · 状态 {research.current.status}</p>
      <div class="export">
        <button class="act" onclick={() => research.exportToMemory(research.current!.id)}>存入记忆</button>
        <button
          class="act"
          disabled={!cockpit.cwd}
          title={cockpit.cwd ? `写入 ${cockpit.cwd}` : '先在驾驶舱选一个项目目录'}
          onclick={() => research.exportToFile(research.current!.id, `${cockpit.cwd}/research-${research.current!.id}.md`)}
        >导出 Markdown 到项目</button>
        {#if research.exportMsg}<span class="exmsg">{research.exportMsg}</span>{/if}
      </div>
    </article>
  {:else if research.status !== 'running'}
    <p class="empty">输入问题开始一次深度研究,或从下方历史里打开一份报告。</p>
  {/if}

  {#if research.sessions.length}
    <details class="history">
      <summary>历史研究 ({research.sessions.length})</summary>
      <ul>
        {#each research.sessions as s (s.id)}
          <li>
            <button class="hbtn" onclick={() => research.openSession(s.id)}>
              <span class="badge {s.status}">{s.status}</span><span class="hq">{s.question}</span>
            </button>
          </li>
        {/each}
      </ul>
    </details>
  {/if}
</section>

<style>
  .research {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 18px 24px 18px 18px;
    overflow: auto;
    height: 100%;
    box-sizing: border-box;
    max-width: 860px;
    font-family: var(--sans);
    color: var(--t2);
  }
  .head {
    display: flex;
    align-items: baseline;
    gap: 12px;
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
  .status {
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
  .head .pg {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: .5px;
    font-variant-numeric: tabular-nums;
  }
  .ask {
    border-bottom: 1px solid var(--hair);
    padding-bottom: 10px;
  }
  .askrow {
    display: flex;
    align-items: flex-start;
    gap: 9px;
  }
  .car {
    width: 2px;
    height: 14px;
    background: var(--acc);
    flex: none;
    margin-top: 5px;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .ask textarea {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 13px;
    padding: 3px 0 6px;
    resize: vertical;
    min-width: 0;
  }
  .ask textarea::placeholder {
    color: var(--t4);
  }
  .ask textarea:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .controls {
    display: flex;
    gap: 12px;
    margin-top: 8px;
    padding-left: 11px;
  }
  .controls select {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 11px;
    padding: 3px 0 5px;
  }
  .controls select option {
    background: var(--panel);
    color: var(--t1);
  }
  .controls select:focus {
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
    transition: color .12s var(--ease);
  }
  .act:hover:not(:disabled) {
    color: var(--t1);
  }
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
    margin-left: auto;
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
    cursor: default;
  }
  .act.stop {
    color: var(--red);
    border-color: var(--red);
    margin-left: auto;
  }
  /* 进度 = 框选视口(活的过程) */
  .progress {
    list-style: none;
    margin: 0;
    padding: 9px 12px;
    font-size: 10.5px;
    font-family: var(--mono);
    color: var(--t3);
    max-height: 160px;
    overflow: auto;
  }
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
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin: 10px 0 5px;
  }
  .report h3 {
    margin: 4px 0 6px;
    font-size: 15px;
    color: var(--t1);
  }
  .summary {
    white-space: pre-wrap;
    line-height: 1.55;
    font-size: 13px;
    color: var(--t2);
    margin: 0;
  }
  .claims {
    padding-left: 18px;
    line-height: 1.6;
    font-size: 13px;
    margin: 0;
  }
  .cite {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--acc-ink);
    margin-left: 3px;
    text-decoration: none;
    font-variant-numeric: tabular-nums;
  }
  .sources {
    padding-left: 18px;
    font-size: 12px;
    margin: 0;
    line-height: 1.6;
  }
  .sources a {
    color: var(--acc-ink);
    text-decoration: none;
  }
  .sources a:hover {
    text-decoration: underline;
  }
  .meta {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    margin: 8px 0 0;
    font-variant-numeric: tabular-nums;
  }
  .export {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
    margin-top: 8px;
  }
  .exmsg {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--green);
  }
  .history {
    border-top: 1px solid var(--hair);
    padding-top: 8px;
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
    margin: 8px 0 0;
    padding: 0;
  }
  .history li {
    border-top: 1px solid var(--hair);
  }
  .history li:first-child {
    border-top: none;
  }
  .hbtn {
    border: 0;
    background: transparent;
    cursor: pointer;
    text-align: left;
    font-size: 12.5px;
    color: var(--t2);
    display: flex;
    gap: 8px;
    align-items: center;
    width: 100%;
    padding: 4px 0;
  }
  .hbtn:hover .hq {
    color: var(--t1);
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
  .badge.stopped {
    color: var(--orange);
    border-color: var(--orange);
  }
  .badge.failed {
    color: var(--red);
    border-color: var(--red);
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
