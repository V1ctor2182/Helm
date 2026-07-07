<script lang="ts">
  // 通用列宽拖柄(R15,用户:所有分割都要可拖)。拖动改一个 CSS 变量(:root),
  // 宽度存 localStorage;使用方用 style 把它摆到分割线上(absolute)。
  import { onMount } from 'svelte'

  let {
    cssVar,
    storageKey,
    min = 160,
    max = 460,
    initial = 250,
    style = '',
  }: {
    cssVar: string
    storageKey: string
    min?: number
    max?: number
    initial?: number
    style?: string
  } = $props()

  let active = $state(false)
  let startX = 0
  let startW = 0

  function currentW(): number {
    const v = parseFloat(getComputedStyle(document.documentElement).getPropertyValue(cssVar))
    return Number.isFinite(v) ? v : initial
  }

  onMount(() => {
    try {
      const saved = localStorage.getItem(storageKey)
      if (saved) document.documentElement.style.setProperty(cssVar, `${saved}px`)
    } catch {
      /* 测试环境/隐私模式无 localStorage */
    }
  })

  function down(e: PointerEvent) {
    startX = e.clientX
    startW = currentW()
    active = true
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
  }
  function move(e: PointerEvent) {
    if (!active) return
    const w = Math.min(max, Math.max(min, startW + (e.clientX - startX)))
    document.documentElement.style.setProperty(cssVar, `${w}px`)
  }
  function up() {
    if (!active) return
    active = false
    try {
      localStorage.setItem(storageKey, String(Math.round(currentW())))
    } catch {
      /* 同上 */
    }
  }
</script>

<div
  class="rz"
  class:active
  {style}
  role="separator"
  aria-orientation="vertical"
  aria-label="拖动调整宽度"
  onpointerdown={down}
  onpointermove={move}
  onpointerup={up}
  onpointercancel={up}
></div>

<style>
  .rz {
    position: absolute;
    top: 0;
    bottom: 0;
    width: 7px;
    cursor: col-resize;
    z-index: 40;
    touch-action: none;
  }
  .rz::after {
    content: '';
    position: absolute;
    top: 0;
    bottom: 0;
    left: 3px;
    width: 1px;
    background: transparent;
    transition: background var(--dur-micro) var(--ease);
  }
  .rz:hover::after,
  .rz.active::after {
    background: color-mix(in srgb, var(--t4) 60%, transparent);
  }
</style>
