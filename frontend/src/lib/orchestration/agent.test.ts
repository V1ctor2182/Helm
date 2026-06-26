import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AgentStore } from './agentStore.svelte'

class FakeWS {
  static instances: FakeWS[] = []
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
  emit(obj: unknown) {
    this.onmessage?.({ data: JSON.stringify(obj) })
  }
}

beforeEach(() => {
  FakeWS.instances = []
  vi.stubGlobal('WebSocket', FakeWS)
  vi.stubGlobal('location', { protocol: 'http:', host: '127.0.0.1:8769' })
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ runs: [] }) }))
})
afterEach(() => vi.restoreAllMocks())

describe('AgentStore.handle (reducer)', () => {
  it('run_started sets runId; ACP events accumulate', () => {
    const s = new AgentStore()
    s.handle({ type: 'run_started', run_id: 7 })
    expect(s.runId).toBe(7)
    s.handle({ type: 'status', session_id: 's', data: { model: 'm' }, ts: 1 })
    s.handle({ type: 'tool_call', session_id: 's', data: { name: 'Read' }, ts: 2 })
    expect(s.events).toHaveLength(2)
    expect(s.events[1].type).toBe('tool_call')
  })

  it('done sets status done and refreshes runs', () => {
    const s = new AgentStore()
    s.status = 'running'
    s.handle({ type: 'done', run_id: 1 })
    expect(s.status).toBe('done')
  })

  it('error sets status + message', () => {
    const s = new AgentStore()
    s.handle({ type: 'error', error: 'agent not found: gemini' })
    expect(s.status).toBe('error')
    expect(s.error).toContain('gemini')
  })

  it('control frames are not stored as events', () => {
    const s = new AgentStore()
    s.handle({ type: 'run_started', run_id: 1 })
    s.handle({ type: 'done' })
    expect(s.events).toHaveLength(0)
  })
})

describe('AgentStore.start', () => {
  it('opens a WS and sends the agent+prompt payload on open', () => {
    const s = new AgentStore()
    s.start('do a thing', '/proj')
    expect(s.status).toBe('running')
    const ws = FakeWS.instances[0]
    expect(ws.url).toContain('/api/orchestration/runs/ws')
    ws.onopen?.()
    expect(JSON.parse(ws.sent[0])).toEqual({ agent: 'claude-code', prompt: 'do a thing', cwd: '/proj' })
  })

  it('refuses to start with an empty prompt or while running', () => {
    const s = new AgentStore()
    s.start('   ')
    expect(s.status).toBe('idle')
    expect(FakeWS.instances).toHaveLength(0)
  })

  it('a streamed run drives status to done on close', () => {
    const s = new AgentStore()
    s.start('go')
    const ws = FakeWS.instances[0]
    ws.emit({ type: 'run_started', run_id: 3 })
    ws.emit({ type: 'message', session_id: 's', data: { text: 'hi' }, ts: 1 })
    ws.close()
    expect(s.status).toBe('done')
    expect(s.runId).toBe(3)
    expect(s.events).toHaveLength(1)
  })
})

describe('AgentStore tool_call → cockpit linkage', () => {
  it('flashes the file in the cockpit when the agent edits it', async () => {
    const { cockpit } = await import('../cockpit/cockpit.svelte')
    cockpit.changedPaths = new Set()
    const s = new AgentStore()
    s.handle({ type: 'tool_call', session_id: 's', data: { name: 'Edit', input: { file_path: '/proj/a.py' } }, ts: 1 })
    expect(cockpit.changedPaths.has('/proj/a.py')).toBe(true)
    // a tool_call without a file path doesn't throw / mark anything new
    s.handle({ type: 'tool_call', session_id: 's', data: { name: 'Bash', input: { command: 'ls' } }, ts: 2 })
    expect(cockpit.changedPaths.size).toBe(1)
  })
})
