import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ChatStore } from './chatStore.svelte'

class FakeWS {
  static instances: FakeWS[] = []
  static OPEN = 1
  url: string
  readyState = 1
  sent: string[] = []
  onmessage: ((e: { data: string }) => void) | null = null
  constructor(url: string) {
    this.url = url
    FakeWS.instances.push(this)
  }
  send(d: string) {
    this.sent.push(d)
  }
  close() {
    this.readyState = 3
  }
  addEventListener() {}
  emit(obj: unknown) {
    this.onmessage?.({ data: JSON.stringify(obj) })
  }
}

const ok = (body: unknown) => ({ ok: true, json: () => Promise.resolve(body) })
const SESSION = { id: 1, title: null, provider_id: 1, model: 'm', system_prompt: null }

beforeEach(() => {
  FakeWS.instances = []
  vi.stubGlobal('WebSocket', FakeWS)
  vi.stubGlobal('location', { protocol: 'http:', host: '127.0.0.1:8769' })
})
afterEach(() => vi.restoreAllMocks())

describe('ChatStore', () => {
  it('loadProviders populates providers', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        ok({ providers: [{ id: 1, type: 'ollama', name: 'O', base_url: 'u', models: [], has_key: false }] }),
      ),
    )
    const c = new ChatStore()
    await c.loadProviders()
    expect(c.providers).toHaveLength(1)
  })

  it('openSession loads messages and opens a session WS', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ session: { ...SESSION, id: 5 }, messages: [{ role: 'user', content: 'hi' }] })))
    const c = new ChatStore()
    await c.openSession(5)
    expect(c.current?.id).toBe(5)
    expect(c.messages).toHaveLength(1)
    expect(FakeWS.instances[0].url).toContain('session_id=5')
  })

  it('send streams deltas into the assistant placeholder; done ends streaming', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ session: SESSION, messages: [] })))
    const c = new ChatStore()
    await c.openSession(1)
    c.send('hello')
    expect(c.streaming).toBe(true)
    expect(c.messages).toEqual([
      { role: 'user', content: 'hello' },
      { role: 'assistant', content: '' },
    ])
    const ws = FakeWS.instances[0]
    expect(JSON.parse(ws.sent[0])).toEqual({ type: 'message', content: 'hello' })

    ws.emit({ type: 'delta', text: 'Hi' })
    ws.emit({ type: 'delta', text: ' there' })
    expect(c.messages.at(-1)).toEqual({ role: 'assistant', content: 'Hi there' })

    ws.emit({ type: 'done' })
    expect(c.streaming).toBe(false)
  })

  it('stop sends a stop frame; error surfaces and ends streaming', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ session: SESSION, messages: [] })))
    const c = new ChatStore()
    await c.openSession(1)
    c.send('x')
    const ws = FakeWS.instances[0]
    c.stop()
    expect(JSON.parse(ws.sent.at(-1) as string)).toEqual({ type: 'stop' })

    ws.emit({ type: 'error', error: 'boom' })
    expect(c.error).toBe('boom')
    expect(c.streaming).toBe(false)
  })

  it('send is a no-op while already streaming', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ session: SESSION, messages: [] })))
    const c = new ChatStore()
    await c.openSession(1)
    c.send('first')
    c.send('second')
    expect(c.messages.filter((m) => m.role === 'user')).toHaveLength(1)
  })
})
