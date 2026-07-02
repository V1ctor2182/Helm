import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import CommandPalette from './CommandPalette.svelte'
import { layout } from './layout.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  layout.closePalette()
  layout.setMode('today')
})

describe('CommandPalette', () => {
  it('renders nothing when closed', () => {
    render(CommandPalette)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('shows commands when open and filters by query', async () => {
    layout.openPalette()
    render(CommandPalette)
    expect(screen.getByRole('dialog')).toBeInTheDocument()

    const input = screen.getByLabelText('命令')
    await fireEvent.input(input, { target: { value: 'chat' } })
    const options = screen.getAllByRole('option')
    expect(options.length).toBe(1)
    expect(options[0]).toHaveTextContent('Go to Chat')
  })

  it('Enter runs the selected command and closes the palette', async () => {
    layout.openPalette()
    render(CommandPalette)
    const input = screen.getByLabelText('命令')
    await fireEvent.input(input, { target: { value: 'chat' } })
    await fireEvent.keyDown(input, { key: 'Enter' })
    expect(layout.mode).toBe('chat')
    expect(layout.paletteOpen).toBe(false)
  })

  it('Escape closes the palette', async () => {
    layout.openPalette()
    render(CommandPalette)
    const input = screen.getByLabelText('命令')
    await fireEvent.keyDown(input, { key: 'Escape' })
    expect(layout.paletteOpen).toBe(false)
  })
})

describe('CommandPalette · 文件/内容搜索(FanBox 对齐)', () => {
  it('typing triggers a name search after debounce and lists file hits', async () => {
    const calls: string[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) => {
        calls.push(String(url))
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              results: [{ name: 'helm-notes.md', path: '/p/helm-notes.md', is_dir: false, mtime: 1 }],
              truncated: false,
            }),
        })
      }),
    )
    layout.openPalette()
    render(CommandPalette)
    await fireEvent.input(screen.getByLabelText('命令'), { target: { value: 'helm-notes' } })
    await vi.waitFor(() => {
      expect(calls.some((u) => u.includes('mode=name') && u.includes('q=helm-notes'))).toBe(true)
    })
    expect(await screen.findByText('helm-notes.md')).toBeInTheDocument()
    expect(screen.getByText(/FILE/)).toBeInTheDocument()
  })

  it('内容: prefix switches to content mode and shows line preview; Tab flips scope', async () => {
    const calls: string[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) => {
        calls.push(String(url))
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              results: [{ path: '/p/doc.md', line: '收敛规则在这里', line_no: 2 }],
              truncated: true,
            }),
        })
      }),
    )
    layout.openPalette()
    render(CommandPalette)
    const input = screen.getByLabelText('命令')
    await fireEvent.input(input, { target: { value: '内容:收敛' } })
    await vi.waitFor(() => {
      expect(calls.some((u) => u.includes('mode=content'))).toBe(true)
    })
    expect(await screen.findByText('收敛规则在这里')).toBeInTheDocument()
    expect(screen.getByText(/结果不完整/)).toBeInTheDocument()
    expect(screen.getByText(/全机/)).toBeInTheDocument() // 无 cwd 时范围=全机
    await fireEvent.keyDown(input, { key: 'Tab' })
    // 没有 cwd 时切到 cwd 档也显示全机;只验证不抛错且标签仍在
    expect(screen.getByText(/Tab 切换/)).toBeInTheDocument()
  })
})

