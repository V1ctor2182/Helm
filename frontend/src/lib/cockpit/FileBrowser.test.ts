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
