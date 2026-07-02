import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { CompareStore } from './compareStore.svelte'

class FakeWS {
  static instances: FakeWS[] = []
  static OPEN = 1
  url: string
  readyState = 1
  sent: string[] = []
  onmessage: ((e: { data: string }) => void) | null = null
  onclose: (() => void) | null = null
  onerror: (() => void) | null = null
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

const PAIRS = [
  { providerId: 1, providerName: 'Ollama', model: 'llama3' },
  { providerId: 1, providerName: 'Ollama', model: 'qwen' },
]

let nextId = 100

beforeEach(() => {
  FakeWS.instances = []
  nextId = 100
  vi.stubGlobal('WebSocket', FakeWS)
  vi.stubGlobal('location', { protocol: 'http:', host: '127.0.0.1:8769' })
  vi.stubGlobal(
    'fetch',
    vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ id: nextId++ }) })),
  )
})
afterEach(() => vi.restoreAllMocks())

describe('CompareStore', () => {
  it('run creates a session per lane and streams deltas into the right lane', async () => {
    const c = new CompareStore()
    await c.run(PAIRS, 'which is faster?', false)
    expect(c.lanes).toHaveLength(2)
    expect(c.lanes.map((l) => l.sessionId)).toEqual([100, 101])
    expect(FakeWS.instances).toHaveLength(2)
    // each socket got the same prompt
    for (const ws of FakeWS.instances) {
      expect(JSON.parse(ws.sent[0])).toEqual({ type: 'message', content: 'which is faster?' })
    }
    FakeWS.instances[0].emit({ type: 'delta', text: 'A says' })
    FakeWS.instances[1].emit({ type: 'delta', text: 'B says' })
    FakeWS.instances[0].emit({ type: 'done' })
    expect(c.lanes[0].content).toBe('A says')
    expect(c.lanes[1].content).toBe('B says')
    expect(c.lanes[0].streaming).toBe(false)
    expect(c.lanes[1].streaming).toBe(true)
    FakeWS.instances[1].emit({ type: 'error', error: 'boom' })
    expect(c.lanes[1].streaming).toBe(false)
    expect(c.lanes[1].error).toBe('boom')
    expect(c.running).toBe(false)
  })

  it('blind mode hides model names until reveal', async () => {
    const c = new CompareStore()
    await c.run(PAIRS, 'hi', true)
    expect(c.label(c.lanes[0])).toBe('模型 A')
    expect(c.label(c.lanes[1])).toBe('模型 B')
    c.reveal()
    expect(c.label(c.lanes[0])).toBe('Ollama · llama3')
  })

  it('refuses fewer than two lanes and while running', async () => {
    const c = new CompareStore()
    await c.run([PAIRS[0]], 'hi', false)
    expect(c.lanes).toHaveLength(0)
    await c.run(PAIRS, 'hi', false)
    const before = c.lanes
    await c.run(PAIRS, 'again', false) // still streaming → ignored
    expect(c.lanes).toBe(before)
  })
})
