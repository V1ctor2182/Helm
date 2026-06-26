import { afterEach, describe, expect, it, vi } from 'vitest'
import { MemoryStore } from './memoryStore.svelte'

const ok = (body: unknown) => ({ ok: true, json: () => Promise.resolve(body) })
const M = (over: Record<string, unknown> = {}) => ({
  id: 1,
  text: 't',
  category: 'fact',
  source: 'manual',
  session_id: null,
  tags: [],
  uses: 0,
  pinned: false,
  created_at: null,
  updated_at: null,
  ...over,
})

afterEach(() => vi.restoreAllMocks())

describe('MemoryStore', () => {
  it('load populates items', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ memories: [M()] })))
    const s = new MemoryStore()
    await s.load()
    expect(s.items).toHaveLength(1)
  })

  it('add posts and reloads; empty text is a no-op', async () => {
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve(
        url.includes('/api/memories') && !url.includes('?')
          ? ok(M({ id: 2, text: 'new' }))
          : ok({ memories: [M({ id: 2, text: 'new' })] }),
      ),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new MemoryStore()
    expect(await s.add('   ')).toBeNull() // blank: never hits the network
    const created = await s.add('new', 'preference')
    expect(created).not.toBeNull()
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'POST')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toMatchObject({
      text: 'new',
      category: 'preference',
    })
  })

  it('search stores results separately and clearSearch resets', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(ok({ results: [{ ...M(), score: 0.5 }] })),
    )
    const s = new MemoryStore()
    s.query = 'cat'
    await s.search()
    expect(s.results).toHaveLength(1)
    expect(s.results![0].score).toBe(0.5)
    s.clearSearch()
    expect(s.results).toBeNull()
    expect(s.query).toBe('')
  })

  it('blank query clears results without fetching', async () => {
    const fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
    const s = new MemoryStore()
    s.query = '   '
    await s.search()
    expect(s.results).toBeNull()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('togglePin patches with the flipped value', async () => {
    const fetchMock = vi.fn().mockResolvedValue(ok({ memories: [] }))
    vi.stubGlobal('fetch', fetchMock)
    const s = new MemoryStore()
    await s.togglePin(M({ id: 7, pinned: false }))
    const patch = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'PATCH')
    expect(patch![0]).toContain('/api/memories/7')
    expect(JSON.parse((patch![1] as RequestInit).body as string)).toEqual({ pinned: true })
  })

  it('importJSON accepts {memories:[...]} and a bare array; rejects bad JSON', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        url.includes('import') ? Promise.resolve(ok({ imported: 2 })) : Promise.resolve(ok({ memories: [] })),
      ),
    )
    const s = new MemoryStore()
    expect(await s.importJSON(JSON.stringify({ memories: [M(), M()] }))).toBe(2)
    expect(await s.importJSON(JSON.stringify([M(), M()]))).toBe(2)
    expect(await s.importJSON('not json{')).toBe(0)
    expect(s.error).toContain('JSON')
  })

  it('exportJSON returns a pretty JSON string', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ version: 1, memories: [M()] })))
    const s = new MemoryStore()
    const text = await s.exportJSON()
    expect(text).toContain('"version": 1')
  })
})
