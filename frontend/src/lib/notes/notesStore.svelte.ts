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

export class NotesStore {
  notes = $state<Note[]>([])
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
}

export const notes = new NotesStore()
