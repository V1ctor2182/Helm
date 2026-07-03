<script lang="ts">
  import { capture } from './capture.svelte'
  import { layout } from './layout.svelte'
  import { notes } from './notes/notesStore.svelte'
  import { tasks } from './notes/tasksStore.svelte'

  // ⌘N 三模式(2026-07-03 用户:速记功能全部完善,与 notch 对齐):
  // 速记=note、日记=当天 journal、任务=cron 默认每天 9 点(与 notch 同默认)。
  type Kind = 'note' | 'journal' | 'task'
  const KINDS: { id: Kind; label: string }[] = [
    { id: 'note', label: '速记' },
    { id: 'journal', label: '日记' },
    { id: 'task', label: '任务' },
  ]

  let text = $state('')
  let kind = $state<Kind>('note')
  let inputEl = $state<HTMLTextAreaElement>()

  $effect(() => {
    if (layout.captureOpen) {
      inputEl?.focus()
    } else {
      text = ''
      kind = 'note'
    }
  })

  function todayISO(): string {
    const d = new Date()
    const p = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
  }

  let saveErr = $state('')

  async function save() {
    const t = text.trim()
    if (!t) return
    saveErr = ''
    let ok = false
    if (kind === 'note') ok = await capture.submit(t)
    else if (kind === 'journal') ok = await notes.create(t, 'journal', todayISO())
    else ok = await tasks.create('', t, 'cron', { expr: '0 9 * * *' })
    if (ok) layout.closeCapture()
    else saveErr = (kind === 'task' ? tasks.error : notes.error) ?? '保存失败'
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      layout.closeCapture()
    } else if (e.key === 'Tab') {
      // TAB 循环三模式(与 notch 同手势)
      e.preventDefault()
      const i = KINDS.findIndex((k) => k.id === kind)
      kind = KINDS[(i + 1) % KINDS.length].id
    } else if (e.key === 'Enter' && !e.shiftKey) {
      // Enter saves; Shift+Enter for a newline.
      e.preventDefault()
      void save()
    }
  }

  const hint = $derived(
    kind === 'note'
      ? '归入速记(记录页可转任务/记忆/日记)'
      : kind === 'journal'
        ? '写进今天的日记时间线'
        : '建为定时任务(默认每天 9:00,记录页可改)',
  )
</script>

{#if layout.captureOpen}
  <button class="overlay" aria-label="关闭速记" onclick={() => layout.closeCapture()}></button>
  <div class="capture" role="dialog" aria-modal="true" aria-label="速记">
    <div class="kinds" role="tablist" aria-label="速记模式">
      {#each KINDS as k (k.id)}
        <button
          role="tab"
          aria-selected={kind === k.id}
          class="kchip"
          class:on={kind === k.id}
          onclick={() => (kind = k.id)}>{k.label}</button
        >
      {/each}
      <span class="ktab">TAB 切换</span>
    </div>
    <textarea
      bind:this={inputEl}
      bind:value={text}
      {onkeydown}
      rows="3"
      placeholder={kind === 'task' ? '要定时做什么…  (⏎ 保存)' : '记一条…  (⏎ 保存 · ⇧⏎ 换行 · Esc 关闭)'}
      aria-label="速记内容"
    ></textarea>
    <div class="actions">
      <span class="hint" class:err={!!saveErr}>{saveErr || hint}</span>
      <button class="save" onclick={save} disabled={text.trim() === ''}>保存</button>
    </div>
  </div>
{/if}

<style>
  .kinds {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 10px 12px 0;
  }
  .kchip {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 1px;
    color: var(--t3);
    background: transparent;
    border: 1px solid var(--line);
    padding: 3px 10px;
    cursor: pointer;
  }
  .kchip.on {
    color: var(--acc-ink);
    border-color: var(--acc-ink);
  }
  .hint.err {
    color: var(--red, #d33);
  }
  .ktab {
    margin-left: auto;
    font-family: var(--mono);
    font-size: 9px;
    color: var(--t4);
  }
  .overlay {
    position: fixed;
    inset: 0;
    border: 0;
    padding: 0;
    background: rgba(0, 0, 0, 0.5);
    -webkit-backdrop-filter: blur(6px);
    backdrop-filter: blur(6px);
    cursor: default;
    z-index: 100;
  }
  .capture {
    position: fixed;
    top: 20vh;
    left: 50%;
    transform: translateX(-50%);
    width: min(520px, 92vw);
    background: var(--chrome);
    border: 1px solid var(--line);
    border-radius: 12px;
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.55);
    z-index: 101;
    padding: 12px;
    box-sizing: border-box;
    font-family: var(--sans);
  }
  textarea {
    width: 100%;
    border: 1px solid var(--hair);
    border-radius: 8px;
    background: var(--bg);
    color: var(--t1);
    caret-color: var(--acc);
    padding: 10px;
    font-family: var(--sans);
    font-size: 15px;
    resize: vertical;
    outline: none;
    box-sizing: border-box;
  }
  textarea::placeholder {
    color: var(--t4);
  }
  .actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 8px;
  }
  .hint {
    color: var(--t4);
    font-size: 12px;
    font-family: var(--mono);
  }
  .save {
    border: 0;
    background: var(--acc);
    color: #0b0e0f;
    padding: 7px 14px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 600;
  }
  .save:disabled {
    background: var(--tile);
    color: var(--t4);
    cursor: default;
  }
</style>
