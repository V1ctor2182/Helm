import { afterEach, describe, expect, it, vi } from 'vitest'
import { RagStore } from './ragStore.svelte'

const ok = (body: unknown) => ({ ok: true, json: () => Promise.resolve(body) })
const notFound = () => ({ ok: false, json: () => Promise.resolve({}) })
const SRC = (over: Record<string, unknown> = {}) => ({
  id: 1,
  path: '/docs',
  kind: 'dir',
  status: 'indexed',
  file_count: 3,
  chunk_count: 12,
  error: null,
  created_at: null,
  indexed_at: null,
  ...over,
})

afterEach(() => vi.restoreAllMocks())

describe('RagStore', () => {
  it('load populates sources and stats', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve(
          url.includes('/stats')
            ? ok({ sources: 1, files: 3, chunks: 12, vector_count: 0 })
            : ok({ sources: [SRC()] }),
        ),
      ),
    )
    const s = new RagStore()
    await s.load()
    expect(s.sources).toHaveLength(1)
    expect(s.stats?.chunks).toBe(12)
  })

  it('addSource posts the path and clears busy; surfaces 404 as error', async () => {
    const okFetch = vi.fn((url: string) =>
      Promise.resolve(url.includes('/stats') ? ok({ sources: 0, files: 0, chunks: 0, vector_count: 0 }) : url.match(/sources$/) ? ok(SRC({ id: 9 })) : ok({ sources: [SRC({ id: 9 })] })),
    )
    vi.stubGlobal('fetch', okFetch)
    const s = new RagStore()
    const created = await s.addSource('/docs')
    expect(created?.id).toBe(9)
    expect(s.busy).toBe(false)

    // empty path is a no-op (no fetch)
    expect(await s.addSource('   ')).toBeNull()

    // 404 → error message, busy reset
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(notFound()))
    const s2 = new RagStore()
    expect(await s2.addSource('/nope')).toBeNull()
    expect(s2.error).toContain('路径不存在')
    expect(s2.busy).toBe(false)
  })

  it('search keeps results separate; clearSearch resets; blank query no-ops', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      ok({ results: [{ source_id: 1, path: '/docs/a.md', chunk: 0, text: 'hit', score: 0.7 }] }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new RagStore()
    s.query = 'cat'
    await s.search()
    expect(s.results).toHaveLength(1)
    expect(s.results![0].path).toBe('/docs/a.md')

    s.clearSearch()
    expect(s.results).toBeNull()
    expect(s.query).toBe('')

    fetchMock.mockClear()
    s.query = '   '
    await s.search()
    expect(s.results).toBeNull()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('reindex posts to the reindex endpoint', async () => {
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve(url.includes('/stats') ? ok({ sources: 0, files: 0, chunks: 0, vector_count: 0 }) : ok({ sources: [] })),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new RagStore()
    await s.reindex(5)
    const call = fetchMock.mock.calls.find((c) => String(c[0]).includes('/reindex'))
    expect(call![0]).toContain('/api/rag/sources/5/reindex')
    expect((call![1] as RequestInit).method).toBe('POST')
  })
})
