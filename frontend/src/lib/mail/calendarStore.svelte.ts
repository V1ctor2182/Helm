// Calendar store (email-calendar m5): local events + .ics import/export.

import { jsonFetch } from '../api'

export interface CalEvent {
  id: number
  uid: string
  summary: string
  description: string
  location: string
  start: string | null
  end: string | null
  all_day: boolean
  source: string
}

export class CalendarStore {
  events = $state<CalEvent[]>([])
  error = $state<string | null>(null)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    return jsonFetch(path, init)
  }

  async load(): Promise<void> {
    const b = (await this.#json('/api/calendar/events')) as { events: CalEvent[] } | null
    if (b) this.events = b.events
  }

  async add(summary: string, start: string): Promise<boolean> {
    if (!summary.trim() || !start) return false
    const ok = await this.#json('/api/calendar/events', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ summary, start }),
    })
    if (ok) await this.load()
    else this.error = '创建事件失败'
    return ok !== null
  }

  async remove(id: number): Promise<void> {
    const ok = await this.#json(`/api/calendar/events/${id}`, { method: 'DELETE' })
    if (ok) await this.load()
  }

  async importIcs(ics: string): Promise<number> {
    const b = (await this.#json('/api/calendar/import', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ics }),
    })) as { imported: number } | null
    if (b) await this.load()
    return b ? b.imported : 0
  }

  async exportIcs(): Promise<string> {
    try {
      const res = await fetch('/api/calendar/export')
      return res.ok ? await res.text() : ''
    } catch {
      return ''
    }
  }
}

export const calendar = new CalendarStore()
