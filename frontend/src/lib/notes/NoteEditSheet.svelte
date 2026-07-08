<script lang="ts">
  // 编辑弹层(2026-07-08 用户拍板):行内 textarea 退场——居中弹层,
  // 所见即所得 contenteditable + 三个格式钮(粗体/斜体/高亮),不让用户
  // 手写 markdown;保存时序列化回 md 兼容标记(见 inlineMd.ts)。
  import type { Note } from './notesStore.svelte'
  import { htmlToMd, mdToHtml } from './inlineMd'
  import { localDateTime } from '../time'

  let {
    note,
    onsave,
    onclose,
  }: {
    note: Note
    onsave: (md: string) => void
    onclose: () => void
  } = $props()

  const KIND_ZH: Record<string, string> = {
    note: '速记', journal: '日记', task: '待办', idea: '想法', focus: '专注',
  }

  let editor = $state<HTMLElement | null>(null)
  let chars = $state(0)

  $effect(() => {
    if (editor && editor.innerHTML === '') {
      editor.innerHTML = mdToHtml(note.content)
      chars = note.content.length
      editor.focus()
    }
  })

  function currentMd(): string {
    return editor ? htmlToMd(editor).trim() : note.content
  }
  function oninput() {
    chars = currentMd().length
  }
  function save() {
    const md = currentMd()
    if (!md) return
    onsave(md)
  }

  // 工具栏:mousedown preventDefault 保住选区;高亮优先 surroundContents,
  // 跨节点选区退回 execCommand 背景色(序列化两种都认)。
  function fmt(cmd: 'bold' | 'italic') {
    document.execCommand?.(cmd)
    editor?.focus()
    oninput()
  }
  function highlight() {
    const sel = window.getSelection()
    if (!sel?.rangeCount || sel.isCollapsed) return
    try {
      const mark = document.createElement('mark')
      sel.getRangeAt(0).surroundContents(mark)
      sel.removeAllRanges()
    } catch {
      document.execCommand?.('hiliteColor', false, '#fff3bf')
    }
    editor?.focus()
    oninput()
  }
  // 粘贴只收纯文本,不带外来样式
  function onpaste(e: ClipboardEvent) {
    e.preventDefault()
    const t = e.clipboardData?.getData('text/plain') ?? ''
    document.execCommand?.('insertText', false, t)
  }
  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.preventDefault()
      onclose()
    } else if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault()
      save()
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="scrim" role="presentation" onclick={onclose}>
  <div class="sheet" role="dialog" aria-label="编辑记录" tabindex="-1" onclick={(e) => e.stopPropagation()}>
    <header class="shd">
      <span class="kbadge">{KIND_ZH[note.kind] ?? note.kind} · 编辑</span>
      <span class="tools" role="toolbar" aria-label="格式">
        <button title="粗体" aria-label="粗体" onmousedown={(e) => e.preventDefault()} onclick={() => fmt('bold')}><b>B</b></button>
        <button title="斜体" aria-label="斜体" onmousedown={(e) => e.preventDefault()} onclick={() => fmt('italic')}><i>I</i></button>
        <button title="高亮" aria-label="高亮" onmousedown={(e) => e.preventDefault()} onclick={highlight}><span class="hl">H</span></button>
      </span>
      <span class="tm">{localDateTime(note.created_at)}</span>
      <button class="x" aria-label="关闭" onclick={onclose}>×</button>
    </header>
    <div
      class="editor"
      contenteditable="true"
      bind:this={editor}
      {oninput}
      {onpaste}
      {onkeydown}
      role="textbox"
      aria-multiline="true"
      aria-label="内容"
      tabindex="0"
    ></div>
    <footer class="foot">
      <span class="cnt">{chars} 字</span>
      <span class="hintk">选中文字点上方按钮 · ⌘⏎ 保存 · Esc 取消</span>
      <button class="ghostb" onclick={onclose}>取消</button>
      <button class="save" onclick={save} disabled={chars === 0}>保存</button>
    </footer>
  </div>
</div>

<style>
  .scrim {
    position: fixed;
    inset: 0;
    background: color-mix(in srgb, var(--t1) 26%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 95;
    padding: 32px;
  }
  .sheet {
    width: min(620px, 100%);
    background: var(--card);
    border-radius: 20px;
    box-shadow: var(--shadow-lg);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
  .shd {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 13px 16px;
    border-bottom: 1px solid var(--hairline, var(--pill));
  }
  .kbadge {
    font: 700 10px/1 var(--sans);
    color: var(--onink);
    background: var(--t1);
    border-radius: var(--radius-pill);
    padding: 4px 10px;
    flex: none;
  }
  .tools {
    display: flex;
    gap: 3px;
  }
  .tools button {
    width: 27px;
    height: 24px;
    border: 0;
    border-radius: 7px;
    background: var(--pill);
    color: var(--t2);
    font: 600 12px/1 var(--sans);
    cursor: pointer;
  }
  .tools button:hover { color: var(--t1); }
  .tools .hl {
    background: #fff3bf;
    color: #7a5b00;
    border-radius: 4px;
    padding: 1px 4px;
  }
  .shd .tm {
    margin-left: auto;
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .x {
    border: 0;
    background: var(--pill);
    width: 24px;
    height: 24px;
    border-radius: 50%;
    color: var(--t3);
    cursor: pointer;
  }
  .editor {
    min-height: 180px;
    max-height: 52vh;
    overflow-y: auto;
    padding: 16px 18px;
    outline: none;
    font: 400 14px/1.75 var(--sans);
    color: var(--t1);
    word-break: break-word;
  }
  .editor :global(mark) {
    background: #fff3bf;
    border-radius: 3px;
    padding: 0 2px;
  }
  .foot {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 11px 16px;
    border-top: 1px solid var(--hairline, var(--pill));
  }
  .cnt {
    font: 500 10.5px/1 var(--mono);
    color: var(--t4);
  }
  .hintk {
    font: 400 11px/1 var(--sans);
    color: var(--t4);
  }
  .ghostb {
    margin-left: auto;
    border: 0;
    border-radius: var(--radius-pill);
    background: var(--pill);
    color: var(--t2);
    font: 500 12px/1 var(--sans);
    padding: 9px 14px;
    cursor: pointer;
  }
  .save {
    border: 0;
    border-radius: var(--radius-pill);
    background: var(--grad);
    color: #fff;
    font: 600 12px/1 var(--sans);
    padding: 9px 18px;
    cursor: pointer;
  }
  .save:disabled { opacity: 0.5; }
</style>
