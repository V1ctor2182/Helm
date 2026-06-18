import { describe, expect, it } from 'vitest'
import { LayoutStore } from './layout.svelte'

describe('LayoutStore', () => {
  it('defaults: today mode, context open, terminal collapsed', () => {
    const l = new LayoutStore()
    expect(l.mode).toBe('today')
    expect(l.contextCollapsed).toBe(false)
    expect(l.terminalCollapsed).toBe(true)
    expect(l.tabs).toEqual([])
  })

  it('setMode changes the active mode', () => {
    const l = new LayoutStore()
    l.setMode('research')
    expect(l.mode).toBe('research')
  })

  it('switching mode preserves open tabs (constraint d55f8ece)', () => {
    const l = new LayoutStore()
    l.openTab('A')
    l.openTab('B')
    expect(l.tabs.length).toBe(2)
    l.setMode('chat')
    expect(l.mode).toBe('chat')
    expect(l.tabs.length).toBe(2)
  })

  it('openTab activates the new tab; closeTab falls back to the previous', () => {
    const l = new LayoutStore()
    const a = l.openTab('A')
    const b = l.openTab('B')
    expect(l.activeTabId).toBe(b.id)
    l.closeTab(b.id)
    expect(l.activeTabId).toBe(a.id)
    l.closeTab(a.id)
    expect(l.activeTabId).toBe(null)
  })

  it('immersive when both side panels are collapsed', () => {
    const l = new LayoutStore()
    expect(l.immersive).toBe(false) // context open
    l.toggleContext()
    expect(l.immersive).toBe(true) // both collapsed
    l.toggleTerminal()
    expect(l.immersive).toBe(false) // terminal now open
  })
})
