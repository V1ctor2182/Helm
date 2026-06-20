<script lang="ts">
  import { onMount } from 'svelte'
  import { chat } from './chatStore.svelte'
  import ProviderSettings from './ProviderSettings.svelte'

  let input = $state('')
  let showProviders = $state(false)
  let newProviderId = $state<number | null>(null)
  let newModel = $state('')

  onMount(() => {
    void chat.loadProviders()
    void chat.loadSessions()
    return () => chat.disconnect() // close the chat WS when leaving chat mode
  })

  const newProvider = $derived(chat.providers.find((p) => p.id === newProviderId) ?? null)

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
    <button class="prov-toggle" onclick={() => (showProviders = !showProviders)}>⚙ Providers</button>

    <section class="new">
      <h4>新会话</h4>
      <select bind:value={newProviderId} aria-label="provider">
        <option value={null}>选择 provider</option>
        {#each chat.providers as p (p.id)}<option value={p.id}>{p.name}</option>{/each}
      </select>
      <input
        bind:value={newModel}
        list="model-list"
        placeholder="模型 id"
        aria-label="模型"
      />
      <datalist id="model-list">
        {#each newProvider?.models ?? [] as m (m)}<option value={m}></option>{/each}
      </datalist>
      <button onclick={startSession} disabled={newProviderId == null || !newModel.trim()}>开始</button>
    </section>

    <h4>会话</h4>
    <ul class="sessions">
      {#each chat.sessions as s (s.id)}
        <li>
          <button class:active={chat.current?.id === s.id} onclick={() => chat.openSession(s.id)}>
            {s.title || `会话 ${s.id}`} · {s.model}
          </button>
        </li>
      {/each}
    </ul>
  </aside>

  <main class="thread">
    {#if showProviders}
      <ProviderSettings />
    {:else if !chat.current}
      <p class="empty">新建或选择一个会话开始对话。</p>
    {:else}
      <div class="msgs">
        {#each chat.messages as m, i (i)}
          <div class="msg {m.role}">
            <span class="who">{m.role}</span>
            <div class="body">{m.content}</div>
          </div>
        {/each}
      </div>
      <form class="composer" onsubmit={submit}>
        <input bind:value={input} placeholder="输入消息…" aria-label="消息" disabled={chat.streaming} />
        {#if chat.streaming}
          <button type="button" onclick={() => chat.stop()}>停止</button>
        {:else}
          <button type="submit">发送</button>
        {/if}
      </form>
    {/if}
    {#if chat.error}<p class="err">{chat.error}</p>{/if}
  </main>
</div>

<style>
  .chat { display: grid; grid-template-columns: 240px 1fr; height: 100%; min-height: 0; }
  .sidebar { border-right: 1px solid #e5e4e7; padding: 12px; overflow: auto; }
  .prov-toggle { width: 100%; margin-bottom: 10px; }
  .new { display: flex; flex-direction: column; gap: 6px; margin-bottom: 12px; }
  .new select, .new input { border: 1px solid #e5e4e7; border-radius: 8px; padding: 6px 8px; }
  h4 { margin: 6px 0; color: #888; font-size: 0.8rem; }
  .sessions { list-style: none; padding: 0; }
  .sessions button { width: 100%; text-align: left; border: 1px solid transparent; background: transparent; border-radius: 8px; padding: 6px 8px; cursor: pointer; }
  .sessions button.active { background: #eef1ff; }
  .thread { display: flex; flex-direction: column; min-width: 0; min-height: 0; }
  .msgs { flex: 1; overflow: auto; padding: 16px; }
  .msg { margin-bottom: 12px; }
  .msg .who { font-size: 0.72rem; color: #999; text-transform: uppercase; }
  .msg.user .body { color: #222; }
  .msg.assistant .body { color: #333; white-space: pre-wrap; }
  .composer { display: flex; gap: 8px; padding: 12px; border-top: 1px solid #e5e4e7; }
  .composer input { flex: 1; border: 1px solid #e5e4e7; border-radius: 8px; padding: 8px 10px; }
  .empty { color: #aaa; padding: 24px; }
  .err { color: #e5484d; padding: 0 16px; }
</style>
