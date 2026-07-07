// Notes store (journal-notes-tasks). m1: makes the ⌘N quick-capture durable by
// wiring the capture store's persister seam to POST /api/notes. List/journal/
// convert UI lands in later milestones.

import { capture } from '../capture.svelte'

import { jsonFetch, jsonList } from '../api'

/** AI enrichment(速记管线):链接 parse/摘要/预览元数据。 */
export interface NoteMeta {
  type?: 'youtube' | 'paper' | 'article' | 'inspiration' | 'text'
  url?: string
  title?: string
  summary?: string
  image?: string
  site?: string
  tags?: string[]
  when?: string
  where?: string
  due?: string // T1 分诊:可解析的绝对时刻(本地 ISO),待办临近高亮用
  triage?: { by: 'rule' | 'llm'; confident: boolean }
  links?: { url: string; type?: string; title?: string; summary?: string; image?: string; site?: string }[]
  topic?: string
}

/** T1 分诊回执(POST /api/notes triage:true 的响应附带)。 */
export interface TriageReceipt {
  kind: string
  when: string | null
  where: string | null
  due: string | null
  recurring: boolean
  confident: boolean
}

export interface Note {
  id: number
  kind: string
  title: string | null
  content: string
  tags: string[]
  meta: NoteMeta | null
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
    return jsonFetch(path, init)
  }

  async persist(text: string): Promise<void> {
    this.error = null
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
    const xs = await jsonList<Note>(`/api/notes${q}`, 'notes')
    if (xs) this.notes = xs
  }

  /** T3 自动挡:后端分诊判类+双抽取,返回落库 note+回执(toast 用)。 */
  async createTriage(content: string): Promise<(Note & { triage: TriageReceipt }) | null> {
    if (!content.trim()) return null
    this.error = null
    const out = (await this.#json('/api/notes', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ content, source: 'capture', triage: true }),
    })) as (Note & { triage: TriageReceipt }) | null
    if (out) await this.load()
    else this.error = '速记保存失败'
    return out
  }

  /** 回执「改」:分诊纠错,PATCH kind 回流。 */
  async reclass(id: number, kind: string): Promise<boolean> {
    const ok = await this.#json(`/api/notes/${id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind }),
    })
    if (ok) await this.load()
    return ok !== null
  }

  async create(
    content: string,
    kind: 'note' | 'journal' | 'task' | 'idea' = 'note',
    journalDate: string | null = null,
  ): Promise<boolean> {
    if (!content.trim()) return false
    this.error = null
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
    this.error = null
    const ok = await this.#json(`/api/notes/${id}/to-journal`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ journal_date: date ?? null }),
    })
    if (ok) await this.load()
    return ok !== null
  }

  async toMemory(id: number): Promise<boolean> {
    this.error = null
    const ok = await this.#json(`/api/notes/${id}/to-memory`, { method: 'POST' })
    if (!ok) this.error = '转记忆失败'
    return ok !== null
  }

  /** note→task (intent#1): the note's content becomes the task prompt, linked
   *  via linked_note_id server-side. Schedule comes from the tasks form. */
  async toTask(id: number, kind: string, value: Record<string, unknown>, name = ''): Promise<boolean> {
    this.error = null
    const ok = await this.#json(`/api/notes/${id}/to-task`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name, schedule_kind: kind, schedule_value: value }),
    })
    if (!ok) this.error = '转任务失败(检查 schedule)'
    return ok !== null
  }

  /** T2 人话排期版 note→task:时间用人话说,后端解析;不给则试 note 原文。 */
  async toTaskNL(id: number, nl: string): Promise<boolean> {
    this.error = null
    const ok = await this.#json(`/api/notes/${id}/to-task`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ schedule_nl: nl || null }),
    })
    if (!ok) this.error = '没听出时间——用人话说个时间,如「每天早上 9 点」「明晚 8 点」'
    return ok !== null
  }

  /** 编辑速记/日记内容(PATCH,backlog: 笔记不可编辑)。 */
  async update(id: number, content: string): Promise<boolean> {
    if (!content.trim()) return false
    this.error = null
    const ok = await this.#json(`/api/notes/${id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ content }),
    })
    if (ok) await this.load()
    else this.error = '保存失败'
    return ok !== null
  }

  /** AI 归类纠错:整份 meta 回写(如移出集合=拿掉 topic) */
  async updateMeta(id: number, meta: NoteMeta): Promise<boolean> {
    const ok = await this.#json(`/api/notes/${id}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ meta }),
    })
    if (ok) await this.load()
    return ok !== null
  }

  async remove(id: number): Promise<void> {
    const ok = await this.#json(`/api/notes/${id}`, { method: 'DELETE' })
    if (ok) await this.load()
  }

  // ── AI 今日小结 (intent#2) ──────────────────────────────────────────────

  async loadProviders(): Promise<void> {
    const xs = await jsonList<NoteProvider>('/api/providers', 'providers')
    if (xs) this.providers = xs
  }

  async summarizeToday(date: string, days = 1): Promise<void> {
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
        body: JSON.stringify({ provider_id: p.id, model: p.models[0] ?? '', journal_date: date, days, save: false }),
      })) as { summary: string } | null
      this.summary = body ? body.summary : '小结生成失败(区间无日记或 provider 不可用)'
    } finally {
      this.summarizing = false
    }
  }
}

export const notes = new NotesStore()
