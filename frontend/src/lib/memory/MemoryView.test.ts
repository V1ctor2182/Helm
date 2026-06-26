import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import Memory from './Memory.svelte'
import { memory } from './memoryStore.svelte'

function stubFetch(map: Record<string, unknown>) {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) => {
      const key = Object.keys(map).find((k) => url.includes(k))
      return Promise.resolve({ ok: true, json: () => Promise.resolve(key ? map[key] : {}) })
    }),
  )
}

const M = (over: Record<string, unknown> = {}) => ({
  id: 1,
  text: 'remember dark mode',
  category: 'preference',
  source: 'manual',
  session_id: null,
  tags: [],
  uses: 0,
  pinned: false,
  created_at: null,
  updated_at: null,
  ...over,
})

afterEach(() => {
  vi.restoreAllMocks()
  memory.items = []
  memory.results = null
  memory.query = ''
  memory.filter = 'all'
  memory.error = null
})

describe('Memory panel', () => {
  it('renders the empty state then loaded memories', async () => {
    stubFetch({ '/api/memories': { memories: [M()] } })
    render(Memory)
    expect(await screen.findByText('remember dark mode')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '导出 JSON' })).toBeInTheDocument()
  })

  it('shows the empty hint when there are no memories', async () => {
    stubFetch({ '/api/memories': { memories: [] } })
    render(Memory)
    expect(await screen.findByText(/还没有记忆/)).toBeInTheDocument()
  })

  it('typing and submitting adds a memory', async () => {
    const fetchMock = vi.fn((url: string, init?: RequestInit) => {
      if ((init?.method ?? 'GET') === 'POST') return Promise.resolve({ ok: true, json: () => Promise.resolve(M({ id: 9 })) })
      return Promise.resolve({ ok: true, json: () => Promise.resolve({ memories: [] }) })
    })
    vi.stubGlobal('fetch', fetchMock)
    render(Memory)
    const input = screen.getByLabelText('记忆内容')
    await fireEvent.input(input, { target: { value: 'new memory' } })
    await fireEvent.click(screen.getByRole('button', { name: '添加' }))
    const posted = fetchMock.mock.calls.some(
      (c) => (c[1] as RequestInit)?.method === 'POST' && String((c[1] as RequestInit).body).includes('new memory'),
    )
    expect(posted).toBe(true)
  })
})
