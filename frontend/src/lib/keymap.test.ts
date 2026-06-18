import { describe, expect, it } from 'vitest'
import { applyShortcut } from './keymap'
import { LayoutStore } from './layout.svelte'

const mod = (key: string) => ({ metaKey: true, ctrlKey: false, key })

describe('applyShortcut', () => {
  it('ignores keys without the modifier', () => {
    const l = new LayoutStore()
    expect(applyShortcut({ metaKey: false, ctrlKey: false, key: 'k' }, l)).toBe(false)
    expect(l.paletteOpen).toBe(false)
  })

  it('⌘K toggles the palette', () => {
    const l = new LayoutStore()
    expect(applyShortcut(mod('k'), l)).toBe(true)
    expect(l.paletteOpen).toBe(true)
  })

  it('⌘N opens quick capture', () => {
    const l = new LayoutStore()
    expect(applyShortcut(mod('n'), l)).toBe(true)
    expect(l.captureOpen).toBe(true)
  })

  it('⌘\\ toggles context, ⌘` toggles terminal', () => {
    const l = new LayoutStore()
    applyShortcut(mod('\\'), l)
    expect(l.contextCollapsed).toBe(true)
    applyShortcut(mod('`'), l)
    expect(l.terminalCollapsed).toBe(false)
  })

  it('⌘<n> switches mode by Rail order', () => {
    const l = new LayoutStore()
    expect(applyShortcut(mod('2'), l)).toBe(true)
    expect(l.mode).toBe('chat') // MODES[1]
  })

  it('⌘<n> out of range is not handled', () => {
    const l = new LayoutStore()
    expect(applyShortcut(mod('9'), l)).toBe(false) // only 8 modes
  })

  it('ctrl also works (non-mac)', () => {
    const l = new LayoutStore()
    expect(applyShortcut({ metaKey: false, ctrlKey: true, key: 'K' }, l)).toBe(true)
    expect(l.paletteOpen).toBe(true)
  })

  it('does not fire when Alt is held (AltGr layouts)', () => {
    const l = new LayoutStore()
    expect(
      applyShortcut({ metaKey: false, ctrlKey: true, altKey: true, key: '\\' }, l),
    ).toBe(false)
    expect(l.contextCollapsed).toBe(false)
  })
})
