<script lang="ts">
  import { onMount } from 'svelte'
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { chat } from './chatStore.svelte'
  import ProviderSettings from './ProviderSettings.svelte'

  let input = $state('')
  let showProviders = $state(false)
  let newProviderId = $state<number | null>(null)
  let newModel = $state('')
  let msgsEl = $state<HTMLElement | null>(null)

  onMount(() => {
    void chat.loadProviders()
    void chat.loadSessions()
    return () => chat.disconnect() // close the chat WS when leaving chat mode
  })

  const newProvider = $derived(chat.providers.find((p) => p.id === newProviderId) ?? null)

  // 新消息/流式增量到来时贴底(用户手动上滚超过一屏就不打扰)。
  $effect(() => {
    void chat.messages.length
    void chat.messages[chat.messages.length - 1]?.content
    const el = msgsEl
    if (el && el.scrollHeight - el.scrollTop - el.clientHeight < el.clientHeight) {
      el.scrollTop = el.scrollHeight
    }
  })

  function renderMd(src: string): string {
    return DOMPurify.sanitize(marked.parse(src ?? '', { async: false }) as string)
  }

  function submit(e: Event) {
    e.preventDefault()
    if (input.trim()) {
      chat.send(input)
      input = ''
    }
  }

  async function startSession() {
    if (newProviderId == null || !newModel.trim()) return
    await chat.createSession(newProviderId, newModel.trim())
    showProviders = false
  }
</script>

