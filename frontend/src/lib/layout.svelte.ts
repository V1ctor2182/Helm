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
  contextCollapsed = $state(false)
  terminalCollapsed = $state(true) // terminal hidden until a cockpit/agent needs it
  tabs = $state<Tab[]>([])
  activeTabId = $state<string | null>(null)
  paletteOpen = $state(false)
  captureOpen = $state(false)

  #seq = 0

  // Immersive = both side panels collapsed (full-screen central work).
  get immersive(): boolean {
    return this.contextCollapsed && this.terminalCollapsed
  }

  get activeTab(): Tab | null {
    return this.tabs.find((t) => t.id === this.activeTabId) ?? null
  }

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
  }

  toggleTerminal(): void {
    this.terminalCollapsed = !this.terminalCollapsed
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
