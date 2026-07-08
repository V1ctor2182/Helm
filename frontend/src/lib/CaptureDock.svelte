<script lang="ts">
  // 捕获坞:notch 速记的 5-kind(速记/日记/任务/专注/问大脑)放进 Today
  // (2026-07-05 用户:dashboard 上这几个放在一起,任务分给自己/交给 agent)。
  // 语义与 notch 一致:给自己→notes(kind:task);交给 agent→POST /api/tasks(prompt);
  // 时间/地点不手选,发送后 Helm 侧 AI 解析(F6 阶段2)。专注:计时,停止记入日记。
  import { notes } from './notes/notesStore.svelte'
  import { focus } from './focus.svelte'

  type Kind = 'note' | 'idea' | 'journal' | 'task' | 'focus' | 'ask'
  const KINDS: { id: Kind; label: string }[] = [
    { id: 'note', label: '速记' },
    { id: 'idea', label: '想法' },
    { id: 'journal', label: '日记' },
    { id: 'task', label: '任务' },
    { id: 'ask', label: '问大脑' },
  ]

  let kind = $state<Kind>('note')
  let target = $state<'me' | 'agent'>('me')
  // K7 智能判类:输入实时判定(规则版,LLM 兜底记 backlog);用户点过 chip=手动接管
  let autoKind = $state(true)
  const verdict = $derived.by(() => {
    const t = text.trim()
    if (!t) return null
    if (/https?:\/\//.test(t)) return { k: 'note' as Kind, why: /arxiv/.test(t) ? '收藏 · 论文' : /youtu/.test(t) ? '收藏 · 视频' : '收藏 · 链接' }
    if (/明早|明晚|今晚|明天|后天|下周|点前|每天|每周|每月|提醒|记得|别忘|之前完成|deadline|截止/.test(t))
      return { k: 'task' as Kind, why: '任务 · 读到时间词' }
    if (/也许|或许|说不定|要不要|想到|点子|灵感|可以试试/.test(t))
      return { k: 'idea' as Kind, why: '想法 · 点子' }
    if (t.length > 14 && /今天|终于|感觉|开心|难受|累|复盘|想了想|反思/.test(t))
      return { k: 'journal' as Kind, why: '日记 · 叙事' }
    if (/^(为什么|怎么|如何|什么是|哪个|谁|吗\?|吗？)/.test(t) || /[?？]$/.test(t))
      return { k: 'ask' as Kind, why: '问大脑 · 疑问句' }
    return { k: 'note' as Kind, why: '速记' }
  })
  $effect(() => {
    if (autoKind && verdict) kind = verdict.k
  })
  const CYCLE: Kind[] = ['note', 'idea', 'journal', 'task', 'ask']
  function cycleKind() {
    autoKind = false
    const i = CYCLE.indexOf(kind)
    kind = CYCLE[(i + 1) % CYCLE.length]
    askAnswer = null
  }
  let text = $state('')
  let status = $state<'idle' | 'sending' | 'sent' | 'failed'>('idle')
  let askAnswer = $state<string | null>(null)
  // T3 分诊回执(稿:发送后结构化回执 toast——类型 chip+抽取 chips+改类)
  let receipt = $state<{ id: number; kind: string; when: string | null; where: string | null } | null>(null)
  let receiptTimer: ReturnType<typeof setTimeout> | undefined
  const RECLASS: string[] = ['note', 'idea', 'journal', 'task']
  const kindLabel = (k: string) => (KINDS.find((x) => x.id === k)?.label ?? k)
  function showReceipt(r: { id: number; kind: string; when: string | null; where: string | null }) {
    receipt = r
    clearTimeout(receiptTimer)
    receiptTimer = setTimeout(() => (receipt = null), 8000)
  }
  async function reclassReceipt() {
    if (!receipt) return
    const next = RECLASS[(RECLASS.indexOf(receipt.kind) + 1) % RECLASS.length]
    if (await notes.reclass(receipt.id, next)) showReceipt({ ...receipt, kind: next })
  }

  // 专注计时:K8 起走全局 store(速记墙顶活卡/待办发起共用)

  const placeholder = $derived(
    kind === 'note' ? '随手记一笔…'
    : kind === 'idea' ? '记下这个点子…'
    : kind === 'journal' ? '写两行今天…'
    : kind === 'task' ? (target === 'me' ? '要做什么…' : '到点让 agent 做什么,时间用人话说…')
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
      const dockable = kind === 'note' || kind === 'idea' || kind === 'journal' || (kind === 'task' && target === 'me')
      if (autoKind && dockable) {
        // T3 自动挡:后端分诊为准(规则+LLM 兜底)→ 结构化回执 toast
        const out = await notes.createTriage(t)
        ok = out !== null
        if (out) showReceipt({ id: out.id, kind: out.kind, when: out.triage?.when ?? out.meta?.when ?? null, where: out.triage?.where ?? out.meta?.where ?? null })
      } else if (kind === 'note') ok = await notes.create(t, 'note')
      else if (kind === 'idea') ok = await notes.create(t, 'idea')
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
        autoKind = true
        setTimeout(() => (status = 'idle'), 1200)
      }
    } catch {
      status = 'failed'
    }
  }

  function startFocus() {
    focus.start(text)
    text = ''
  }
  async function stopFocus() {
    await focus.stop()
    status = 'sent'
    setTimeout(() => (status = 'idle'), 1200)
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      void submit()
    }
  }
</script>

<!-- 去重定稿(2026-07-08 用户确认):kind chips 行撤掉——AI 判定徽章分流(点=轮换改判),
     任务时双轨浮现,专注收成 ⏱ 图标,问大脑由疑问句判定。 -->
