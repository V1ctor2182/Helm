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

describe('cockpit fs ops(新建/重命名/废纸篓)', () => {
  it('mkdir/newFile/renameEntry/trash post the right bodies and refresh', async () => {
    const calls: { url: string; body?: unknown }[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string, init?: RequestInit) => {
        calls.push({ url, body: init?.body ? JSON.parse(init.body as string) : undefined })
        const isFs = url.includes('/fs/')
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve(
              isFs
                ? { path: '/proj/new.md' }
                : { path: '/proj', entries: [{ name: 'new.md', path: '/proj/new.md', is_dir: false, size: 0, ext: 'md' }] },
            ),
        })
      }),
    )
    const c = new CockpitStore()
    c.cwd = '/proj'
    expect(await c.mkdir('sub')).toBe(true)
    expect(calls.find((x) => x.url === '/api/cockpit/fs/mkdir')?.body).toEqual({ dir: '/proj', name: 'sub' })

    expect(await c.newFile('new.md')).toBe(true)
    // 新建即编辑:创建后选中该文件
    expect(c.selected?.path).toBe('/proj/new.md')

    await c.renameEntry('/proj/new.md', 'renamed.md')
    expect(calls.find((x) => x.url === '/api/cockpit/fs/rename')?.body).toEqual({ path: '/proj/new.md', name: 'renamed.md' })

    await c.trash('/proj/renamed.md')
    expect(calls.find((x) => x.url === '/api/cockpit/fs/trash')?.body).toEqual({ path: '/proj/renamed.md' })
  })

  it('server detail surfaces to error on failure', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: false, status: 409, json: () => Promise.resolve({ detail: '已存在同名项' }) }),
    )
    const c = new CockpitStore()
    c.cwd = '/proj'
    expect(await c.mkdir('dup')).toBe(false)
    expect(c.error).toBe('已存在同名项')
  })
})

describe('cockpit 双击语义 + 灯箱', () => {
  it('openWithSystem posts the path', async () => {
    const calls: { url: string; body?: unknown }[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string, init?: RequestInit) => {
        calls.push({ url, body: init?.body ? JSON.parse(init.body as string) : undefined })
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ opened: '/p/doc.pdf' }) })
      }),
    )
    const c = new CockpitStore()
    await c.openWithSystem('/p/doc.pdf')
    expect(calls[0]).toEqual({ url: '/api/cockpit/fs/open', body: { path: '/p/doc.pdf' } })
  })
})

describe('cockpit 改·N 热度 + 收件箱', () => {
  it('applyChange 聚合到 cwd 顶层项并进收件箱;噪声全程被拦', () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }))
    const c = new CockpitStore()
    c.cwd = '/proj'
    c.applyChange({ path: '/proj/src/a.ts', kind: 'modified' })
    c.applyChange({ path: '/proj/src/b.ts', kind: 'modified' })
    c.applyChange({ path: '/proj/node_modules/x.js', kind: 'modified' }) // 噪声
    expect(c.changeHeat['/proj/src']?.count).toBe(2)
    expect(c.changeHeat['/proj/src'].files).toEqual(['src/a.ts', 'src/b.ts'])
    expect(c.changeHeat['/proj/node_modules']).toBeUndefined()
    expect(c.inbox).toHaveLength(2)
    expect(c.inbox[0].name).toBe('b.ts') // 最新置顶
    // 同文件再改:去重计数+置顶
    c.applyChange({ path: '/proj/src/a.ts', kind: 'modified' })
    expect(c.inbox[0]).toMatchObject({ name: 'a.ts', count: 2 })
    expect(c.inbox).toHaveLength(2)
    c.clearInbox()
    expect(c.inbox).toHaveLength(0)
  })
})

