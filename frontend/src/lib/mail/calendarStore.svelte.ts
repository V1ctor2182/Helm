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

export interface CalDavAccount {
  id: number
  name: string
  url: string
  username: string
}

export class CalendarStore {
  events = $state<CalEvent[]>([])
  error = $state<string | null>(null)
  caldavAccounts = $state<CalDavAccount[]>([])
  syncing = $state(false)
  syncMsg = $state<string | null>(null)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    return jsonFetch(path, init)
  }

  #post(path: string, body?: unknown): Promise<unknown | null> {
    return this.#json(path, {
      method: 'POST',
      headers: body ? { 'content-type': 'application/json' } : {},
      body: body ? JSON.stringify(body) : undefined,
    })
  }

  async loadCaldav(): Promise<void> {
    const b = (await this.#json('/api/calendar/accounts')) as { accounts: CalDavAccount[] } | null
    if (b) this.caldavAccounts = b.accounts
  }

  async addCaldav(a: { name: string; url: string; username: string; password: string }): Promise<boolean> {
    const r = await this.#post('/api/calendar/accounts', a)
    if (r) await this.loadCaldav()
    else this.error = '添加 CalDAV 账户失败'
    return r !== null
  }

  async syncCaldav(): Promise<void> {
    if (!this.caldavAccounts.length) return
    this.syncing = true
    try {
      let pulled = 0
      let pushed = 0
      for (const acc of this.caldavAccounts) {
        const r = (await this.#post(`/api/calendar/accounts/${acc.id}/sync`)) as
          | { pulled_new: number; pushed: number }
          | null
        if (r) {
          pulled += r.pulled_new
          pushed += r.pushed
        }
      }
      await this.load()
      this.syncMsg = `同步完成:拉取 ${pulled} · 推送 ${pushed}`
    } finally {
      this.syncing = false
    }
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
