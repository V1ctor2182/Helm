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

  // T2 人话排期:整句只发 {prompt},排期后端解析(契约同捕获坞/notch)。
  it('createNL posts the bare prompt and reloads', async () => {
    const fetchMock = vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve((init?.method ?? 'GET') === 'POST' ? T() : { tasks: [T()] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    expect(await new TasksStore().createNL('每天早上9点汇总未读邮件')).toBe(true)
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'POST')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toEqual({ prompt: '每天早上9点汇总未读邮件' })
  })

  it('createNL surfaces the no-time hint on 422', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, json: () => Promise.resolve({}) }))
    const s = new TasksStore()
    expect(await s.createNL('整理桌面')).toBe(false)
    expect(s.error).toContain('什么时候')
  })

  it('parse hits /api/tasks/parse and returns the label', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true, json: () => Promise.resolve({ parsed: { label: '每天 09:00' } }),
    }))
    expect((await new TasksStore().parse('每天早上9点'))?.label).toBe('每天 09:00')
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
  it('dispatch bar shows a live schedule badge and posts the sentence', async () => {
    const fetchMock = vi.fn((url: string, init?: RequestInit) => {
      const u = String(url)
      if (u.includes('/api/tasks/parse'))
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ parsed: { label: '每天 09:00' } }) })
      if ((init?.method ?? 'GET') === 'POST') return Promise.resolve({ ok: true, json: () => Promise.resolve(T()) })
      return Promise.resolve({ ok: true, json: () => Promise.resolve({ tasks: [], notes: [], providers: [] }) })
    })
    vi.stubGlobal('fetch', fetchMock)
    render(JournalView)
    await fireEvent.click(screen.getByRole('tab', { name: '任务' }))
    const input = screen.getByLabelText('任务指令')
    await fireEvent.input(input, { target: { value: '每天早上9点汇总未读邮件' } })
    expect(await screen.findByText('每天 09:00')).toBeInTheDocument()   // 边打字出徽章
    await fireEvent.click(screen.getByRole('button', { name: '交给 agent' }))
    const post = fetchMock.mock.calls.find(
      (c) => String(c[0]) === '/api/tasks' && (c[1] as RequestInit)?.method === 'POST')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toEqual({ prompt: '每天早上9点汇总未读邮件' })
  })

  it('schedule chip prefers the human nl label over the raw kind', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ notes: [], providers: [], tasks: [] }) }))
    tasks.tasks = [T({ schedule_value: { expr: '0 9 * * *', nl: '每天 09:00' } })]
    render(JournalView)
    await fireEvent.click(screen.getByRole('tab', { name: '任务' }))
    expect(await screen.findByText('每天 09:00')).toBeInTheDocument()
    expect(screen.queryByText('0 9 * * *')).not.toBeInTheDocument()     // cron 表达式退场
  })

  it('lists tasks under the 任务 segment', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ notes: [], providers: [], tasks: [] }) }))
    tasks.tasks = [T({ name: 'mail digest', run_count: 2 })]
    render(JournalView)
    await fireEvent.click(screen.getByRole('tab', { name: '任务' }))
    expect(await screen.findByText('mail digest')).toBeInTheDocument()
    expect(screen.getByText(/2 次/)).toBeInTheDocument()
  })

  it('expands the runs drawer and lists task_runs', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve(
              String(url).includes('/runs')
                ? { runs: [{ id: 1, task_id: 1, status: 'ok', output: 'digest sent', started_at: '2026-07-01T01:00:00+00:00', ended_at: null }] }
                : String(url).includes('/api/tasks')
                  ? { tasks: [T({ name: 'mail digest', run_count: 2 })] }
                  : { notes: [], providers: [] },
            ),
        }),
      ),
    )
    tasks.tasks = [T({ name: 'mail digest', run_count: 2 })]
    render(JournalView)
    await fireEvent.click(screen.getByRole('tab', { name: '任务' }))
    await fireEvent.click(await screen.findByRole('button', { name: '运行记录 mail digest' }))
    expect(await screen.findByText('digest sent')).toBeInTheDocument()
    expect(screen.getByText('ok')).toBeInTheDocument()
    tasks.runsFor = null
  })
})
