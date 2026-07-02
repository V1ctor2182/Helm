<script lang="ts">
  // 图片灯箱(承 FanBox app:759-771):滚轮 0.2-8x 缩放、点空白/Esc 关闭;
  // 原生格式走 raw,heic/tiff 等浏览器不认的走 w=1600 缩略图。
  import { cockpit } from './cockpit.svelte'

  const NATIVE = new Set(['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'ico', 'avif'])

  let scale = $state(1)

  const src = $derived.by(() => {
    const p = cockpit.lightboxPath
    if (!p) return ''
    const ext = (p.split('.').pop() ?? '').toLowerCase()
    return NATIVE.has(ext)
      ? `/api/cockpit/raw?path=${encodeURIComponent(p)}`
      : `/api/cockpit/thumb?path=${encodeURIComponent(p)}&w=1600`
  })

  $effect(() => {
    void cockpit.lightboxPath
    scale = 1 // 换图重置缩放
  })

  function close() {
    cockpit.lightboxPath = null
  }

  function onWheel(e: WheelEvent) {
    e.preventDefault()
    scale = Math.min(8, Math.max(0.2, scale - e.deltaY * 0.002))
  }

  function onKey(e: KeyboardEvent) {
    // Esc 分层:右键菜单/对话框在上层时让位(一次只退一层)
    if (e.key === 'Escape' && cockpit.lightboxPath && !document.querySelector('.ctx, .dlg')) close()
  }
</script>

<svelte:window onkeydown={onKey} />

{#if cockpit.lightboxPath}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div
    class="lb"
    role="dialog"
    tabindex="-1"
    aria-label="图片灯箱"
    onclick={(e) => e.target === e.currentTarget && close()}
    onwheel={onWheel}
  >
    <img class="lbi" style={`transform:scale(${scale})`} {src} alt="" />
    <div class="lbh">点击空白处关闭 · 滚轮缩放 · ESC</div>
  </div>
{/if}

<style>
  .lb {
    position: fixed;
    inset: 0;
    z-index: 80;
    background: rgba(0, 0, 0, .88);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .lbi {
    max-width: 92vw;
    max-height: 92vh;
    transition: transform .08s linear;
    background: var(--tile);
  }
  .lbh {
    position: absolute;
    bottom: 14px;
    left: 50%;
    transform: translateX(-50%);
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: .5px;
    color: rgba(255, 255, 255, .5);
  }
</style>
