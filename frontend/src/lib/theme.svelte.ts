// 主题 + 每日 accent 系统（Svelte 5 runes）。
// 真相源：docs/design/helm-pro.html + DESIGN.md。
// - mode: 'system'（默认，跟随 prefers-color-scheme）| 'dark' | 'light'
// - 每日 accent：palette[dayIndex % 10]，当天稳定、午夜轮换；浅主题把 ink 压暗。
// 应用到 <html>：data-theme 属性 + 内联 --acc / --acc-ink，让 app.css 的 token 响应。

export type ThemeMode = 'system' | 'dark' | 'light'

// notch 每日调色板（承 helm-notch-pro.html / DESIGN.md）
export const PALETTE = [
  '#FB9E66', '#FF6F61', '#FFC53D', '#B6E84F', '#34D6C0',
  '#4FD6E8', '#5EA0FF', '#7C9CFF', '#B98CFF', '#FF6FA5',
] as const

const DAY_MS = 86_400_000

/** 确定性日序（自 epoch 的天数）——当天稳定，午夜 +1。 */
export function dayIndex(now: number = Date.now()): number {
  return Math.floor(now / DAY_MS)
}

/** 当天的 accent——当天稳定，午夜轮换。 */
export function dailyAccent(idx: number = dayIndex()): string {
  const n = PALETTE.length
  return PALETTE[((idx % n) + n) % n]
}

/** 把 accent 压暗，供浅（纸）主题上文字/线可读。
 *  复刻 helm-pro.html 的 darken(): r*.5 g*.5 b*.42（纸底对比安全）。 */
export function darken(hex: string): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim())
  if (!m) return hex
  const int = parseInt(m[1], 16)
  const r = Math.round(((int >> 16) & 255) * 0.5)
  const g = Math.round(((int >> 8) & 255) * 0.5)
  const b = Math.round((int & 255) * 0.42)
  return '#' + [r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('')
}

function prefersDark(): boolean {
  if (typeof window === 'undefined' || !window.matchMedia) return true
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}

class ThemeStore {
  mode = $state<ThemeMode>('system')
  accent = $state<string>(dailyAccent())

  /** 有效是否暗色（'system' 解析到系统设置）。 */
  get isDark(): boolean {
    return this.mode === 'dark' || (this.mode === 'system' && prefersDark())
  }

  setMode(m: ThemeMode) {
    this.mode = m
    this.apply()
  }

  /** 手动设 accent（如「换今日色」），传 palette hex。 */
  setAccent(hex: string) {
    this.accent = hex
    this.apply()
  }

  /** 轮到下一个 palette 色（供换色按钮）。 */
  cycleAccent() {
    const i = (PALETTE as readonly string[]).indexOf(this.accent)
    this.setAccent(PALETTE[(i + 1) % PALETTE.length])
  }

  /** 把 mode + accent 推进 DOM，让 app.css 的 token 响应。 */
  apply() {
    if (typeof document === 'undefined') return
    const root = document.documentElement
    if (this.mode === 'system') root.removeAttribute('data-theme')
    else root.setAttribute('data-theme', this.mode)
    root.style.setProperty('--acc', this.accent)
    root.style.setProperty('--acc-ink', this.isDark ? this.accent : darken(this.accent))
  }

  /** 启动挂载：立即应用 + 系统主题翻转时刷新（system 模式下）。 */
  init() {
    this.accent = dailyAccent()
    this.apply()
    if (typeof window !== 'undefined' && window.matchMedia) {
      window
        .matchMedia('(prefers-color-scheme: dark)')
        .addEventListener('change', () => {
          if (this.mode === 'system') this.apply()
        })
    }
  }
}

export const theme = new ThemeStore()
