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

  it('renders code in a <pre> from the text endpoint', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ content: 'print(1)', truncated: false }),
      }),
    )
    render(PreviewPane)
    cockpit.selected = entry({ name: 'a.py', path: '/p/a.py', ext: 'py' })
    expect(await screen.findByText('print(1)')).toBeInTheDocument()
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
        json: () => Promise.resolve({ content: 'B-content', truncated: false }),
      })
    vi.stubGlobal('fetch', f)
    render(PreviewPane)

    cockpit.selected = entry({ name: 'a.py', path: '/p/a.py', ext: 'py' })
    flushSync() // load(A) starts, awaits aPending
    cockpit.selected = entry({ name: 'b.py', path: '/p/b.py', ext: 'py' })
    flushSync() // load(B) starts, resolves
    expect(await screen.findByText('B-content')).toBeInTheDocument()

    // A resolves late — the token guard must drop its result.
    resolveA({ ok: true, json: () => Promise.resolve({ content: 'A-content', truncated: false }) })
    await Promise.resolve()
    await Promise.resolve()
    expect(screen.queryByText('A-content')).toBeNull()
    expect(screen.getByText('B-content')).toBeInTheDocument()
  })

  it('shows a no-preview message for unknown types', async () => {
    render(PreviewPane)
    cockpit.selected = entry({ name: 'a.exe', path: '/p/a.exe', ext: 'exe' })
    expect(await screen.findByText(/暂不支持预览/)).toBeInTheDocument()
  })
})
