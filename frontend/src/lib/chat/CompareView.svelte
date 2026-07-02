<script lang="ts">
  // 多模型对比面板:选 2-3 组 provider+model,同一 prompt 并行流式,
  // 每条 lane 一个框选视口(活的东西用 frame,ORAGE);盲测隐藏模型名可揭晓。
  import { marked } from 'marked'
  import DOMPurify from 'dompurify'
  import { chat } from './chatStore.svelte'
  import { compare } from './compareStore.svelte'

  interface Pick {
    providerId: number | null
    model: string
  }
  let picks = $state<Pick[]>([
    { providerId: null, model: '' },
    { providerId: null, model: '' },
  ])
  let promptDraft = $state('')
  let blindPick = $state(false)

  const validPairs = $derived(
    picks
      .filter((p) => p.providerId != null && p.model.trim())
      .map((p) => ({
        providerId: p.providerId!,
        providerName: chat.providers.find((x) => x.id === p.providerId)?.name ?? `#${p.providerId}`,
        model: p.model.trim(),
      })),
  )

  function modelsFor(id: number | null): string[] {
    return chat.providers.find((p) => p.id === id)?.models ?? []
  }

  function addPick() {
    if (picks.length < 3) picks = [...picks, { providerId: null, model: '' }]
  }

  function renderMd(src: string): string {
    return DOMPurify.sanitize(marked.parse(src ?? '', { async: false }) as string)
  }

  async function run() {
    await compare.run(validPairs, promptDraft, blindPick)
    // 对比会话是真实持久化的,跑完让侧栏列表跟上
    await chat.loadSessions()
  }
</script>

<div class="cmp">
  <div class="h">多模型对比 / COMPARE</div>

  <div class="setup">
    {#each picks as p, i (i)}
      <div class="pick">
        <select bind:value={p.providerId} aria-label={`对比 provider ${i + 1}`}>
          <option value={null}>provider</option>
          {#each chat.providers as pr (pr.id)}<option value={pr.id}>{pr.name}</option>{/each}
        </select>
        <input bind:value={p.model} list={`cmp-models-${i}`} placeholder="模型 id" aria-label={`对比模型 ${i + 1}`} />
        <datalist id={`cmp-models-${i}`}>
          {#each modelsFor(p.providerId) as m (m)}<option value={m}></option>{/each}
        </datalist>
      </div>
    {/each}
    {#if picks.length < 3}
      <button class="act" onclick={addPick}>+ 加一路</button>
    {/if}
    <label class="blind">
      <input type="checkbox" class="cbx" bind:checked={blindPick} />
      盲测(揭晓前隐藏模型名)
    </label>
  </div>

  <form
    class="composer"
    onsubmit={(e) => {
      e.preventDefault()
      run()
    }}
  >
    <span class="car" aria-hidden="true"></span>
    <input bind:value={promptDraft} placeholder="同一 prompt 发给所有模型…" aria-label="对比 prompt" disabled={compare.running} />
    {#if compare.running}
      <button type="button" class="act stop" onclick={() => compare.stopAll()}>停止</button>
    {:else}
      <button type="submit" class="act pri" disabled={validPairs.length < 2 || !promptDraft.trim()}>运行</button>
    {/if}
  </form>
  {#if compare.error}<p class="err" role="alert">{compare.error}</p>{/if}

  {#if compare.lanes.length === 0}
    <p class="empty">选两到三个模型,发同一个 prompt 并排看差异。</p>
  {:else}
    {#if compare.blind && !compare.revealed && !compare.running}
      <button class="act pri reveal" onclick={() => compare.reveal()}>揭晓模型</button>
    {/if}
    <div class="lanes" style={`--n:${compare.lanes.length}`}>
      {#each compare.lanes as l (l.key)}
        <section class="lane" aria-label={compare.label(l)}>
          <header class="lh">
            <span class="ln">{compare.label(l)}</span>
            {#if l.streaming}<span class="ls">STREAMING</span>{/if}
          </header>
          <div class="lc">
            {#if l.error}
              <p class="lerr">{l.error}</p>
            {:else if !l.content && !l.streaming}
              <p class="lerr dim">无输出</p>
            {:else}
              <div class="md">{@html renderMd(l.content)}</div>
              {#if l.streaming}<span class="car sm" aria-hidden="true"></span>{/if}
            {/if}
          </div>
        </section>
      {/each}
    </div>
  {/if}
</div>

<style>
  .cmp {
    padding: 14px 18px;
    overflow: auto;
    height: 100%;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    gap: 10px;
    font-family: var(--sans);
    color: var(--t2);
  }
  .h {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .setup {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 14px;
  }
  .pick {
    display: flex;
    gap: 8px;
  }
  .pick select,
  .pick input {
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    font-family: var(--mono);
    font-size: 11px;
    padding: 3px 0 5px;
    width: 110px;
  }
  .pick select option {
    background: var(--panel);
    color: var(--t1);
  }
  .pick select:focus,
  .pick input:focus {
    outline: none;
    border-bottom-color: var(--acc-ink);
  }
  .pick input::placeholder {
    color: var(--t4);
  }
  .blind {
    display: flex;
    align-items: center;
    gap: 7px;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t3);
    cursor: pointer;
  }
  .cbx {
    appearance: none;
    width: 13px;
    height: 13px;
    border: 1.4px solid var(--t4);
    background: transparent;
    cursor: pointer;
    margin: 0;
  }
  .cbx:checked {
    border-color: var(--acc-ink);
    background: var(--acc);
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
  .reveal {
    align-self: flex-start;
  }
  .composer {
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
  .car.sm {
    height: 12px;
    display: inline-block;
    vertical-align: -1px;
    margin-left: 2px;
  }
  @keyframes blink {
    50% { opacity: 0; }
  }
  .composer input {
    flex: 1;
    background: transparent;
    border: 0;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
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
  /* lanes:框选视口网格(活的输出用 frame + accent L 角) */
  .lanes {
    display: grid;
    grid-template-columns: repeat(var(--n), minmax(0, 1fr));
    gap: 14px;
    flex: 1;
    min-height: 0;
  }
  .lane {
    position: relative;
    border: 1px solid var(--line);
    display: flex;
    flex-direction: column;
    min-height: 180px;
  }
  .lane::before,
  .lane::after {
    content: '';
    position: absolute;
    width: 9px;
    height: 9px;
    border: 1.4px solid var(--acc-ink);
  }
  .lane::before {
    top: -1px;
    left: -1px;
    border-right: none;
    border-bottom: none;
  }
  .lane::after {
    bottom: -1px;
    right: -1px;
    border-left: none;
    border-top: none;
  }
  .lh {
    display: flex;
    align-items: baseline;
    gap: 8px;
    padding: 7px 10px;
    border-bottom: 1px solid var(--hair);
  }
  .ln {
    font-family: var(--mono);
    font-size: 10px;
    font-weight: 700;
    letter-spacing: .5px;
    color: var(--t1);
  }
  .lh .ls {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--acc-ink);
  }
  .lc {
    padding: 9px 10px;
    overflow: auto;
    font-size: 12.5px;
    line-height: 1.55;
    flex: 1;
  }
  .lerr {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--red);
    margin: 0;
  }
  .lerr.dim {
    color: var(--t4);
  }
  .md {
    display: inline;
    word-break: break-word;
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
    padding: 6px 8px;
    overflow: auto;
    font-size: 11.5px;
  }
  .md :global(code) {
    font-family: var(--mono);
    font-size: 11.5px;
    color: var(--t1);
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
