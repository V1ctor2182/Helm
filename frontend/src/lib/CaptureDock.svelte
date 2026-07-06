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
    <div class="answer"><span class="spark" aria-hidden="true"></span><span class="alab">大脑</span>{askAnswer === '' ? '（空回答）' : askAnswer}</div>
  {/if}
</div>

<style>
  /* NOMI 皮(阶段 4 R04):白卡+胶囊+渐变发送;逻辑层未动。 */
  .dock {
    background: var(--card);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    padding: 12px 14px;
    margin-bottom: 14px;
  }

  .chips { display: flex; align-items: center; gap: 5px; flex-wrap: wrap; }
  .chip {
    font: 500 11.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    cursor: pointer;
    transition: background var(--dur-micro) var(--ease), color var(--dur-micro) var(--ease);
  }
  .chip:hover { color: var(--t1); }
  .chip.on { background: var(--t1); color: var(--onink); font-weight: 600; }
  .chip.sub { font-size: 11px; padding: 5px 11px; background: transparent; border: 1px solid var(--hair); }
  .chip.sub.on {
    border-color: transparent;
    background: var(--grad);
    color: #fff;
  }
  .tsep { width: 1px; height: 14px; background: var(--hair); margin: 0 3px; }

  .row {
    display: flex;
    gap: 8px;
    margin-top: 10px;
    background: var(--pill);
    border-radius: var(--radius-pill);
    padding: 4px 4px 4px 15px;
    align-items: center;
  }
  .cin {
    flex: 1;
    background: transparent;
    border: none;
    color: var(--t1);
    caret-color: var(--g2);
    font-family: var(--sans);
    font-size: 13.5px;
    padding: 7px 0;
    outline: none;
  }
  .cin::placeholder { color: var(--t4); }

  .send {
    font: 600 12px/1 var(--sans);
    color: #fff;
    background: var(--grad);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 9px 18px;
    cursor: pointer;
    white-space: nowrap;
  }
  .send:disabled { background: var(--pill); color: var(--t4); cursor: default; }

  .hintrow {
    margin-top: 7px;
    font: 400 10.5px/1 var(--sans);
    color: var(--t4);
    padding-left: 4px;
  }

  .focusrun { display: flex; align-items: center; gap: 12px; margin-top: 10px; }
  .ft {
    font-family: var(--mono);
    font-size: 26px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    color: var(--t1);
  }
  .fw { font-size: 12px; color: var(--t3); }
  .send.stop { margin-left: auto; }

  .answer {
    margin-top: 10px;
    padding: 11px 13px;
    background: var(--card);
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow);
    font-size: 12.5px;
    color: var(--t2);
    white-space: pre-wrap;
    display: flex;
    align-items: baseline;
    gap: 7px;
  }
  .spark {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    flex: none;
    align-self: center;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }
  .alab {
    font: 600 10px/1 var(--sans);
    color: var(--t3);
    margin-right: 4px;
  }
</style>
