import { afterEach, describe, expect, it, vi } from 'vitest'
import { CockpitStore } from './cockpit.svelte'
import { commands } from '../commands.svelte'
import { layout } from '../layout.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  layout.setMode('today')
})

const ok = (body: unknown) => ({ ok: true, json: () => Promise.resolve(body) })

describe('CockpitStore', () => {
  it('browse loads cwd + entries and clears error', async () => {
    const c = new CockpitStore()
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        ok({
          path: '/p',
          entries: [{ name: 'a', path: '/p/a', is_dir: false, size: 1, ext: 'md' }],
        }),
      ),
    )
    await c.browse('/p')
    expect(c.cwd).toBe('/p')
    expect(c.entries).toHaveLength(1)
    expect(c.error).toBeNull()
  })

  it('browse sets an error on non-ok response', async () => {
    const c = new CockpitStore()
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false }))
    await c.browse('/bad')
    expect(c.error).not.toBeNull()
  })

  it('loadProjects registers each project into the ⌘K palette', async () => {
    const c = new CockpitStore()
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        ok({
          projects: [
            { path: '/proj/foo', name: 'foo', badges: ['py'], last_opened: null },
          ],
        }),
      ),
    )
    await c.loadProjects()
    expect(c.projects).toHaveLength(1)
    expect(
      commands.search('foo').some((cmd) => cmd.id === 'cockpit.project./proj/foo'),
    ).toBe(true)
  })

  it('applyChange flashes the path; follow mode also previews it', () => {
    const c = new CockpitStore()
    c.cwd = '/p'
    c.applyChange({ path: '/p/a.md', kind: 'modified' })
    expect(c.changedPaths.has('/p/a.md')).toBe(true)
    expect(c.selected).toBeNull() // follow off → no preview

    c.followMode = true
    c.applyChange({ path: '/p/b.ts', kind: 'modified' })
    expect(c.selected?.path).toBe('/p/b.ts')
    expect(c.selected?.ext).toBe('ts')
  })

  it('markChanged clears the flash after the timeout', () => {
    vi.useFakeTimers()
    const c = new CockpitStore()
    c.markChanged('/p/x')
    expect(c.changedPaths.has('/p/x')).toBe(true)
    vi.advanceTimersByTime(1600)
    expect(c.changedPaths.has('/p/x')).toBe(false)
    vi.useRealTimers()
  })

  it('toggleFollow flips follow mode', () => {
    const c = new CockpitStore()
    expect(c.followMode).toBe(false)
    c.toggleFollow()
    expect(c.followMode).toBe(true)
  })

  it('select browses into a dir, selects a file', async () => {
    const c = new CockpitStore()
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ path: '/p/d', entries: [] })))
    c.select({ name: 'd', path: '/p/d', is_dir: true, size: 0, ext: '' })
    await vi.waitFor(() => expect(c.cwd).toBe('/p/d'))

    c.select({ name: 'f', path: '/p/f', is_dir: false, size: 1, ext: 'md' })
    expect(c.selected?.name).toBe('f')
  })
})