<div class="chat">
  <aside class="sidebar">
    <div class="h">新会话</div>
    <section class="new">
      <select bind:value={newProviderId} aria-label="provider">
        <option value={null}>选择 provider</option>
        {#each chat.providers as p (p.id)}<option value={p.id}>{p.name}</option>{/each}
      </select>
      <input bind:value={newModel} list="model-list" placeholder="模型 id" aria-label="模型" />
      <datalist id="model-list">
        {#each newProvider?.models ?? [] as m (m)}<option value={m}></option>{/each}
      </datalist>
      <button class="act pri" onclick={startSession} disabled={newProviderId == null || !newModel.trim()}>开始</button>
    </section>

    <div class="h hs">会话 / SESSIONS</div>
    {#if chat.sessions.length === 0}
      <p class="empty small">还没有会话。</p>
    {:else}
      <ul class="sessions">
        {#each chat.sessions as s (s.id)}
          <li class="srow">
            <button class="sess" class:active={chat.current?.id === s.id} onclick={() => chat.openSession(s.id)}>
              <span class="st">{s.title || `会话 ${s.id}`}</span>
              <span class="sm">{s.model}</span>
            </button>
            <button class="sdel" aria-label={`删除会话 ${s.title || s.id}`} onclick={() => chat.deleteSession(s.id)}>×</button>
          </li>
        {/each}
      </ul>
    {/if}

    <button class="act prov" class:on={showProviders} onclick={() => (showProviders = !showProviders)}>PROVIDERS</button>
  </aside>

  <main class="thread">
    {#if showProviders}
      <ProviderSettings />
    {:else if !chat.current}
      <div class="blank">
        <p class="empty">新建或选择一个会话开始对话。</p>
      </div>
    {:else}
      <header class="th">
        <span class="tt">{chat.current.title || `会话 ${chat.current.id}`}</span>
        <span class="tm">{chat.current.model}</span>
      </header>
      <div class="msgs" bind:this={msgsEl}>
        {#each chat.messages as m, i (i)}
          <div class="msg">
            <span class="who" class:you={m.role === 'user'}>{m.role === 'user' ? 'YOU' : 'MODEL'}</span>
            <div class="body">
              {#if m.role === 'assistant'}
                <div class="md">{@html renderMd(m.content)}</div>
                {#if chat.streaming && i === chat.messages.length - 1}<span class="car" aria-hidden="true"></span>{/if}
              {:else}
                <div class="ut">{m.content}</div>
              {/if}
            </div>
          </div>
        {/each}
      </div>
      <form class="composer" onsubmit={submit}>
        <span class="car big" aria-hidden="true"></span>
        <input bind:value={input} placeholder="输入消息…" aria-label="消息" disabled={chat.streaming} />
        {#if chat.streaming}
          <button type="button" class="act stop" onclick={() => chat.stop()}>停止</button>
        {:else}
          <button type="submit" class="act pri" disabled={!input.trim()}>发送</button>
        {/if}
      </form>
    {/if}
    {#if chat.error}<p class="err" role="alert">{chat.error}</p>{/if}
  </main>
</div>

<style>
  .chat {
    display: grid;
    grid-template-columns: 210px 1fr;
    height: 100%;
    min-height: 0;
    font-family: var(--sans);
    color: var(--t2);
  }
  .sidebar {
    border-right: 1px solid var(--hair);
    padding: 14px 12px;
    overflow: auto;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 7px;
  }
  .h.hs {
    margin-top: 16px;
  }
  .new {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .new select,
  .new input {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 11px;
    padding: 3px 0 5px;
  }
  .new select:focus,
  .new input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .new select option {
    background: var(--panel);
    color: var(--t1);
  }
  .new input::placeholder {
    color: var(--t4);
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
  }
  .act.pri:disabled {
    color: var(--t4);
    border-color: var(--line);
    cursor: default;
  }
  .act.stop {
    color: var(--red);
    border-color: var(--red);
  }
  .sessions {
    list-style: none;
    margin: 0;
    padding: 0;
    overflow: auto;
  }
  .srow {
    display: flex;
    align-items: center;
  }
  .srow .sess {
    flex: 1;
    min-width: 0;
  }
  .sdel {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    background: transparent;
    border: 0;
    padding: 2px 4px;
    cursor: pointer;
    opacity: 0;
    transition: opacity .12s var(--ease);
  }
  .srow:hover .sdel,
  .sdel:focus-visible {
    opacity: 1;
  }
  .sdel:hover {
    color: var(--red);
  }
  .sess {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1px;
    text-align: left;
    background: transparent;
    border: 0;
    border-left: 2px solid transparent;
    padding: 5px 8px;
    cursor: pointer;
  }
  .sess .st {
    color: var(--t2);
    font-size: 12.5px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .sess .sm {
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
    letter-spacing: .3px;
  }
  .sess:hover .st {
    color: var(--t1);
  }
  .sess.active {
    border-left-color: var(--acc);
  }
  .sess.active .st {
    color: var(--t1);
  }
  .prov {
    margin-top: auto;
    letter-spacing: 1px;
  }
  .prov.on {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  /* 线程:账本消息流(无气泡无卡片) */
  .thread {
    display: flex;
    flex-direction: column;
    min-width: 0;
    min-height: 0;
  }
  .th {
    display: flex;
    align-items: baseline;
    gap: 10px;
    padding: 12px 18px 8px;
    border-bottom: 1px solid var(--hair);
  }
  .th .tt {
    color: var(--t1);
    font-weight: 600;
    font-size: 13px;
  }
  .th .tm {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
  }
  .msgs {
    flex: 1;
    overflow: auto;
    padding: 12px 18px;
    max-width: 860px;
  }
  .msg {
    display: grid;
    grid-template-columns: 52px 1fr;
    gap: 10px;
    border-top: 1px solid var(--hair);
    padding: 9px 0;
  }
  .msg:first-child {
    border-top: none;
  }
  .who {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--t4);
    padding-top: 3px;
  }
  .who.you {
    color: var(--acc-ink);
  }
  .body {
    min-width: 0;
    font-size: 13px;
    line-height: 1.55;
  }
  .ut {
    color: var(--t1);
    white-space: pre-wrap;
    word-break: break-word;
  }
  .md {
    color: var(--t2);
    word-break: break-word;
    display: inline;
  }
  .md :global(p) {
    margin: .3em 0;
  }
  .md :global(p:first-child) {
    margin-top: 0;
  }
  .md :global(pre) {
    background: var(--tile);
    border: 1px solid var(--hair);
    padding: 8px 10px;
    overflow: auto;
    font-size: 12px;
  }
  .md :global(code) {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--t1);
  }
  .md :global(h1),
  .md :global(h2),
  .md :global(h3) {
    font-size: 13px;
    margin: .5em 0 .2em;
    color: var(--t1);
  }
  .md :global(a) {
    color: var(--acc-ink);
  }
  .md :global(ul),
  .md :global(ol) {
    padding-left: 1.3em;
    margin: .3em 0;
  }
  .car {
    width: 2px;
    height: 12px;
    background: var(--acc);
    display: inline-block;
    vertical-align: -1px;
    margin-left: 2px;
    animation: blink 1s steps(1) infinite;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .composer {
    display: flex;
    align-items: center;
    gap: 9px;
    padding: 10px 18px 14px;
    border-top: 1px solid var(--hair);
  }
  .composer .car.big {
    height: 14px;
    margin: 0;
    flex: none;
  }
  .composer input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 13px;
    padding: 4px 0 7px;
    min-width: 0;
  }
  .composer input::placeholder {
    color: var(--t4);
  }
  .composer input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .blank {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
  }
  .empty.small {
    margin: 2px 0;
    font-size: 12px;
  }
  .err {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--red);
    margin: 4px 18px 10px;
  }
</style>