<div class="dock" role="group" aria-label="捕获">

  {#if focus.running}
    <div class="focusrun">
      <span class="ft" aria-live="polite">{focus.mmss}</span>
      {#if focus.what}<span class="fw">{focus.what}</span>{/if}
      <button class="send stop" onclick={() => void stopFocus()}>停止并记录</button>
    </div>
  {:else}
    <div class="row">
      <input
        class="cin"
        bind:value={text}
        placeholder="随手丢进来 — AI 自动分流:速记 / 日记 / 任务 / 收藏 / 问大脑…"
        {onkeydown}
        aria-label="捕获内容"
      />
      {#if verdict && autoKind}
        <button class="verdict" title="AI 判定,点击轮换改判" onclick={cycleKind}>
          <span class="vspark" aria-hidden="true"></span>AI · {verdict.why}<span class="vc">▾</span>
        </button>
      {:else if !autoKind && text.trim()}
        <button class="verdict manual" title="点回 AI 自动判定" onclick={() => (autoKind = true)}>手动 · {KINDS.find((k) => k.id === kind)?.label}<span class="vc">▾</span></button>
      {/if}
      {#if kind === 'task' && text.trim()}
        <span class="whomini">
          <button class="wm" class:on={target === 'me'} onclick={() => (target = 'me')}>给自己</button>
          <button class="wm" class:on={target === 'agent'} onclick={() => (target = 'agent')}>交给 agent</button>
        </span>
      {/if}
      <button class="fbtn" title="用这句话开始专注" aria-label="开始专注" onclick={startFocus}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="13" r="7.2"/><path d="M12 9.5V13l2.4 1.6M10 2.5h4M12 2.5v3"/></svg>
      </button>
      <button class="send" disabled={text.trim() === '' || status === 'sending'} onclick={() => void submit()}>
        {status === 'sending' ? '发送中' : status === 'sent' ? '已记 ✓' : status === 'failed' ? '重试' : '发送'}
      </button>
    </div>
    <div class="hintrow">{hint}</div>
  {/if}

  {#if askAnswer !== null}
    <div class="answer"><span class="spark" aria-hidden="true"></span><span class="alab">大脑</span>{askAnswer === '' ? '（空回答）' : askAnswer}</div>
  {/if}

  {#if receipt}
    <!-- T3 分诊回执(稿):类型 chip + 抽取 chips + 改类(纠正回流 PATCH kind) -->
    <div class="receipt" role="status">
      <span class="ntag" class:idea={receipt.kind === 'idea'} class:task={receipt.kind === 'task'}>{kindLabel(receipt.kind)}</span>
      <span class="rtxt">已结构化入库</span>
      {#if receipt.when}<span class="ntag xc">{receipt.when}</span>{/if}
      {#if receipt.where}<span class="ntag xc">@{receipt.where}</span>{/if}
      {#if receipt.kind === 'task'}<span class="ntag xc">→ 已入待办</span>{/if}
      <button class="rfix" title="判错了?点击改类" onclick={() => void reclassReceipt()}>改</button>
    </div>
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

  /* T3 分诊回执 toast(稿 .ntag 族) */
  .receipt {
    display: flex;
    align-items: center;
    gap: 7px;
    margin-top: 10px;
    flex-wrap: wrap;
  }
  .ntag {
    display: inline-block;
    font-size: 9.5px;
    font-weight: 700;
    border-radius: 999px;
    padding: 3px 9px;
    color: var(--onink); /* 深浅双模式:与 --t1 底反色 */
    background: var(--t1);
  }
  .ntag.idea,
  .ntag.task { color: #fff; }
  .ntag.idea { background: #0a84ff; }
  .ntag.task { background: linear-gradient(90deg, var(--g1), var(--g2)); }
  .ntag.xc {
    color: var(--t2);
    background: var(--pill);
    font-weight: 600;
    font-family: var(--mono);
  }
  .rtxt { font: 400 11.5px/1 var(--sans); color: var(--t3); }
  .rfix {
    font: 600 10.5px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: 999px;
    padding: 4px 10px;
    cursor: pointer;
  }
  .rfix:hover { color: var(--t1); }

  .verdict {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font: 600 11px/1 var(--sans);
    color: var(--t3);
    background: var(--pill);
    border: 0;
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    cursor: pointer;
    flex: none;
    animation: vpop 0.18s var(--ease);
  }
  .vc {
    font-size: 8px;
    color: var(--t4);
    margin-left: 2px;
  }
  .whomini {
    display: inline-flex;
    gap: 4px;
    animation: vpop 0.18s var(--ease);
  }
  .wm {
    font: 500 11px/1 var(--sans);
    color: var(--t3);
    background: var(--card);
    border: 1px solid var(--hair);
    border-radius: var(--radius-pill);
    padding: 6px 12px;
    cursor: pointer;
    white-space: nowrap;
  }
  .wm.on {
    border-color: transparent;
    background: var(--grad);
    color: #fff;
    font-weight: 600;
  }
  .fbtn {
    width: 34px;
    height: 34px;
    border-radius: 50%;
    border: 0;
    background: var(--card);
    color: var(--t3);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
  }
  .fbtn :global(svg) {
    width: 16px;
    height: 16px;
  }
  .fbtn:hover {
    color: var(--t1);
  }
  .verdict.manual {
    color: var(--t4);
    background: transparent;
    border: 1px dashed var(--hair);
  }
  @keyframes vpop {
    from { transform: scale(0.86); opacity: 0; }
  }
  .vspark {
    width: 11px;
    height: 11px;
    border-radius: 50%;
    background: conic-gradient(from 210deg, var(--g1), var(--g2), var(--g1));
  }

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
