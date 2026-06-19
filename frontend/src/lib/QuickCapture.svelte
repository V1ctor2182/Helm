<script lang="ts">
  import { capture } from './capture.svelte'
  import { layout } from './layout.svelte'

  let text = $state('')
  let inputEl = $state<HTMLTextAreaElement>()

  $effect(() => {
    if (layout.captureOpen) {
      inputEl?.focus()
    } else {
      text = ''
    }
  })

  async function save() {
    const ok = await capture.submit(text)
    if (ok) layout.closeCapture()
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      layout.closeCapture()
    } else if (e.key === 'Enter' && !e.shiftKey) {
      // Enter saves; Shift+Enter for a newline.
      e.preventDefault()
      void save()
    }
  }
</script>

{#if layout.captureOpen}
  <button class="overlay" aria-label="关闭速记" onclick={() => layout.closeCapture()}></button>
  <div class="capture" role="dialog" aria-modal="true" aria-label="速记">
    <textarea
      bind:this={inputEl}
      bind:value={text}
      {onkeydown}
      rows="3"
      placeholder="记一条…  (⏎ 保存 · ⇧⏎ 换行 · Esc 关闭)"
      aria-label="速记内容"
    ></textarea>
    <div class="actions">
      <span class="hint">归入速记（可在记录 Room 转任务/记忆/日记）</span>
      <button class="save" onclick={save} disabled={text.trim() === ''}>保存</button>
    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    border: 0;
    padding: 0;
    background: rgba(0, 0, 0, 0.2);
    cursor: default;
    z-index: 100;
  }
  .capture {
    position: fixed;
    top: 20vh;
    left: 50%;
    transform: translateX(-50%);
    width: min(520px, 92vw);
    background: #fff;
    border: 1px solid #e5e4e7;
    border-radius: 12px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.18);
    z-index: 101;
    padding: 12px;
    box-sizing: border-box;
  }
  textarea {
    width: 100%;
    border: 1px solid #eee;
    border-radius: 8px;
    padding: 10px;
    font: inherit;
    font-size: 15px;
    resize: vertical;
    outline: none;
    box-sizing: border-box;
  }
  .actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 8px;
  }
  .hint {
    color: #999;
    font-size: 12px;
  }
  .save {
    border: 0;
    background: #4250ff;
    color: #fff;
    padding: 7px 14px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
  }
  .save:disabled {
    background: #c7c9d9;
    cursor: default;
  }
</style>
