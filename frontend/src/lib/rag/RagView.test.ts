import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import Rag from './Rag.svelte'
import BrainPanel from '../memory/BrainPanel.svelte'
import { rag } from './ragStore.svelte'

function stubFetch(map: Record<string, unknown>) {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) => {
      const key = Object.keys(map).find((k) => url.includes(k))
      return Promise.resolve({ ok: true, json: () => Promise.resolve(key ? map[key] : {}) })
    }),
  )
}

afterEach(() => {
  vi.restoreAllMocks()
  rag.sources = []
  rag.results = null
  rag.query = ''
  rag.stats = null
  rag.error = null
  rag.busy = false
})

describe('Rag panel', () => {
  it('shows the empty state, then lists sources with counts', async () => {
    stubFetch({
      '/api/rag/stats': { sources: 1, files: 2, chunks: 8, vector_count: 0 },
      '/api/rag/sources': { sources: [{ id: 1, path: '/docs', kind: 'dir', status: 'indexed', file_count: 2, chunk_count: 8, error: null, created_at: null, indexed_at: null }] },
    })
    render(Rag)
    expect(await screen.findByText('/docs')).toBeInTheDocument()
    expect(screen.getByText('indexed')).toBeInTheDocument()
    expect(screen.getByText(/2 文件 · 8 块/)).toBeInTheDocument()
  })

  it('renders retrieval results when a search returns hits', async () => {
    stubFetch({
      '/api/rag/stats': { sources: 0, files: 0, chunks: 0, vector_count: 0 },
      '/api/rag/sources': { sources: [] },
      '/api/rag/search': { results: [{ source_id: 1, path: '/docs/a.md', chunk: 0, text: 'a relevant snippet', score: 0.81 }] },
    })
    render(Rag)
    const box = screen.getByLabelText('检索')
    await fireEvent.input(box, { target: { value: 'snippet' } })
    await fireEvent.click(screen.getByRole('button', { name: '检索' }))
    expect(await screen.findByText('a relevant snippet')).toBeInTheDocument()
    expect(screen.getByText('/docs/a.md')).toBeInTheDocument()
  })
})

describe('BrainPanel', () => {
  it('toggles between 记忆, 知识库 and Skills', async () => {
    stubFetch({
      '/api/memories': { memories: [] },
      '/api/rag/stats': { sources: 0, files: 0, chunks: 0, vector_count: 0 },
      '/api/rag/sources': { sources: [] },
      '/api/skills': { skills: [], total: 0, healthy: 0, unhealthy: 0 },
    })
    render(BrainPanel)
    // memory view is default
    expect(await screen.findByText(/还没有记忆/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('tab', { name: '知识库' }))
    expect(await screen.findByText(/还没有文档源/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('tab', { name: 'Skills' }))
    expect(await screen.findByText(/没有发现 skills/)).toBeInTheDocument()
  })
})
