// Global keyboard map (F8 §7). Pure function so it's unit-testable without a
// window. Returns true if the shortcut was handled (caller preventDefaults).
//
//   ⌘K command palette · ⌘N quick capture · ⌘\ context panel · ⌘` terminal
//   ⌘1..8 switch mode by Rail order
// ⌘P (project switch) is deferred until projects exist (cockpit Room).

import { MODES, type LayoutStore } from './layout.svelte'

export function applyShortcut(
  e: Pick<KeyboardEvent, 'metaKey' | 'ctrlKey' | 'key'> & { altKey?: boolean },
  layout: LayoutStore,
): boolean {
  // Require ⌘/Ctrl but NOT Alt — AltGr reports ctrlKey on some EU layouts, and
  // we must not hijack AltGr chars (\, `, @, …).
  if (!(e.metaKey || e.ctrlKey) || e.altKey) return false

  switch (e.key.toLowerCase()) {
    case 'k':
      layout.togglePalette()
      return true
    case 'n':
      layout.openCapture()
      return true
    case '\\':
      layout.toggleContext()
      return true
    case '`':
      layout.toggleTerminal()
      return true
  }

  if (e.key >= '1' && e.key <= '9') {
    const idx = Number(e.key) - 1
    if (idx < MODES.length) {
      layout.setMode(MODES[idx].id)
      return true
    }
  }

  return false
}
