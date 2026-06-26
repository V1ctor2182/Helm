// Memory store (Svelte 5 runes): the brain's persistent memories — list,
// add, delete, pin, keyword/semantic search, and JSON import/export. Mirrors
// chatStore's resilient `#json` fetch helper (null on any failure, surfaced
// via `error`). Search results are kept separate from the full list so the
// browse view is never lost while searching.

export interface Memory {
  id: number
  text: string
  category: string
  source: string
  session_id: string | null
  tags: string[]
  uses: number
  pinned: boolean
  created_at: string | null
  updated_at: string | null
}

export type Category = 'fact' | 'preference' | 'decision'
export const CATEGORIES: Category[] = ['fact', 'preference', 'decision']

export class MemoryStore {
  items = $state<Memory[]>([])
  results = $state<(Memory & { score: number })[] | null>(null)
  query = $state('')
  filter = $state<Category | 'all'>('all')
  error = $state<string | null>(null)

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
    const q = this.filter === 'all' ? '' : `?category=${this.filter}`
    const body = (await this.#json(`/api/memories${q}`)) as { memories: Memory[] } | null
    if (body) this.items = body.memories
  }

  setFilter(f: Category | 'all'): void {
    this.filter = f
    void this.load()
  }

  async add(text: string, category: Category = 'fact'): Promise<Memory | null> {
    if (!text.trim()) return null
    const created = (await this.#json('/api/memories', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text, category }),
    })) as Memory | null
    if (!created) {
      this.error = '添加记忆失败'
      return null
    }
    this.error = null
    await this.load()
    return created
  }

  async remove(id: number): Promise<void> {
    const ok = await this.#json(`/api/memories/${id}`, { method: 'DELETE' })
    if (ok) await this.load()
    else this.error = '删除失败'
  }

  async togglePin(m: Memory): Promise<void> {
    const ok = await this.#json(`/api/memories/${m.id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pinned: !m.pinned }),
    })
    if (ok) await this.load()
  }

  async search(): Promise<void> {
    const q = this.query.trim()
    if (!q) {
      this.results = null
      return
    }
    const cat = this.filter === 'all' ? '' : `&category=${this.filter}`
    const body = (await this.#json(
      `/api/memories/search?q=${encodeURIComponent(q)}${cat}`,
    )) as { results: (Memory & { score: number })[] } | null
    this.results = body ? body.results : []
  }

  clearSearch(): void {
    this.query = ''
    this.results = null
  }

  async exportJSON(): Promise<string | null> {
    const body = await this.#json('/api/memories/export')
    return body ? JSON.stringify(body, null, 2) : null
  }

  async importJSON(text: string, replace = false): Promise<number> {
    let parsed: unknown
    try {
      parsed = JSON.parse(text)
    } catch {
      this.error = 'JSON 解析失败'
      return 0
    }
    const memories = Array.isArray(parsed)
      ? parsed
      : (parsed as { memories?: unknown }).memories
    if (!Array.isArray(memories)) {
      this.error = '格式不对:需要 memories 数组或顶层数组'
      return 0
    }
    const body = (await this.#json('/api/memories/import', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ memories, replace }),
    })) as { imported: number } | null
    if (!body) {
      this.error = '导入失败'
      return 0
    }
    this.error = null
    await this.load()
    return body.imported
  }
}

export const memory = new MemoryStore()
