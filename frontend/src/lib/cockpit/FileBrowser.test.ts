import { render, screen } from '@testing-library/svelte'
import { afterEach, describe, expect, it, vi } from 'vitest'
import FileBrowser from './FileBrowser.svelte'
import { cockpit } from './cockpit.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  cockpit.cwd = null
  cockpit.projects = []
  cockpit.entries = []
})

describe('FileBrowser', () => {
  it('shows the open-folder input and recent projects on mount', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            projects: [
              { path: '/p/foo', name: 'foo', badges: ['py'], last_opened: null },
            ],
          }),
      }),
    )
    render(FileBrowser)
    expect(screen.getByLabelText('项目路径')).toBeInTheDocument()
    expect(await screen.findByText('foo')).toBeInTheDocument()
    expect(screen.getByText('py')).toBeInTheDocument() // badge
  })

  it('renders file entries with names when a directory is open', () => {
    cockpit.cwd = '/p'
    cockpit.entries = [
      { name: 'readme.md', path: '/p/readme.md', is_dir: false, size: 12, ext: 'md' },
      { name: 'src', path: '/p/src', is_dir: true, size: 0, ext: '' },
    ]
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ projects: [] }) }))
    render(FileBrowser)
    expect(screen.getByText('readme.md')).toBeInTheDocument()
    expect(screen.getByText('src')).toBeInTheDocument()
  })
})

describe('FileBrowser · 双视图/排序/隐藏开关', () => {
  it('list view renders header and mono columns; sort=mtime puts newest first', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ projects: [] }) }))
    cockpit.cwd = '/p'
    cockpit.viewMode = 'list'
    cockpit.sortKey = 'mtime'
    cockpit.entries = [
      { name: 'old.md', path: '/p/old.md', is_dir: false, size: 10, ext: 'md', mtime: 100 },
      { name: 'new.md', path: '/p/new.md', is_dir: false, size: 20, ext: 'md', mtime: 200 },
      { name: 'zdir', path: '/p/zdir', is_dir: true, size: 0, ext: '', mtime: 50 },
    ]
    render(FileBrowser)
    expect(await screen.findByText('修改时间')).toBeInTheDocument()
    const rows = [...document.querySelectorAll('.frow .fname')].map((e) => e.textContent?.trim())
    // 目录永远在前;文件按 mtime 降序
    expect(rows[0]).toContain('zdir')
    expect(rows[1]).toContain('new.md')
    expect(rows[2]).toContain('old.md')
    cockpit.viewMode = 'grid'
    cockpit.sortKey = 'name'
    cockpit.entries = []
    cockpit.cwd = null
  })

  it('toggleHidden refetches with hidden=true', async () => {
    const calls: string[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) => {
        calls.push(String(url))
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ path: '/p', entries: [] }) })
      }),
    )
    const c = new (cockpit.constructor as new () => typeof cockpit)()
    c.cwd = '/p'
    c.showHidden = false
    await c.toggleHidden()
    expect(c.showHidden).toBe(true)
    expect(calls.some((u) => u.includes('hidden=true'))).toBe(true)
  })
})

