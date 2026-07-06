// Shell layout state (Svelte 5 runes). Owns the active mode, panel collapse,
// and the central workspace tabs. Tabs live here — independent of mode — so
// switching modes never closes open tabs (constraint: 切换模式不丢失 Tab).

export type ModeId =
  | 'today'
  | 'chat'
  | 'research'
  | 'memory'
  | 'journal'
  | 'cockpit'
  | 'settings'
// NOTE: 'mail' mode removed for now — email capability disabled (calendar moved
// into the Journal mode). Re-add the mode + Shell branch + MODES entry to restore.

export interface Mode {
  id: ModeId
  label: string
  icon: string
}

// The Rail's modes. Feature rooms light these up; m2 ships them as placeholders.
export const MODES: Mode[] = [
  { id: 'today', label: 'Today', icon: '🏠' },
  { id: 'chat', label: 'Chat', icon: '💬' },
  { id: 'research', label: 'Research', icon: '🔍' },
  { id: 'memory', label: 'Memory', icon: '🧠' },
  { id: 'journal', label: 'Journal', icon: '📓' },
  { id: 'cockpit', label: 'Cockpit', icon: '🛠' },
  { id: 'settings', label: 'Settings', icon: '⚙' },
]

export interface Tab {
  id: string
  title: string
  mode: ModeId
}

export class LayoutStore {
  mode = $state<ModeId>('today')
  // 上下文列默认折叠(2026-07-03 用户:一列只摆几行字太浪费);偏好持久
  contextCollapsed = $state(
    (() => {
      try {
        return localStorage.getItem('helm-ctx-collapsed') !== '0'
      } catch {
        return true
      }
    })(),
  )
  terminalCollapsed = $state(true) // terminal hidden until a cockpit/agent needs it
  tabs = $state<Tab[]>([])
  activeTabId = $state<string | null>(null)
  paletteOpen = $state(false)
  captureOpen = $state(false)
  // ORAGE 监控 chrome 强度：false = 弱（日常默认，仅点阵+少量 fiducial）；
  // true = 强（散落准星 + 坐标 chip 拉满，展示用）。承 DESIGN.md「强度可切，日常默认偏弱」。
  chromeStrong = $state(false)

  #seq = 0

  // Immersive = both side panels collapsed (full-screen central work).
  get immersive(): boolean {
    return this.contextCollapsed && this.terminalCollapsed
  }

  get activeTab(): Tab | null {
    return this.tabs.find((t) => t.id === this.activeTabId) ?? null
  }

  /** 深链意图:切到记录页时直接落某个 tab(ContextPanel「任务」用)。 */
  journalIntent = $state<'notes' | 'journal' | 'tasks' | 'calendar' | null>(null)
  // 记录页分类过滤(阶段 4 R13,稿:分类在全局侧栏;Rail 与 JournalView 共享)
  journalFilter = $state<
    'all' | 'note' | 'journal' | 'task' | 'collect' | 'youtube' | 'paper' | 'inspiration'
  >('all')

  setMode(id: ModeId): void {
    this.mode = id
  }

  openPalette(): void {
    this.paletteOpen = true
  }

  closePalette(): void {
    this.paletteOpen = false
  }

  togglePalette(): void {
    this.paletteOpen = !this.paletteOpen
  }

  openCapture(): void {
    this.captureOpen = true
  }

  closeCapture(): void {
    this.captureOpen = false
  }

  toggleContext(): void {
    this.contextCollapsed = !this.contextCollapsed
    try {
      localStorage.setItem('helm-ctx-collapsed', this.contextCollapsed ? '1' : '0')
    } catch {
      /* 忽略 */
    }
  }

  toggleTerminal(): void {
    this.terminalCollapsed = !this.terminalCollapsed
  }

  toggleChrome(): void {
    this.chromeStrong = !this.chromeStrong
  }

  openTab(title: string, mode: ModeId = this.mode): Tab {
    const tab: Tab = { id: `tab-${++this.#seq}`, title, mode }
    this.tabs.push(tab)
    this.activeTabId = tab.id
    return tab
  }

  closeTab(id: string): void {
    this.tabs = this.tabs.filter((t) => t.id !== id)
    if (this.activeTabId === id) {
      this.activeTabId = this.tabs.at(-1)?.id ?? null
    }
  }

  selectTab(id: string): void {
    if (this.tabs.some((t) => t.id === id)) this.activeTabId = id
  }
}

export const layout = new LayoutStore()
