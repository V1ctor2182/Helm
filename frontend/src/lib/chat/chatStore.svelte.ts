// Chat store: providers, sessions, the active conversation, and the streaming
// WebSocket. Server-message handling (`handle`) is split out so it's unit-
// testable; live streaming is exercised via an injectable global WebSocket.

import { jsonFetch, jsonList } from '../api'

export interface Provider {
  id: number
  type: string
  name: string
  base_url: string
  models: string[]
  has_key: boolean
}

export interface Template {
  type: string
  name: string
  base_url: string
  needs_key: boolean
  models: string[]
  default?: boolean
}

export interface ChatSessionT {
  id: number
  title: string | null
  provider_id: number
  model: string
  system_prompt: string | null
}

export interface Msg {
  role: string
  content: string
}

type ServerMsg =
  | { type: 'delta'; text: string }
  | { type: 'done' }
  | { type: 'stopped' }
  | { type: 'error'; error: string }

export class ChatStore {
  providers = $state<Provider[]>([])
  templates = $state<Template[]>([])
  sessions = $state<ChatSessionT[]>([])
  current = $state<ChatSessionT | null>(null)
  messages = $state<Msg[]>([])
  streaming = $state(false)
  error = $state<string | null>(null)

  #ws: WebSocket | null = null

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    return jsonFetch(path, init)
  }

  async loadTemplates(): Promise<void> {
    const xs = await jsonList<Template>('/api/providers/templates', 'templates')
    if (xs) this.templates = xs
  }

  async loadProviders(): Promise<void> {
    const xs = await jsonList<Provider>('/api/providers', 'providers')
    if (xs) this.providers = xs
  }

  async addProvider(p: {
    type: string
    name: string
    base_url: string
    api_key?: string
    models?: string[]
  }): Promise<Provider | null> {
    const created = (await this.#json('/api/providers', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(p),
    })) as Provider | null
    if (!created) {
      this.error = '添加 provider 失败'
      return null
    }
    await this.loadProviders()
    return created
  }

  async testProvider(id: number): Promise<{ ok: boolean; models?: string[]; error?: string }> {
    const body = await this.#json(`/api/providers/${id}/test`, { method: 'POST' })
    return (body as { ok: boolean } | null) ?? { ok: false, error: '请求失败' }
  }

  async loadSessions(): Promise<void> {
    const xs = await jsonList<ChatSessionT>('/api/sessions', 'sessions')
    if (xs) this.sessions = xs
  }

  async createSession(
    providerId: number,
    model: string,
    systemPrompt: string | null = null,
  ): Promise<ChatSessionT | null> {
    const s = (await this.#json('/api/sessions', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ provider_id: providerId, model, system_prompt: systemPrompt }),
    })) as ChatSessionT | null
    if (!s) {
      this.error = '创建会话失败'
      return null
    }
    await this.loadSessions()
    await this.openSession(s.id)
    return s
  }

  async openSession(id: number): Promise<void> {
    const body = (await this.#json(`/api/sessions/${id}`)) as
      | { session: ChatSessionT; messages: Msg[] }
      | null
    if (!body) {
      this.error = '打开会话失败'
      return
    }
    this.current = body.session
    this.messages = body.messages
    this.error = null
    this.streaming = false // a prior session's stream can't deliver here
    this.#connect(id)
  }

  #connect(id: number): void {
    this.#ws?.close()
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = new WebSocket(`${proto}://${location.host}/api/chat/ws?session_id=${id}`)
    ws.onmessage = (e: MessageEvent) => this.handle(JSON.parse(e.data as string))
    // If the socket drops without a terminal frame, don't strand the composer.
    ws.onclose = () => {
      if (this.#ws === ws) this.streaming = false
    }
    this.#ws = ws
  }

  send(content: string): void {
    const text = content.trim()
    if (!text || !this.current || this.streaming) return
    // optimistic: user turn + empty assistant placeholder that deltas fill
    this.messages = [...this.messages, { role: 'user', content: text }, { role: 'assistant', content: '' }]
    this.streaming = true
    const frame = JSON.stringify({ type: 'message', content: text })
    const ws = this.#ws
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(frame)
    } else if (ws) {
      ws.addEventListener('open', () => ws.send(frame), { once: true })
    }
  }

  stop(): void {
    if (this.#ws && this.#ws.readyState === WebSocket.OPEN) {
      this.#ws.send(JSON.stringify({ type: 'stop' }))
    }
  }

  handle(m: ServerMsg): void {
    if (m.type === 'delta') {
      const last = this.messages.at(-1)
      if (last && last.role === 'assistant') {
        this.messages = [...this.messages.slice(0, -1), { ...last, content: last.content + m.text }]
      }
    } else if (m.type === 'done' || m.type === 'stopped') {
      this.streaming = false
    } else if (m.type === 'error') {
      this.streaming = false
      this.error = m.error
    }
  }

  disconnect(): void {
    this.#ws?.close()
    this.#ws = null
  }
}

export const chat = new ChatStore()
