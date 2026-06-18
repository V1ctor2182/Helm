import { describe, expect, it } from 'vitest'
import { ProjectStore } from './project.svelte'

describe('ProjectStore', () => {
  it('setCurrent updates / clears the current project', () => {
    const p = new ProjectStore()
    p.setCurrent({ path: '/a', name: 'A' })
    expect(p.current?.name).toBe('A')
    p.setCurrent(null)
    expect(p.current).toBeNull()
  })

  it('open sets current and prepends to recent, de-duped by path', () => {
    const p = new ProjectStore()
    p.open({ path: '/a', name: 'A' })
    p.open({ path: '/b', name: 'B' })
    p.open({ path: '/a', name: 'A' }) // re-open moves A to front, no dupe
    expect(p.current?.name).toBe('A')
    expect(p.recent.map((x) => x.path)).toEqual(['/a', '/b'])
  })

  it('setRecent replaces the recent list (cockpit seam)', () => {
    const p = new ProjectStore()
    p.setRecent([{ path: '/x', name: 'X' }])
    expect(p.recent).toHaveLength(1)
  })
})
