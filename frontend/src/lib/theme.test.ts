import { describe, it, expect, vi } from 'vitest'
import { dayIndex, dailyAccent, darken, PALETTE, theme } from './theme.svelte'

describe('theme · daily accent', () => {
  it('dayIndex 当天稳定，午夜 +1', () => {
    const d0 = dayIndex(0)
    expect(dayIndex(1000)).toBe(d0)
    expect(dayIndex(86_400_000)).toBe(d0 + 1)
  })

  it('dailyAccent 从 palette 确定性取色，按天 mod 10 环绕', () => {
    expect(PALETTE).toContain(dailyAccent(0))
    expect(dailyAccent(2)).toBe(PALETTE[2])
    expect(dailyAccent(12)).toBe(PALETTE[2])
    expect(dailyAccent(-1)).toBe(PALETTE[9])
  })

  it('darken 产出更暗的合法 hex（浅主题 ink）', () => {
    const out = darken('#FFC53D')
    expect(out).toMatch(/^#[0-9a-f]{6}$/i)
    expect(out).not.toBe('#FFC53D')
    // 每个通道都不比原色亮
    const chan = (h: string, i: number) => parseInt(h.slice(1 + i * 2, 3 + i * 2), 16)
    for (let i = 0; i < 3; i++) expect(chan(out, i)).toBeLessThanOrEqual(chan('#FFC53D', i))
  })
})

describe('theme persistence', () => {
  it('setMode persists and init restores', () => {
    // jsdom 的 localStorage 不完整:stub 一个内存实现
    const store = new Map<string, string>()
    vi.stubGlobal('localStorage', {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    })
    try {
      const t = new (theme.constructor as new () => typeof theme)()
      t.setMode('dark')
      expect(store.get('helm-theme-mode')).toBe('dark')
      const t2 = new (theme.constructor as new () => typeof theme)()
      t2.init()
      expect(t2.mode).toBe('dark')
    } finally {
      vi.unstubAllGlobals()
    }
  })
})
