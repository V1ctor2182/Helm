// 多模型对比(intent 4501c6dd):同一 prompt 并行发给多个模型,每条 lane 一个
// 真实 chat 会话 + 独立 WS 流;盲测模式先隐藏模型名,揭晓后展示。
// 复用既有后端(POST /api/sessions + /api/chat/ws),零后端改动。

import { jsonFetch } from '../api'

export interface Lane {
  key: number
  providerId: number
  providerName: string
  model: string
  sessionId: number | null
  content: string
  streaming: boolean
  error: string | null
}

export class CompareStore {
  lanes = $state<Lane[]>([])
  prompt = $state('')
  blind = $state(false)
  revealed = $state(false)
  error = $state<string | null>(null)

  #sockets = new Map<number, WebSocket>()

  readonly running = $derived(this.lanes.some((l) => l.streaming))

  #patch(key: number, patch: Partial<Lane>): void {
    this.lanes = this.lanes.map((l) => (l.key === key ? { ...l, ...patch } : l))
  }

  /** 并行开跑:每条 lane 建一个真实会话并各自流式。 */
  async run(
    pairs: { providerId: number; providerName: string; model: string }[],
    prompt: string,
    blind: boolean,
  ): Promise<void> {
    const text = prompt.trim()
    if (!text || pairs.length < 2 || this.running) return
    this.disconnect()
    this.error = null
    this.blind = blind
    this.revealed = false
    this.prompt = text
    this.lanes = pairs.map((p, i) => ({
      key: i,
      providerId: p.providerId,
      providerName: p.providerName,
      model: p.model,
      sessionId: null,
      content: '',
      streaming: true,
      error: null,
    }))
    await Promise.all(this.lanes.map((l) => this.#startLane(l.key, text)))
  }

  async #startLane(key: number, text: string): Promise<void> {
    const lane = this.lanes.find((l) => l.key === key)
    if (!lane) return
    const s = (await jsonFetch('/api/sessions', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        provider_id: lane.providerId,
        model: lane.model,
        title: `对比 · ${text.slice(0, 24)}`,
      }),
    })) as { id: number } | null
    if (!s) {
      this.#patch(key, { streaming: false, error: '创建会话失败' })
      return
    }
    this.#patch(key, { sessionId: s.id })
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = new WebSocket(`${proto}://${location.host}/api/chat/ws?session_id=${s.id}`)
    this.#sockets.set(key, ws)
    ws.onmessage = (e: MessageEvent) => {
      const m = JSON.parse(e.data as string) as
        | { type: 'delta'; text: string }
        | { type: 'done' }
        | { type: 'stopped' }
        | { type: 'error'; error: string }
      const cur = this.lanes.find((l) => l.key === key)
      if (!cur) return
      if (m.type === 'delta') this.#patch(key, { content: cur.content + m.text })
      else if (m.type === 'done' || m.type === 'stopped') this.#patch(key, { streaming: false })
      else if (m.type === 'error') this.#patch(key, { streaming: false, error: m.error })
    }
    ws.onclose = () => {
      const cur = this.lanes.find((l) => l.key === key)
      if (cur?.streaming) this.#patch(key, { streaming: false })
    }
    ws.onerror = () => {
      const cur = this.lanes.find((l) => l.key === key)
      if (cur?.streaming) this.#patch(key, { streaming: false, error: '连接失败(WS)' })
    }
    const frame = JSON.stringify({ type: 'message', content: text })
    if (ws.readyState === WebSocket.OPEN) ws.send(frame)
    else ws.addEventListener('open', () => ws.send(frame), { once: true })
  }

  stopAll(): void {
    for (const ws of this.#sockets.values()) {
      if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: 'stop' }))
    }
  }

  reveal(): void {
    this.revealed = true
  }

  /** 盲测下 lane 的展示名:揭晓前只给 模型 A/B/C。 */
  label(l: Lane): string {
    if (!this.blind || this.revealed) return `${l.providerName} · ${l.model}`
    return `模型 ${String.fromCharCode(65 + l.key)}`
  }

  disconnect(): void {
    for (const ws of this.#sockets.values()) ws.close()
    this.#sockets.clear()
  }
}

export const compare = new CompareStore()
