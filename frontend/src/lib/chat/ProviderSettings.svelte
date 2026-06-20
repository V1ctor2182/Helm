<script lang="ts">
  import { onMount } from 'svelte'
  import { chat, type Template } from './chatStore.svelte'

  let selected = $state<Template | null>(null)
  let name = $state('')
  let baseUrl = $state('')
  let apiKey = $state('')
  let testResult = $state('')

  onMount(() => {
    void chat.loadTemplates()
    void chat.loadProviders()
  })

  function pick(t: Template) {
    selected = t
    name = t.name
    baseUrl = t.base_url
    apiKey = ''
  }

  async function add() {
    if (!selected) return
    await chat.addProvider({
      type: selected.type,
      name,
      base_url: baseUrl,
      api_key: apiKey || undefined,
    })
    selected = null
    name = baseUrl = apiKey = ''
  }

  async function test(id: number) {
    const r = await chat.testProvider(id)
    testResult = r.ok ? `OK：${(r.models ?? []).join(', ') || '已连接'}` : `失败：${r.error ?? ''}`
  }
</script>

<div class="providers">
  <h3>模型 Provider</h3>
  {#if chat.providers.length === 0}
    <p class="muted">还没有 provider — 从下方模板添加一个。</p>
  {/if}
  <ul>
    {#each chat.providers as p (p.id)}
      <li>
        <span>{p.name}（{p.type}）{p.has_key ? '🔑' : ''}</span>
        <button onclick={() => test(p.id)}>测试</button>
      </li>
    {/each}
  </ul>
  {#if testResult}<p class="test">{testResult}</p>{/if}

  <h4>从模板添加</h4>
  <div class="templates">
    {#each chat.templates as t (t.type)}
      <button class:sel={selected?.type === t.type} onclick={() => pick(t)}>{t.name}</button>
    {/each}
  </div>

  {#if selected}
    <form onsubmit={(e) => { e.preventDefault(); void add() }}>
      <input bind:value={name} placeholder="名称" aria-label="名称" />
      <input bind:value={baseUrl} placeholder="base_url" aria-label="base_url" />
      {#if selected.needs_key}
        <input bind:value={apiKey} type="password" placeholder="API key" aria-label="API key" />
      {/if}
      <button type="submit">添加</button>
    </form>
  {/if}
</div>

<style>
  .providers { padding: 12px; }
  h3, h4 { margin: 8px 0; }
  .muted { color: #aaa; }
  ul { list-style: none; padding: 0; }
  li { display: flex; justify-content: space-between; gap: 8px; padding: 4px 0; }
  .templates { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
  .templates button { border: 1px solid #e5e4e7; background: #fff; border-radius: 8px; padding: 5px 10px; cursor: pointer; }
  .templates button.sel { border-color: #4250ff; color: #4250ff; }
  form { display: flex; flex-direction: column; gap: 6px; max-width: 360px; }
  form input { border: 1px solid #e5e4e7; border-radius: 8px; padding: 7px 9px; }
  .test { color: #2b8a3e; font-size: 0.85rem; }
</style>
