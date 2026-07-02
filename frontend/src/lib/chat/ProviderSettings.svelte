<script lang="ts">
  import { onMount } from 'svelte'
  import { chat, type Template } from './chatStore.svelte'

  let selected = $state<Template | null>(null)
  let name = $state('')
  let baseUrl = $state('')
  let apiKey = $state('')
  let testResult = $state('')
  let testOk = $state(true)

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
    testOk = r.ok
    testResult = r.ok ? `OK：${(r.models ?? []).join(', ') || '已连接'}` : `失败：${r.error ?? ''}`
  }
</script>

<div class="providers">
  <div class="h">模型 PROVIDER</div>
  {#if chat.providers.length === 0}
    <p class="empty">还没有 provider — 从下方模板添加一个。</p>
  {:else}
    <ul class="plist">
      {#each chat.providers as p (p.id)}
        <li class="prow">
          <span class="pn">{p.name}</span>
          <span class="pt">{p.type}</span>
          {#if p.has_key}<span class="pk">KEY</span>{/if}
          <button class="act" onclick={() => test(p.id)}>测试</button>
          <button class="act del" aria-label={`删除 ${p.name}`} onclick={() => chat.deleteProvider(p.id)}>×</button>
        </li>
      {/each}
    </ul>
  {/if}
  {#if testResult}<p class="test" class:bad={!testOk}>{testResult}</p>{/if}

  <div class="h ht">从模板添加</div>
  <div class="templates">
    {#each chat.templates as t (t.type)}
      <button class="act" class:sel={selected?.type === t.type} onclick={() => pick(t)}>{t.name}</button>
    {/each}
  </div>

  {#if selected}
    <form onsubmit={(e) => { e.preventDefault(); void add() }}>
      <input bind:value={name} placeholder="名称" aria-label="名称" />
      <input bind:value={baseUrl} placeholder="base_url" aria-label="base_url" />
      {#if selected.needs_key}
        <input bind:value={apiKey} type="password" placeholder="API key(加密存储)" aria-label="API key" />
      {/if}
      <button class="act pri" type="submit">添加</button>
    </form>
  {/if}
</div>

<style>
  .providers {
    padding: 14px 18px;
    overflow: auto;
    font-family: var(--sans);
    color: var(--t2);
    max-width: 560px;
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
    margin-bottom: 7px;
  }
  .h.ht {
    margin-top: 18px;
  }
  .plist {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .prow {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 5px 0;
    border-top: 1px solid var(--hair);
    font-size: 13px;
  }
  .prow:first-child {
    border-top: none;
  }
  .pn {
    color: var(--t1);
    font-weight: 600;
    font-size: 12.5px;
  }
  .pt {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
  }
  .pk {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: var(--acc-ink);
    border: 1px solid var(--acc-ink);
    padding: 0 4px;
  }
  .prow .act:not(.del) {
    margin-left: auto;
  }
  .act.del {
    border: 0;
    padding: 2px 4px;
  }
  .act.del:hover {
    color: var(--red);
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
  .act:hover {
    color: var(--t1);
  }
  .act.sel,
  .act.pri {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .templates {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 10px;
  }
  form {
    display: flex;
    flex-direction: column;
    gap: 10px;
    max-width: 360px;
  }
  form input {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 11px;
    padding: 3px 0 6px;
  }
  form input::placeholder {
    color: var(--t4);
  }
  form input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  form .act.pri {
    align-self: flex-start;
  }
  .test {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--green);
    margin: 6px 0 0;
  }
  .test.bad {
    color: var(--red);
  }
  .empty {
    color: var(--t4);
    font-size: 13px;
  }
</style>
