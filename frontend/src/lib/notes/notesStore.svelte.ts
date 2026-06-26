// Notes store (journal-notes-tasks). m1: makes the ⌘N quick-capture durable by
// wiring the capture store's persister seam to POST /api/notes. List/journal/
// convert UI lands in later milestones.

import { capture } from '../capture.svelte'

export interface Note {
  id: number
  kind: string
  title: string | null
  content: string
  tags: string[]
  pinned: boolean
  source: string
  journal_date: string | null
  created_at: string | null
  updated_at: string | null
}

export interface NoteProvider {
  id: number
  name: string
  models: string[]
}

export class NotesStore {
  notes = $state<Note[]>([])
  error = $state<string | null>(null)
  providers = $state<NoteProvider[]>([])
  summary = $state<string | null>(null)
  summarizing = $state(false)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    try {
      const res = await fetch(path, init)
      if (!res.ok) return null
      return await res.json()
    } catch {
      return null
    }
  }

  async persist(text: string): Promise<void> {
    const ok = await this.#json('/api/notes', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ content: text, source: 'capture' }),
    })
    if (!ok) this.error = '速记保存失败'
  }

  /** Make ⌘N quick captures durable (constraint 3f699ed0). */
  wireCapture(): void {
    capture.setPersister((t) => this.persist(t))
  }

  async load(kind?: string): Promise<void> {
    const q = kind ? `?kind=${kind}` : ''
    const body = (await this.#json(`/api/notes${q}`)) as { notes: Note[] } | null
    if (body) this.notes = body.notes
  }

  async create(
    content: string,
    kind: 'note' | 'journal' = 'note',
    journalDate: string | null = null,
  ): Promise<boolean> {
    if (!content.trim()) return false
    const ok = await this.#json('/api/notes', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ content, kind, journal_date: journalDate }),
    })
    if (ok) await this.load()
    else this.error = '保存失败'
    return ok !== null
  }

  // ── convert (intent#1: 一键转 记忆/日记) ────────────────────────────────

  async toJournal(id: number, date?: string): Promise<boolean> {
    const ok = await this.#json(`/api/notes/${id}/to-journal`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ journal_date: date ?? null }),
    })
    if (ok) await this.load()
    return ok !== null
  }

  async toMemory(id: number): Promise<boolean> {
    const ok = await this.#json(`/api/notes/${id}/to-memory`, { method: 'POST' })
    if (!ok) this.error = '转记忆失败'
    return ok !== null
  }

  async remove(id: number): Promise<void> {
    const ok = await this.#json(`/api/notes/${id}`, { method: 'DELETE' })
    if (ok) await this.load()
  }

  // ── AI 今日小结 (intent#2) ──────────────────────────────────────────────

  async loadProviders(): Promise<void> {
    const body = (await this.#json('/api/providers')) as { providers: NoteProvider[] } | null
    if (body) this.providers = body.providers
  }

  async summarizeToday(date: string): Promise<void> {
    const p = this.providers[0]
    if (!p) {
      this.error = '没有可用的模型 provider — 先在 Chat 里配置一个'
      return
    }
    this.summarizing = true
    this.summary = null
    try {
      const body = (await this.#json('/api/notes/journal/summary', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ provider_id: p.id, model: p.models[0] ?? '', journal_date: date, save: false }),
      })) as { summary: string } | null
      this.summary = body ? body.summary : '小结生成失败(无当天日记或 provider 不可用)'
    } finally {
      this.summarizing = false
    }
  }
}

export const notes = new NotesStore()
