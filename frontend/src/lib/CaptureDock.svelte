<script lang="ts">
  // 捕获坞:notch 速记的 5-kind(速记/日记/任务/专注/问大脑)放进 Today
  // (2026-07-05 用户:dashboard 上这几个放在一起,任务分给自己/交给 agent)。
  // 语义与 notch 一致:给自己→notes(kind:task);交给 agent→POST /api/tasks(prompt);
  // 时间/地点不手选,发送后 Helm 侧 AI 解析(F6 阶段2)。专注:计时,停止记入日记。
  import { notes } from './notes/notesStore.svelte'

  type Kind = 'note' | 'journal' | 'task' | 'focus' | 'ask'
  const KINDS: { id: Kind; label: string }[] = [
    { id: 'note', label: '速记' },
    { id: 'journal', label: '日记' },
    { id: 'task', label: '任务' },
    { id: 'focus', label: '专注' },
    { id: 'ask', label: '问大脑' },
  ]

  let kind = $state<Kind>('note')
  let target = $state<'me' | 'agent'>('me')
  let text = $state('')
  let status = $state<'idle' | 'sending' | 'sent' | 'failed'>('idle')
  let askAnswer = $state<string | null>(null)

  // 专注计时
  let focusStart = $state<number | null>(null)
  let focusWhat = $state('')
  let tick = $state(0)
  $effect(() => {
    if (focusStart === null) return
    const t = setInterval(() => (tick = Date.now()), 1000)
    return () => clearInterval(t)
  })
  const focusSecs = $derived(focusStart ? Math.max(0, Math.floor(((tick || Date.now()) - focusStart) / 1000)) : 0)
  const mmss = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

  const placeholder = $derived(
    kind === 'note' ? '随手记一笔…'
    : kind === 'journal' ? '写两行今天…'
    : kind === 'task' ? (target === 'me' ? '要做什么…' : '到点让 agent 做什么…')
    : kind === 'ask' ? '问 Helm 大脑…'
    : '在做什么…',
  )
  const hint = $derived(
    kind === 'journal' ? '⏎ 发送' : kind === 'ask' ? '⏎ 发送 · 走 Chat 配好的 provider' : '⏎ 发送 · AI 自动整理时间/地点',
  )

  function today(): string {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  async function submit() {
    const t = text.trim()
    if (!t || status === 'sending') return
    status = 'sending'
    askAnswer = null
    try {
      let ok = true
      if (kind === 'note') ok = await notes.create(t, 'note')
      else if (kind === 'journal') ok = await notes.create(t, 'journal', today())
      else if (kind === 'task' && target === 'me') ok = await notes.create(t, 'task')
      else if (kind === 'task') {
        // 交给 agent = 调度任务;契约同 notch(POST /api/tasks {prompt})
        const r = await fetch('/api/tasks', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ prompt: t }),
        })
        ok = r.ok
      } else if (kind === 'ask') {
        const r = await fetch('/api/ask', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ q: t }),
        })
        ok = r.ok
        if (r.ok) askAnswer = ((await r.json()) as { answer?: string }).answer ?? ''
      }
      status = ok ? 'sent' : 'failed'
      if (ok) {
        text = ''
        setTimeout(() => (status = 'idle'), 1200)
      }
    } catch {
      status = 'failed'
    }
  }

  function startFocus() {
    focusWhat = text.trim()
    focusStart = Date.now()
    tick = Date.now()
  }
  async function stopFocus() {
    const mins = Math.max(1, Math.round(focusSecs / 60))
    const what = focusWhat ? `:${focusWhat}` : ''
    focusStart = null
    text = ''
    await notes.create(`专注 ${mins} 分钟${what}`, 'journal', today())
    status = 'sent'
    setTimeout(() => (status = 'idle'), 1200)
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      if (kind === 'focus') {
        if (focusStart === null) startFocus()
      } else void submit()
    }
  }
</script>

