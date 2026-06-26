// RAG store (Svelte 5 runes): registered document sources + semantic retrieval
// over them. Mirrors memoryStore's resilient `#json` helper. `addSource`
// indexes synchronously server-side, so a `busy` flag guards the UI while a
// large directory is being indexed (background indexing is ticketed for later).

export interface RagSource {
  id: number
  path: string
  kind: string
  status: string
  file_count: number
  chunk_count: number
  error: string | null
  created_at: string | null
  indexed_at: string | null
}

export interface RagHit {
  source_id: number
  path: string
  chunk: number
  text: string
  score: number
}

export interface RagStats {
  sources: number
  files: number
  chunks: number
  vector_count: number
}

export class RagStore {
  sources = $state<RagSource[]>([])
  results = $state<RagHit[] | null>(null)
  query = $state('')
  stats = $state<RagStats | null>(null)
  error = $state<string | null>(null)
  busy = $state(false)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    try {
      const res = await fetch(path, init)
      if (!res.ok) return null
      return await res.json()
    } catch {
      return null
    }
  }

  async load(): Promise<void> {
    const body = (await this.#json('/api/rag/sources')) as { sources: RagSource[] } | null
    if (body) this.sources = body.sources
    await this.loadStats()
  }

  async loadStats(): Promise<void> {
    const body = (await this.#json('/api/rag/stats')) as RagStats | null
    if (body) this.stats = body
  }

  async addSource(path: string): Promise<RagSource | null> {
    const p = path.trim()
    if (!p) return null
    this.busy = true
    try {
      const src = (await this.#json('/api/rag/sources', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ path: p }),
      })) as RagSource | null
      if (!src) {
        this.error = '添加失败:路径不存在或无法读取'
        return null
      }
      this.error = null
      await this.load()
      return src
    } finally {
      this.busy = false
    }
  }

  async removeSource(id: number): Promise<void> {
    const ok = await this.#json(`/api/rag/sources/${id}`, { method: 'DELETE' })
    if (ok) await this.load()
    else this.error = '删除失败'
  }

  async reindex(id: number): Promise<void> {
    this.busy = true
    try {
      const ok = await this.#json(`/api/rag/sources/${id}/reindex`, { method: 'POST' })
      if (ok) await this.load()
    } finally {
      this.busy = false
    }
  }

  async search(): Promise<void> {
    const q = this.query.trim()
    if (!q) {
      this.results = null
      return
    }
    const body = (await this.#json(
      `/api/rag/search?q=${encodeURIComponent(q)}`,
    )) as { results: RagHit[] } | null
    this.results = body ? body.results : []
  }

  clearSearch(): void {
    this.query = ''
    this.results = null
  }
}

export const rag = new RagStore()
