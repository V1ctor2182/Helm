import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
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

describe('FileBrowser · 键盘导航 + Esc 分层', () => {
  const seed = () => {
    cockpit.cwd = '/p'
    cockpit.viewMode = 'list' // 列表=单列,jsdom 量不了网格列
    cockpit.entries = [
      { name: 'adir', path: '/p/adir', is_dir: true, size: 0, ext: '', mtime: 3 },
      { name: 'b.md', path: '/p/b.md', is_dir: false, size: 5, ext: 'md', mtime: 2 },
      { name: 'c.txt', path: '/p/c.txt', is_dir: false, size: 5, ext: 'txt', mtime: 1 },
    ]
  }
  const reset = () => {
    cockpit.cwd = null
    cockpit.entries = []
    cockpit.selected = null
    cockpit.viewMode = 'grid'
  }

  it('↓ 移动光标,Enter 打开(目录→browse);光标扫过目录不误入', async () => {
    const calls: string[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) => {
        calls.push(String(url))
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ path: '/p/adir', entries: [] }) })
      }),
    )
    seed()
    render(FileBrowser)
    await fireEvent.keyDown(window, { key: 'ArrowDown' })
    expect(document.querySelector('.frow.cursor')?.textContent).toContain('adir')
    expect(calls.filter((u) => u.includes('/files'))).toHaveLength(0) // 光标≠打开
    await fireEvent.keyDown(window, { key: 'Enter' })
    await vi.waitFor(() => {
      expect(calls.some((u) => u.includes(encodeURIComponent('/p/adir')))).toBe(true)
    })
    reset()
  })

  it('F2 开重命名对话框;Esc 一次退一层(对话框→预览)', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ entries: [], projects: [] }) }))
    seed()
    cockpit.selected = { name: 'b.md', path: '/p/b.md', is_dir: false, size: 5, ext: 'md', mtime: 2 }
    render(FileBrowser)
    await fireEvent.keyDown(window, { key: 'ArrowDown' }) // cursor 0
    await fireEvent.keyDown(window, { key: 'ArrowDown' }) // cursor 1 = b.md
    await fireEvent.keyDown(window, { key: 'F2' })
    expect(await screen.findByText(/重命名为/)).toBeInTheDocument()
    await fireEvent.keyDown(window, { key: 'Escape' }) // 第一层:关对话框
    expect(screen.queryByText(/重命名为/)).toBeNull()
    expect(cockpit.selected).not.toBeNull() // 预览还在
    await fireEvent.keyDown(window, { key: 'Escape' }) // 第二层:关预览
    expect(cockpit.selected).toBeNull()
    reset()
  })

  it('⌘⌫ 对光标文件走废纸篓;Backspace 上一级', async () => {
    const calls: { url: string; body?: unknown }[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string, init?: RequestInit) => {
        calls.push({ url: String(url), body: init?.body ? JSON.parse(init.body as string) : undefined })
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ path: '/p', entries: [], trashed: 'x' }) })
      }),
    )
    seed()
    render(FileBrowser)
    await fireEvent.keyDown(window, { key: 'ArrowDown' })
    await fireEvent.keyDown(window, { key: 'ArrowDown' }) // b.md(文件→秒删)
    await fireEvent.keyDown(window, { key: 'Backspace', metaKey: true })
    await vi.waitFor(() => {
      expect(calls.some((c) => c.url.includes('/fs/trash') && (c.body as { path: string }).path === '/p/b.md')).toBe(true)
    })
    await fireEvent.keyDown(window, { key: 'Backspace' })
    await vi.waitFor(() => {
      expect(calls.some((c) => c.url.includes(encodeURIComponent('/p')) && c.url.includes('/files'))).toBe(true)
    })
    reset()
  })
})

