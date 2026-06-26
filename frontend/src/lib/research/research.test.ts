import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ResearchStore } from './researchStore.svelte'

class FakeWS {
  static instances: FakeWS[] = []
  static OPEN = 1
  readyState = 1
  url: string
  sent: string[] = []
  onopen: (() => void) | null = null
  onmessage: ((e: { data: string }) => void) | null = null
  onclose: (() => void) | null = null
  constructor(url: string) {
    this.url = url
    FakeWS.instances.push(this)
  }
  send(d: string) {
    this.sent.push(d)
  }
  close() {
    this.onclose?.()
  }
}

beforeEach(() => {
  FakeWS.instances = []
  vi.stubGlobal('WebSocket', FakeWS)
  vi.stubGlobal('location', { protocol: 'http:', host: '127.0.0.1:8769' })
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ sessions: [], providers: [] }) }))
})
afterEach(() => vi.restoreAllMocks())

describe('ResearchStore', () => {
  it('loadProviders defaults provider + model', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ providers: [{ id: 2, name: 'Claude', models: ['opus', 'sonnet'] }] }) }))
    const s = new ResearchStore()
    await s.loadProviders()
    expect(s.providerId).toBe(2)
    expect(s.model).toBe('opus')
  })

  it('start opens a WS and sends provider/model/question on open', () => {
    const s = new ResearchStore()
    s.providers = [{ id: 1, name: 'O', models: ['m'] }]
    s.selectProvider(1)
    s.start('is X better?')
    expect(s.status).toBe('running')
    const ws = FakeWS.instances[0]
    ws.onopen?.()
    expect(JSON.parse(ws.sent[0])).toEqual({ provider_id: 1, model: 'm', question: 'is X better?' })
  })

  it('refuses to start without a provider or question', () => {
    const s = new ResearchStore()
    s.start('q') // no provider
    expect(s.status).toBe('idle')
    s.providers = [{ id: 1, name: 'O', models: ['m'] }]
    s.selectProvider(1)
    s.start('  ') // blank
    expect(s.status).toBe('idle')
  })

  it('handle accumulates progress and finishes on done', () => {
    const s = new ResearchStore()
    s.status = 'running'
    s.handle({ type: 'progress', kind: 'round_start', round: 1 })
    s.handle({ type: 'progress', kind: 'source', url: 'https://x.com' })
    expect(s.progress).toHaveLength(2)
    s.handle({ type: 'done', session_id: 5, status: 'completed' })
    expect(s.status).toBe('done')
  })

  it('handle surfaces errors', () => {
    const s = new ResearchStore()
    s.handle({ type: 'error', error: 'provider 9 not found' })
    expect(s.status).toBe('error')
    expect(s.error).toContain('not found')
  })

  it('exportToMemory posts and sets a success message', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ memory_id: 3 }) })
    vi.stubGlobal('fetch', fetchMock)
    const s = new ResearchStore()
    await s.exportToMemory(7)
    expect(fetchMock.mock.calls[0][0]).toBe('/api/research/7/export/memory')
    expect((fetchMock.mock.calls[0][1] as RequestInit).method).toBe('POST')
    expect(s.exportMsg).toContain('记忆')
  })

  it('exportToFile reports the failure when overwrite refused', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, json: () => Promise.resolve({}) }))
    const s = new ResearchStore()
    await s.exportToFile(7, '/p/r.md')
    expect(s.exportMsg).toContain('失败')
  })

  it('stop sends a stop frame when open', () => {
    const s = new ResearchStore()
    s.providers = [{ id: 1, name: 'O', models: ['m'] }]
    s.selectProvider(1)
    s.start('q')
    FakeWS.instances[0].onopen?.()
    s.stop()
    expect(JSON.parse(FakeWS.instances[0].sent.at(-1)!)).toEqual({ type: 'stop' })
  })
})
