import { describe, it, expect } from 'vitest'
import { dayIndex, dailyAccent, darken, PALETTE } from './theme.svelte'

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
