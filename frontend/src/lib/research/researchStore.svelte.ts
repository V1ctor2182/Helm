// Deep Research store (Svelte 5 runes): kick off a research run over the WS,
// stream its progress, and render the cited report. `handle` is a pure reducer
// (unit-tested); live streaming uses an injectable global WebSocket (stubbed in
// tests), mirroring chatStore/agentStore.

export interface Claim {
  text: string
  sources: string[]
}

export interface ReportSource {
  url: string
  title?: string | null
  snippet?: string | null
}

export interface Report {
  question: string
  summary: string
  claims: Claim[]
  sources: ReportSource[]
  rounds: number
}

export interface ResearchSession {
  id: number
  question: string
  status: string
  rounds_done: number
  report: Report | null
  error: string | null
  created_at: string | null
  ended_at: string | null
  sources?: ReportSource[]
}

export interface Provider {
  id: number
  name: string
  models: string[]
}

export interface Progress {
  kind: string
  [k: string]: unknown
}

type Status = 'idle' | 'running' | 'done' | 'error'

export class ResearchStore {
  providers = $state<Provider[]>([])
  providerId = $state<number | null>(null)
  model = $state<string>('')
  sessions = $state<ResearchSession[]>([])
  current = $state<ResearchSession | null>(null)
  progress = $state<Progress[]>([])
  status = $state<Status>('idle')
  error = $state<string | null>(null)
  exportMsg = $state<string | null>(null)

  #ws: WebSocket | null = null

  async #post(path: string, body?: unknown): Promise<Record<string, unknown> | null> {
    try {
      const res = await fetch(path, {
        method: 'POST',
        headers: body ? { 'content-type': 'application/json' } : {},
        body: body ? JSON.stringify(body) : undefined,
      })
      if (!res.ok) return null
      return (await res.json()) as Record<string, unknown>
    } catch {
      return null
    }
  }

  async exportToMemory(id: number): Promise<void> {
    const r = await this.#post(`/api/research/${id}/export/memory`)
    this.exportMsg = r ? '已存入记忆(终端 agent 可经 MCP 读到)' : '存入记忆失败'
  }

  async exportToFile(id: number, path: string): Promise<void> {
    const r = await this.#post(`/api/research/${id}/export/file`, { path })
    this.exportMsg = r ? `已写入 ${r.path}` : '写入失败(文件可能已存在)'
  }

  async #json(path: string): Promise<unknown | null> {
    try {
      const res = await fetch(path)
      if (!res.ok) return null
      return await res.json()
    } catch {
      return null
    }
  }

  async loadProviders(): Promise<void> {
    const body = (await this.#json('/api/providers')) as { providers: Provider[] } | null
    if (body) {
      this.providers = body.providers
      if (this.providerId === null && body.providers.length) {
        this.selectProvider(body.providers[0].id)
      }
    }
  }

  selectProvider(id: number): void {
    this.providerId = id
    const p = this.providers.find((x) => x.id === id)
    this.model = p?.models[0] ?? ''
  }

  async loadSessions(): Promise<void> {
    const body = (await this.#json('/api/research')) as { sessions: ResearchSession[] } | null
    if (body) this.sessions = body.sessions
  }

  async openSession(id: number): Promise<void> {
    const body = (await this.#json(`/api/research/${id}`)) as ResearchSession | null
    if (body) this.current = body
  }

  start(question: string): void {
    if (this.status === 'running' || !question.trim() || this.providerId === null) return
    this.progress = []
    this.error = null
    this.current = null
    this.status = 'running'

    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = new WebSocket(`${proto}://${location.host}/api/research/ws`)
    ws.onopen = () =>
      ws.send(
        JSON.stringify({ provider_id: this.providerId, model: this.model, question }),
      )
    ws.onmessage = (e: MessageEvent) => this.handle(JSON.parse(e.data as string))
    ws.onclose = () => {
      if (this.#ws === ws && this.status === 'running') this.status = 'done'
    }
    this.#ws = ws
  }

  /** Reduce one server WS message into state. */
  handle(msg: { type: string; [k: string]: unknown }): void {
    if (msg.type === 'started') {
      // session id arrives; report is loaded on done
    } else if (msg.type === 'progress') {
      this.progress = [...this.progress, msg as unknown as Progress]
    } else if (msg.type === 'done') {
      this.status = 'done'
      if (typeof msg.session_id === 'number') void this.openSession(msg.session_id)
      void this.loadSessions()
    } else if (msg.type === 'error') {
      this.status = 'error'
      this.error = (msg.error as string) ?? '研究出错'
    }
  }

  stop(): void {
    if (this.#ws && this.#ws.readyState === WebSocket.OPEN) {
      this.#ws.send(JSON.stringify({ type: 'stop' }))
    }
  }
}

export const research = new ResearchStore()
