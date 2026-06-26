import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { MailStore } from './mailStore.svelte'
import Mail from './Mail.svelte'
import { mail } from './mailStore.svelte'

const E = (over: Record<string, unknown> = {}) => ({
  id: 1, account_id: 1, uid: '1', from_addr: 'a@x.com', subject: 'Hi',
  snippet: 's', unread: true, labels: [], triage: null, date: null, ...over,
})

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ accounts: [], emails: [], providers: [] }) }))
})
afterEach(() => {
  vi.restoreAllMocks()
  mail.accounts = []
  mail.emails = []
  mail.current = null
  mail.providers = []
  mail.error = null
})

describe('MailStore', () => {
  it('sync posts per account then reloads emails', async () => {
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(url.includes('/emails') ? { emails: [E()] } : { new: 1 }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new MailStore()
    s.accounts = [{ id: 7, name: 'P', email_addr: 'm@x', imap_host: 'h', has_password: true }]
    await s.sync()
    expect(fetchMock.mock.calls.some((c) => String(c[0]).includes('/accounts/7/sync'))).toBe(true)
    expect(s.emails).toHaveLength(1)
    expect(s.syncing).toBe(false)
  })

  it('triage posts with the first provider and updates current', async () => {
    const triage = { urgency: 'high', is_spam: false, summary: '催回复', labels: ['工作'], draft: '好的' }
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(url.includes('/triage') ? triage : { emails: [] }) }),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new MailStore()
    s.providers = [{ id: 2, name: 'Claude', models: ['opus'] }]
    s.current = E({ id: 5 })
    await s.triage(5)
    const post = fetchMock.mock.calls.find((c) => String(c[0]).includes('/triage'))
    expect(JSON.parse((post![1] as RequestInit).body as string)).toEqual({ provider_id: 2, model: 'opus' })
    expect(s.current?.triage?.summary).toBe('催回复')
  })

  it('triage errors with no provider', async () => {
    const s = new MailStore()
    s.current = E({ id: 5 })
    await s.triage(5)
    expect(s.error).toContain('provider')
  })
})

describe('Mail panel', () => {
  it('shows the add-account form when there are no accounts', async () => {
    render(Mail)
    expect(await screen.findByLabelText('IMAP 主机')).toBeInTheDocument()
  })

  it('lists inbox emails and opens detail with triage', async () => {
    vi.stubGlobal('fetch', vi.fn((url: string) =>
      Promise.resolve({ ok: true, json: () => Promise.resolve(
        url.endsWith('/emails/9')
          ? E({ id: 9, body: 'full body here', triage: { urgency: 'high', is_spam: false, summary: '催', labels: ['工作'], draft: '好的,马上' } })
          : { accounts: [{ id: 1, name: 'P', email_addr: 'm@x', imap_host: 'h', has_password: true }], emails: [E({ id: 9, subject: 'Urgent ask' })], providers: [] },
      ) }),
    ))
    render(Mail)
    const row = await screen.findByText('Urgent ask')
    await fireEvent.click(row)
    expect(await screen.findByText('full body here')).toBeInTheDocument()
    expect(screen.getByText('催')).toBeInTheDocument()
    expect(screen.getByText('好的,马上')).toBeInTheDocument()
  })
})
