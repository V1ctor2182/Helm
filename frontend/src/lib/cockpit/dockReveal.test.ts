import { render, screen } from '@testing-library/svelte'
import { describe, expect, it, vi } from 'vitest'
import DockHost from './DockHost.svelte'
import { cockpit } from './cockpit.svelte'
import { dock } from './dock.svelte'

describe('DockHost 回归:reveal 自激循环(2026-07-03 真机踩坑)', () => {
  it('selecting a file updates the preview inside DockHost', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ content: 'hello', truncated: false, mtime: 1 }),
    }))
    dock.resetLayout()
    render(DockHost)
    cockpit.selected = { name: 'a.txt', path: '/p/a.txt', is_dir: false, size: 5, ext: 'txt', mtime: 1 }
    const t = await screen.findByTitle('/p/a.txt')
    expect(t).toBeInTheDocument()
    cockpit.selected = null
  })
})
