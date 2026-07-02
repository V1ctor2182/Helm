import { render, screen } from '@testing-library/svelte'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import Calendar from './Calendar.svelte'
import { calendar } from '../mail/calendarStore.svelte'

const EV = (over = {}) => ({
  id: 1, uid: 'u1', summary: 'Standup', description: '', location: '',
  start: '2026-07-01T01:30:00+00:00', end: null, all_day: false, source: 'local', ...over,
})

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ events: [], accounts: [] }) }))
})
afterEach(() => {
  vi.restoreAllMocks()
  calendar.events = []
  calendar.caldavAccounts = []
  calendar.syncMsg = null
  calendar.error = null
})

describe('Calendar agenda view', () => {
  it('groups events by local day with local times and source tags', async () => {
    calendar.events = [
      EV(),
      EV({ id: 2, uid: 'u2', summary: '发布窗口', start: '2026-07-02T06:00:00+00:00', source: 'caldav' }),
      EV({ id: 3, uid: 'u3', summary: '生日', start: '2026-07-02', all_day: true }),
    ]
    render(Calendar)
    // local-day headers (times converted from UTC; all-day stays on its raw date)
    expect(screen.getByText('2026-07-02')).toBeInTheDocument()
    expect(screen.getByText('全天')).toBeInTheDocument()
    expect(screen.getByText('CALDAV')).toBeInTheDocument()
    expect(screen.getAllByText('LOCAL').length).toBe(2)
    expect(screen.getByRole('button', { name: '删除 Standup' })).toBeInTheDocument()
  })

  it('month view lays out a grid with events on their local day', async () => {
    calendar.events = [EV({ id: 5, uid: 'u5', summary: '发布会', start: '2026-07-02T06:00:00+00:00' })]
    render(Calendar)
    const { fireEvent } = await import('@testing-library/dom')
    await fireEvent.click(screen.getByRole('tab', { name: '月' }))
    expect(screen.getByText('2026-07')).toBeInTheDocument()
    expect(screen.getByText('发布会')).toBeInTheDocument()
  })

  it('shows the empty state without events', () => {
    render(Calendar)
    expect(screen.getByText(/还没有日程/)).toBeInTheDocument()
  })
})
