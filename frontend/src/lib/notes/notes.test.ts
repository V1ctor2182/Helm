import { afterEach, describe, expect, it, vi } from 'vitest'
import { NotesStore } from './notesStore.svelte'
import { CaptureStore } from '../capture.svelte'
import { capture } from '../capture.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  capture.items = []
})

describe('NotesStore', () => {
  it('persist POSTs the capture text as a note', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ id: 1 }) })
    vi.stubGlobal('fetch', fetchMock)
    const s = new NotesStore()
    await s.persist('buy milk')
    expect(fetchMock.mock.calls[0][0]).toBe('/api/notes')
    expect(JSON.parse((fetchMock.mock.calls[0][1] as RequestInit).body as string)).toEqual({
      content: 'buy milk',
      source: 'capture',
    })
  })

  it('wireCapture makes capture.submit persist to the backend', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ id: 1 }) })
    vi.stubGlobal('fetch', fetchMock)
    const s = new NotesStore()
    s.wireCapture()
    await capture.submit('a captured thought')
    // capture stays instant (item added) AND it persisted
    expect(capture.items[0].text).toBe('a captured thought')
    expect(fetchMock).toHaveBeenCalledWith('/api/notes', expect.objectContaining({ method: 'POST' }))
  })

  it('load populates notes', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ notes: [{ id: 1, content: 'x', kind: 'note' }] }) }))
    const s = new NotesStore()
    await s.load()
    expect(s.notes).toHaveLength(1)
  })

  it('toJournal posts the date and reloads', async () => {
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(url.includes('to-journal') ? { id: 1, kind: 'journal' } : { notes: [] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new NotesStore()
    expect(await s.toJournal(3, '2026-06-27')).toBe(true)
    const post = fetchMock.mock.calls.find((c) => String(c[0]).includes('to-journal'))
    expect(post![0]).toContain('/api/notes/3/to-journal')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toEqual({ journal_date: '2026-06-27' })
  })

  it('toTask posts the schedule to /to-task', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ id: 1 }) })
    vi.stubGlobal('fetch', fetchMock)
    const s = new NotesStore()
    expect(await s.toTask(4, 'cron', { expr: '0 9 * * *' })).toBe(true)
    expect(fetchMock.mock.calls[0][0]).toBe('/api/notes/4/to-task')
    expect(JSON.parse((fetchMock.mock.calls[0][1] as RequestInit).body as string)).toEqual({
      name: '',
      schedule_kind: 'cron',
      schedule_value: { expr: '0 9 * * *' },
    })
  })

  it('update PATCHes content and reloads', async () => {
    const fetchMock = vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(init?.method === 'PATCH' ? { id: 6 } : { notes: [] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new NotesStore()
    expect(await s.update(6, 'edited text')).toBe(true)
    const patch = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'PATCH')
    expect(patch![0]).toBe('/api/notes/6')
    expect(JSON.parse((patch![1] as RequestInit).body as string)).toEqual({ content: 'edited text' })
  })

  it('toMemory posts and reports failure', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, json: () => Promise.resolve({}) }))
    const s = new NotesStore()
    expect(await s.toMemory(5)).toBe(false)
    expect(s.error).toContain('记忆')
  })

  it('surfaces an error when persist fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, json: () => Promise.resolve({}) }))
    const s = new NotesStore()
    await s.persist('x')
    expect(s.error).toContain('失败')
    // CaptureStore still works in-memory even if persistence fails
    const cap = new CaptureStore()
    expect(await cap.submit('y')).toBe(true)
  })
})
