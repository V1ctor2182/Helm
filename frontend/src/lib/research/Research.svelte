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
</script>

<section class="research" aria-label="Deep Research">
  <header>
    <h2>🔍 Deep Research</h2>
    <span class="status status-{research.status}">{research.status}</span>
  </header>

  <form
    class="ask"
    onsubmit={(e) => {
      e.preventDefault()
      go()
    }}
  >
    <textarea
      placeholder="输入一个研究问题,引擎会多轮搜索、阅读、综合,产出带引用的报告…"
      bind:value={question}
      aria-label="研究问题"
      rows="2"
    ></textarea>
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
        <button type="button" onclick={() => research.stop()}>停止</button>
      {:else}
        <button type="submit" disabled={!question.trim() || research.providerId === null}>开始研究</button>
      {/if}
    </div>
  </form>

  {#if research.error}
    <p class="err" role="alert">{research.error}</p>
  {/if}

  {#if research.status === 'running'}
    <ul class="progress" aria-label="进度">
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
        <h4>关键结论</h4>
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
        <h4>来源 ({r.sources.length})</h4>
        <ol class="sources">
          {#each r.sources as s (s.url)}
            <li><a href={s.url} target="_blank" rel="noreferrer">{s.title || s.url}</a></li>
          {/each}
        </ol>
      {/if}
      <p class="meta">迭代 {r.rounds} 轮 · 状态 {research.current.status}</p>
      <div class="export">
        <button onclick={() => research.exportToMemory(research.current!.id)}>存入记忆</button>
        <button
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
              <span class="badge {s.status}">{s.status}</span>{s.question}
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
    gap: 10px;
    padding: 16px;
    overflow: auto;
    height: 100%;
    max-width: 820px;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  header h2 {
    margin: 0;
    font-size: 1.1rem;
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
  .ask textarea {
    width: 100%;
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
    resize: vertical;
    box-sizing: border-box;
  }
  .controls {
    display: flex;
    gap: 6px;
    margin-top: 6px;
  }
  .controls select {
    padding: 5px;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .controls button {
    margin-left: auto;
    padding: 5px 14px;
    border: 1px solid #cfcdd4;
    border-radius: 8px;
    background: #fff;
    cursor: pointer;
  }
  .progress {
    list-style: none;
    margin: 0;
    padding: 8px;
    background: #fafafa;
    border-radius: 8px;
    font-size: 0.8rem;
    font-family: ui-monospace, monospace;
    color: #666;
    max-height: 160px;
    overflow: auto;
  }
  .report h3 {
    margin: 6px 0;
  }
  .summary {
    white-space: pre-wrap;
    line-height: 1.5;
  }
  .claims {
    padding-left: 18px;
    line-height: 1.6;
  }
  .cite {
    font-size: 0.72rem;
    color: #4a6fff;
    margin-left: 2px;
    text-decoration: none;
  }
  .sources {
    padding-left: 18px;
    font-size: 0.85rem;
  }
  .sources a {
    color: #4a6fff;
  }
  .meta {
    color: #999;
    font-size: 0.78rem;
  }
  .export {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-wrap: wrap;
    margin-top: 8px;
  }
  .export button {
    padding: 4px 10px;
    border: 1px solid #cfcdd4;
    border-radius: 8px;
    background: #fff;
    cursor: pointer;
    font-size: 0.8rem;
  }
  .export button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .exmsg {
    font-size: 0.78rem;
    color: #1c7a40;
  }
  .history summary {
    cursor: pointer;
    font-size: 0.85rem;
    color: #777;
  }
  .history ul {
    list-style: none;
    margin: 6px 0 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .hbtn {
    border: 0;
    background: transparent;
    cursor: pointer;
    text-align: left;
    font-size: 0.85rem;
    display: flex;
    gap: 6px;
    align-items: center;
    width: 100%;
  }
  .badge {
    font-size: 0.66rem;
    border-radius: 999px;
    padding: 0 6px;
    background: #eee;
    color: #555;
    flex: none;
  }
  .badge.completed {
    background: #e6f6ec;
    color: #1c7a40;
  }
  .badge.stopped {
    background: #fff3d6;
    color: #9a6b00;
  }
  .badge.failed {
    background: #fbe8e6;
    color: #c0392b;
  }
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
  }
</style>
