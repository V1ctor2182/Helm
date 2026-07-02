import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { CalendarStore } from './calendarStore.svelte'
import { MailStore } from './mailStore.svelte'
import Mail from './Mail.svelte'
import { calendar } from './calendarStore.svelte'
import { mail } from './mailStore.svelte'

const EV = (over = {}) => ({
  id: 1, uid: 'u', summary: 'Sync', description: '', location: '',
  start: '2026-06-27T09:00:00+00:00', end: null, all_day: false, source: 'local', ...over,
})

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ events: [], accounts: [], emails: [], providers: [] }) }))
})
afterEach(() => {
  vi.restoreAllMocks()
  calendar.events = []
  mail.emails = []
  mail.current = null
  mail.convertMsg = null
})

describe('CalendarStore', () => {
  it('add posts the event and reloads', async () => {
    const fetchMock = vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve((init?.method ?? 'GET') === 'POST' ? EV() : { events: [EV()] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new CalendarStore()
    expect(await s.add('Sync', '2026-06-27T09:00')).toBe(true)
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'POST')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toMatchObject({ summary: 'Sync' })
  })

  it('importIcs returns the imported count', async () => {
    vi.stubGlobal('fetch', vi.fn((url: string) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(url.includes('import') ? { imported: 3 } : { events: [] }) }),
    ))
    expect(await new CalendarStore().importIcs('BEGIN:VCALENDAR')).toBe(3)
  })
})

describe('MailStore convert', () => {
  it('toMemory + toTask post to the right endpoints', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ memory_id: 1 }) })
    vi.stubGlobal('fetch', fetchMock)
    const s = new MailStore()
    await s.toMemory(4)
    expect(fetchMock.mock.calls[0][0]).toContain('/emails/4/to-memory')
    expect(s.convertMsg).toContain('记忆')
    await s.toTask(4)
    const task = fetchMock.mock.calls.find((c) => String(c[0]).includes('/to-task'))
    expect(JSON.parse((task![1] as RequestInit).body as string)).toMatchObject({ schedule_kind: 'cron' })
  })
})

describe('Mail calendar segment', () => {
  it('switches to 日历 and lists events', async () => {
    vi.stubGlobal('fetch', vi.fn((url: string) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(
        url.includes('/calendar/events') ? { events: [EV({ summary: 'Standup' })] } : { accounts: [{ id: 1, name: 'P', email_addr: 'm', imap_host: 'h', has_password: true }], emails: [], providers: [] },
      ) }),
    ))
    render(Mail)
    await fireEvent.click(screen.getByRole('tab', { name: '📅 日历' }))
    expect(await screen.findByText('Standup')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '导出 .ics' })).toBeInTheDocument()
  })
})

describe('MailStore.toEvent', () => {
  it('posts the start time to the to-event endpoint', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ id: 1, summary: 'X' }) })
    vi.stubGlobal('fetch', fetchMock)
    const s = new MailStore()
    await s.toEvent(4, '2026-06-29T10:00')
    expect(fetchMock.mock.calls[0][0]).toContain('/emails/4/to-event')
    // 本地墙钟已转 UTC ISO(与日历约定一致)
    expect(JSON.parse((fetchMock.mock.calls[0][1] as RequestInit).body as string)).toEqual({
      start: new Date('2026-06-29T10:00').toISOString(),
    })
    expect(s.convertMsg).toContain('日历')
  })
})

describe('CalendarStore CalDAV', () => {
  it('syncCaldav posts per account and reports counts', async () => {
    const { calendar: cal } = await import('./calendarStore.svelte')
    cal.caldavAccounts = [{ id: 1, name: 'iCloud', url: 'u', username: 'me' }]
    const fetchMock = vi.fn((url: string) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(url.includes('/sync') ? { pulled_new: 2, pushed: 1 } : { events: [] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    await cal.syncCaldav()
    expect(fetchMock.mock.calls.some((c) => String(c[0]).includes('/accounts/1/sync'))).toBe(true)
    expect(cal.syncMsg).toContain('拉取 2')
    cal.caldavAccounts = []
    cal.syncMsg = null
  })
})
