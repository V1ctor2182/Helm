<script lang="ts">
  import { onMount } from 'svelte'
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { chat } from './chatStore.svelte'
  import { compare } from './compareStore.svelte'
  import ProviderSettings from './ProviderSettings.svelte'
  import CompareView from './CompareView.svelte'

  let input = $state('')
  let showProviders = $state(false)
  let showCompare = $state(false)
  let newProviderId = $state<number | null>(null)
  let newModel = $state('')
  let newSystem = $state('')
  let msgsEl = $state<HTMLElement | null>(null)

  onMount(() => {
    void chat.loadProviders()
    void chat.loadSessions()
    return () => {
      chat.disconnect() // close the chat WS when leaving chat mode
      compare.disconnect()
    }
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

  let modelErr = $state('')

  async function startSession() {
    if (newProviderId == null) return
    // 模型留空 → 用该 provider 的第一个已知模型(一键接入不该让人猜模型名)
    const provider = chat.providers.find((p) => p.id === newProviderId)
    const model = newModel.trim() || provider?.models[0] || ''
    if (!model) return
    // claude-cli 只认别名或完整 claude-* id——错名(如 "claude")在这就拦,
    // 别让它进会话再被 CLI 一句英文报错弄懵
    if (
      provider?.type === 'claude-cli' &&
      !provider.models.includes(model) &&
      !model.startsWith('claude-')
    ) {
      modelErr = `这个 provider 只认:${provider.models.join(' / ')}(或完整 claude-* 模型 id)`
      return
    }
    modelErr = ''
    await chat.createSession(newProviderId, model, newSystem.trim() || null)
    newSystem = ''
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
      <input bind:value={newModel} list="model-list" placeholder="模型 id(留空用默认)" aria-label="模型" />
      <datalist id="model-list">
        {#each newProvider?.models ?? [] as m (m)}<option value={m}></option>{/each}
      </datalist>
      {#if modelErr}<p class="modelerr">{modelErr}</p>{/if}
      <input bind:value={newSystem} placeholder="system prompt(可选)" aria-label="系统提示词" />
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
              <span class="strow">
                {#if s.title?.startsWith('对比 ·')}<span class="cmptag">CMP</span>{/if}
                <span class="st">{s.title || `会话 ${s.id}`}</span>
              </span>
              <span class="sm">{s.model}</span>
            </button>
            <button class="sdel" aria-label={`删除会话 ${s.title || s.id}`} onclick={() => chat.deleteSession(s.id)}>×</button>
          </li>
        {/each}
      </ul>
    {/if}

    <button
      class="act prov cmpbtn"
      class:on={showCompare}
      onclick={() => {
        showCompare = !showCompare
        if (showCompare) showProviders = false
      }}>COMPARE</button>
    <button
      class="act prov"
      class:on={showProviders}
      onclick={() => {
        showProviders = !showProviders
        if (showProviders) showCompare = false
      }}>PROVIDERS</button>
  </aside>

  <main class="thread">
    {#if showCompare}
      <CompareView />
    {:else if showProviders}
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
          {#if m.role === 'assistant'}
            <div class="msg ai">
              <div class="who2"><span class="spark" aria-hidden="true"></span>Helm 大脑</div>
              <div class="md">{@html renderMd(m.content)}</div>
              {#if chat.streaming && i === chat.messages.length - 1}<span class="car" aria-hidden="true"></span>{/if}
            </div>
          {:else}
            <div class="msg user"><div class="ut">{m.content}</div></div>
          {/if}
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
  .modelerr {
    margin: 2px 0 0;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--red, #d33);
  }
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
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-sm);
    color: var(--t1);
    font-family: var(--sans);
    font-size: 12px;
    padding: 8px 10px;
  }
  .new select:focus,
  .new input:focus {
    outline: none;
  }
  .new select option {
    background: var(--panel);
    color: var(--t1);
  }
  .new input::placeholder {
    color: var(--t4);
  }
  .act {
    font: 500 11.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 7px 13px;
    cursor: pointer;
    transition: all .12s var(--ease);
  }
  .act:hover:not(:disabled) {
    color: var(--t1);
  }
  .act.pri {
    color: var(--onink);
    background: var(--t1);
    font-weight: 600;
  }
  .act.pri:disabled {
    background: var(--pill);
    color: var(--t4);
    cursor: default;
  }
  .act.stop {
    color: #fff;
    background: var(--red);
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
    gap: 2px;
    text-align: left;
    background: var(--card);
    border: 0;
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow);
    padding: 10px 12px;
    margin-bottom: 8px;
    cursor: pointer;
    transition: box-shadow .15s var(--ease);
  }
  .sess:hover {
    box-shadow: var(--shadow-lg);
  }
  .strow {
    display: flex;
    align-items: baseline;
    gap: 6px;
    min-width: 0;
  }
  .cmptag {
    font-family: var(--mono);
    font-size: 8px;
    letter-spacing: .5px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    padding: 0 3px;
    flex: none;
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
    box-shadow: 0 0 0 2px var(--card), 0 0 0 3.5px var(--t1), var(--shadow);
  }
  .sess.active .st {
    color: var(--t1);
  }
  .prov {
    letter-spacing: 1px;
  }
  .cmpbtn {
    margin-top: auto;
    margin-bottom: 8px;
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
  .msgs {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .msg {
    max-width: 72%;
    font-size: 13.5px;
    line-height: 1.55;
  }
  .msg.user {
    align-self: flex-end;
    background: var(--t1);
    color: var(--onink);
    border-radius: 18px 18px 4px 18px;
    padding: 10px 16px;
  }
  .msg.ai {
    align-self: flex-start;
    background: var(--card);
    border-radius: 18px 18px 18px 4px;
    padding: 12px 16px;
    box-shadow: var(--shadow);
  }
  .who2 {
    display: flex;
    align-items: center;
    gap: 7px;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
    margin-bottom: 6px;
  }
  .spark {
    width: 13px;
    height: 13px;
    border-radius: 50%;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .ut {
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
    margin: 10px 18px 16px;
    background: var(--card);
    border-radius: var(--radius-pill);
    box-shadow: var(--shadow);
    padding: 6px 6px 6px 20px;
  }
  .composer .car.big {
    display: none;
  }
  .composer input {
    flex: 1;
    background: transparent;
    border: 0;
    color: var(--t1);
    font-family: var(--sans);
    font-size: 14px;
    padding: 8px 0;
    min-width: 0;
  }
  .composer input::placeholder {
    color: var(--t4);
  }
  .composer input:focus {
    outline: none;
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