<div class="dock" role="group" aria-label="捕获">
  <div class="chips">
    {#each KINDS as k (k.id)}
      <button class="chip" class:on={kind === k.id} onclick={() => { kind = k.id; askAnswer = null }}>{k.label}</button>
    {/each}
    {#if kind === 'task'}
      <span class="tsep" aria-hidden="true"></span>
      <button class="chip sub" class:on={target === 'me'} onclick={() => (target = 'me')}>给自己</button>
      <button class="chip sub" class:on={target === 'agent'} onclick={() => (target = 'agent')}>交给 agent</button>
    {/if}
  </div>

  {#if kind === 'focus' && focusStart !== null}
    <div class="focusrun">
      <span class="ft" aria-live="polite">{mmss(focusSecs)}</span>
      {#if focusWhat}<span class="fw">{focusWhat}</span>{/if}
      <button class="send stop" onclick={() => void stopFocus()}>停止并记录</button>
    </div>
  {:else}
    <div class="row">
      <input
        class="cin"
        bind:value={text}
        {placeholder}
        {onkeydown}
        aria-label="捕获内容"
      />
      {#if kind === 'focus'}
        <button class="send" disabled={status === 'sending'} onclick={startFocus}>开始</button>
      {:else}
        <button class="send" disabled={text.trim() === '' || status === 'sending'} onclick={() => void submit()}>
          {status === 'sending' ? '发送中' : status === 'sent' ? '已记 ✓' : status === 'failed' ? '重试' : '发送'}
        </button>
      {/if}
    </div>
    <div class="hintrow">{hint}</div>
  {/if}

  {#if askAnswer !== null}
    <div class="answer"><span class="alab">大脑</span>{askAnswer === '' ? '（空回答）' : askAnswer}</div>
  {/if}
</div>

<style>
  .dock {
    border: 1px solid var(--line);
    padding: 10px 12px;
    margin-bottom: 14px;
    position: relative;
  }
  /* 框选视口 L 角(捕获=活的输入) */
  .dock::before,
  .dock::after {
    content: '';
    position: absolute;
    width: 9px;
    height: 9px;
    border: 1.4px solid var(--acc-ink);
  }
  .dock::before { top: -1px; left: -1px; border-right: none; border-bottom: none; }
  .dock::after { bottom: -1px; right: -1px; border-left: none; border-top: none; }

  .chips { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
  .chip {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--t3);
    background: transparent;
    border: 1px solid var(--hair);
    padding: 4px 10px;
    cursor: pointer;
    transition: color var(--dur-micro) var(--ease), border-color var(--dur-micro) var(--ease);
  }
  .chip:hover { color: var(--t1); }
  .chip.on { color: var(--acc-ink); border-color: var(--acc-ink); }
  .chip.sub { font-size: 10px; padding: 3px 8px; }
  .tsep { width: 1px; height: 14px; background: var(--hair); margin: 0 2px; }

  .row { display: flex; gap: 8px; margin-top: 9px; }
  .cin {
    flex: 1;
    background: transparent;
    border: none;
    border-bottom: 1px solid var(--hair);
    color: var(--t1);
    caret-color: var(--acc);
    font-family: var(--sans);
    font-size: 13.5px;
    padding: 5px 1px 6px;
    outline: none;
  }
  .cin::placeholder { color: var(--t4); }
  .cin:focus { border-bottom-color: var(--acc-ink); }

  .send {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--acc-ink);
    background: transparent;
    border: 1px solid var(--acc-ink);
    padding: 5px 12px;
    cursor: pointer;
    white-space: nowrap;
  }
  .send:disabled { color: var(--t4); border-color: var(--hair); cursor: default; }

  .hintrow {
    margin-top: 6px;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--t4);
    letter-spacing: 0.3px;
  }

  .focusrun { display: flex; align-items: center; gap: 12px; margin-top: 10px; }
  .ft {
    font-family: var(--mono);
    font-size: 26px;
    font-weight: 800;
    font-variant-numeric: tabular-nums;
    color: var(--t1);
  }
  .fw { font-size: 12px; color: var(--t3); }
  .send.stop { margin-left: auto; }

  .answer {
    margin-top: 9px;
    padding: 8px 10px;
    border-left: 2px solid var(--acc-ink);
    font-size: 12.5px;
    color: var(--t2);
    white-space: pre-wrap;
  }
  .alab {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--acc-ink);
    margin-right: 8px;
    text-transform: uppercase;
  }
</style>
