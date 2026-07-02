import { render, screen } from '@testing-library/svelte'
import { flushSync } from 'svelte'
import { afterEach, describe, expect, it, vi } from 'vitest'
import PreviewPane from './PreviewPane.svelte'
import { cockpit, type Entry } from './cockpit.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  cockpit.selected = null
})

const entry = (over: Partial<Entry>): Entry => ({
  name: 'f',
  path: '/p/f',
  is_dir: false,
  size: 1,
  ext: '',
  ...over,
})

describe('PreviewPane', () => {
  it('prompts to select a file when nothing is selected', () => {
    render(PreviewPane)
    expect(screen.getByText('选择一个文件以预览')).toBeInTheDocument()
  })

  it('renders code as an editable textarea (preview IS edit)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ content: 'print(1)', truncated: false, mtime: 111 }),
      }),
    )
    render(PreviewPane)
    cockpit.selected = entry({ name: 'a.py', path: '/p/a.py', ext: 'py' })
    expect(await screen.findByDisplayValue('print(1)')).toBeInTheDocument()
  })

  it('renders markdown as sanitized HTML', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ content: '# Hello', truncated: false }),
      }),
    )
    render(PreviewPane)
    cockpit.selected = entry({ name: 'r.md', path: '/p/r.md', ext: 'md' })
    expect(await screen.findByRole('heading', { name: 'Hello' })).toBeInTheDocument()
  })

  it('renders an <img> for images without fetching text', async () => {
    const f = vi.fn()
    vi.stubGlobal('fetch', f)
    render(PreviewPane)
    cockpit.selected = entry({ name: 'p.png', path: '/p/p.png', ext: 'png' })
    const img = await screen.findByRole('img', { name: 'p.png' })
    expect(img.getAttribute('src')).toContain('/api/cockpit/raw?path=')
    expect(f).not.toHaveBeenCalled() // images don't hit the text endpoint
  })

  it('a stale fetch does not overwrite a newer selection', async () => {
    let resolveA!: (v: unknown) => void
    const aPending = new Promise((r) => {
      resolveA = r
    })
    const f = vi
      .fn()
      .mockReturnValueOnce(aPending) // A: stays pending
      .mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ content: 'B-content', truncated: false, mtime: 1 }),
      })
    vi.stubGlobal('fetch', f)
    render(PreviewPane)

    cockpit.selected = entry({ name: 'a.py', path: '/p/a.py', ext: 'py' })
    flushSync() // load(A) starts, awaits aPending
    cockpit.selected = entry({ name: 'b.py', path: '/p/b.py', ext: 'py' })
    flushSync() // load(B) starts, resolves
    expect(await screen.findByDisplayValue('B-content')).toBeInTheDocument()

    // A resolves late — the token guard must drop its result.
    resolveA({ ok: true, json: () => Promise.resolve({ content: 'A-content', truncated: false, mtime: 2 }) })
    await Promise.resolve()
    await Promise.resolve()
    expect(screen.queryByDisplayValue('A-content')).toBeNull()
    expect(screen.getByDisplayValue('B-content')).toBeInTheDocument()
  })

  it('shows a no-preview message for unknown types', async () => {
    render(PreviewPane)
    cockpit.selected = entry({ name: 'a.exe', path: '/p/a.exe', ext: 'exe' })
    expect(await screen.findByText(/暂不支持预览/)).toBeInTheDocument()
  })
})

describe('PreviewPane · 预览即编辑', () => {
  it('typing marks dirty and ⌘S saves with expected_mtime', async () => {
    const calls: { url: string; init?: RequestInit }[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string, init?: RequestInit) => {
        calls.push({ url, init })
        return Promise.resolve({
          ok: true,
          status: 200,
          json: () =>
            Promise.resolve(
              init?.method === 'POST' ? { mtime: 222 } : { content: 'v1', truncated: false, mtime: 111 },
            ),
        })
      }),
    )
    render(PreviewPane)
    cockpit.selected = entry({ name: 'a.py', path: '/p/a.py', ext: 'py' })
    const box = (await screen.findByDisplayValue('v1')) as HTMLTextAreaElement
    const { fireEvent } = await import('@testing-library/dom')
    await fireEvent.input(box, { target: { value: 'v2' } })
    expect(await screen.findByText('编辑中…')).toBeInTheDocument() // dirty 标记生效
    await fireEvent.keyDown(box, { key: 's', metaKey: true }) // ⌘S 立即落盘
    await vi.waitFor(() => {
      expect(calls.some((c) => c.init?.method === 'POST')).toBe(true)
    })
    const post = calls.find((c) => c.init?.method === 'POST')!
    expect(JSON.parse(post.init!.body as string)).toEqual({
      path: '/p/a.py',
      content: 'v2',
      expected_mtime: 111,
    })
    await vi.waitFor(async () => {
      expect(await screen.findByText(/秒前已保存/)).toBeInTheDocument()
    })
  })

  it('409 shows the conflict bar; 覆盖 posts without expected_mtime', async () => {
    const calls: { url: string; init?: RequestInit }[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string, init?: RequestInit) => {
        calls.push({ url, init })
        if (init?.method === 'POST') {
          const body = JSON.parse(init.body as string)
          if (body.expected_mtime != null) {
            return Promise.resolve({ ok: false, status: 409, json: () => Promise.resolve({}) })
          }
          return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ mtime: 999 }) })
        }
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ content: 'base', truncated: false, mtime: 5 }) })
      }),
    )
    render(PreviewPane)
    cockpit.selected = entry({ name: 'b.ts', path: '/p/b.ts', ext: 'ts' })
    const box = (await screen.findByDisplayValue('base')) as HTMLTextAreaElement
    const { fireEvent } = await import('@testing-library/dom')
    await fireEvent.input(box, { target: { value: 'mine' } })
    await fireEvent.keyDown(box, { key: 's', metaKey: true })
    expect(await screen.findByText('文件被外部修改')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: '覆盖' }))
    await vi.waitFor(() => {
      const posts = calls.filter((c) => c.init?.method === 'POST')
      expect(posts.length).toBeGreaterThan(1)
      expect(JSON.parse(posts.at(-1)!.init!.body as string).expected_mtime).toBeNull()
    })
  })
})
