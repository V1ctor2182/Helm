import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { TasksStore } from './tasksStore.svelte'
import { NotesStore } from './notesStore.svelte'
import JournalView from './JournalView.svelte'
import { tasks } from './tasksStore.svelte'
import { notes } from './notesStore.svelte'

const T = (over: Record<string, unknown> = {}) => ({
  id: 1,
  name: 'digest',
  prompt: 'summarize mail',
  schedule_kind: 'cron',
  schedule_value: { expr: '0 9 * * *' },
  execution_mode: 'new_conversation',
  enabled: true,
  next_run: '2026-06-28T09:00:00+00:00',
  last_status: null,
  run_count: 0,
  linked_note_id: null,
  ...over,
})

afterEach(() => {
  vi.restoreAllMocks()
  tasks.tasks = []
  tasks.error = null
  notes.notes = []
  notes.providers = []
  notes.summary = null
})

describe('TasksStore', () => {
  it('create posts the schedule and reloads', async () => {
    const fetchMock = vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve((init?.method ?? 'GET') === 'POST' ? T() : { tasks: [T()] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new TasksStore()
    expect(await s.create('', 'do it', 'cron', { expr: '0 9 * * *' })).toBe(true)
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'POST')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toMatchObject({ prompt: 'do it', schedule_kind: 'cron' })
  })

  it('toggle flips enabled', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ tasks: [] }) })
    vi.stubGlobal('fetch', fetchMock)
    await new TasksStore().toggle(T({ id: 3, enabled: true }))
    const post = fetchMock.mock.calls.find((c) => String(c[0]).includes('/enabled'))
    expect(JSON.parse((post![1] as RequestInit).body as string)).toEqual({ enabled: false })
  })
})

describe('NotesStore.summarizeToday', () => {
  it('posts to the summary endpoint with the first provider', async () => {
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(url.includes('summary') ? { summary: '今天很高效' } : {}) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new NotesStore()
    s.providers = [{ id: 2, name: 'Claude', models: ['opus'] }]
    await s.summarizeToday('2026-06-27')
    expect(s.summary).toBe('今天很高效')
    const post = fetchMock.mock.calls.find((c) => String(c[0]).includes('summary'))
    expect(JSON.parse((post![1] as RequestInit).body as string)).toMatchObject({ provider_id: 2, model: 'opus', journal_date: '2026-06-27' })
  })

  it('errors with no provider', async () => {
    vi.stubGlobal('fetch', vi.fn())
    const s = new NotesStore()
    await s.summarizeToday('2026-06-27')
    expect(s.error).toContain('provider')
  })
})

describe('JournalView tasks view', () => {
  it('lists tasks under the 任务 segment', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ notes: [], providers: [], tasks: [] }) }))
    tasks.tasks = [T({ name: 'mail digest', run_count: 2 })]
    render(JournalView)
    await fireEvent.click(screen.getByRole('tab', { name: '任务' }))
    expect(await screen.findByText('mail digest')).toBeInTheDocument()
    expect(screen.getByText(/2 次/)).toBeInTheDocument()
  })
})
