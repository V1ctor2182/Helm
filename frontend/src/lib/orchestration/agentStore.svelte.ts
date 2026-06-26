// Agent store (Svelte 5 runes): drives a Claude Code run over the ACP WS and
// accumulates its structured events for the cockpit to observe. The message
// reducer (`handle`) is split out so it's unit-testable; live streaming uses an
// injectable global WebSocket (stubbed in tests), mirroring chatStore.

import { jsonFetch } from '../api'
import { cockpit } from '../cockpit/cockpit.svelte'

export interface AcpEvent {
  type: string // status | message | tool_call | tool_result | session_end | plan | permission_request
  session_id: string | null
  data: Record<string, unknown>
  ts: number
}

export interface AgentRun {
  id: number
  agent: string
  status: string
  prompt: string | null
  project_path: string | null
  started_at: string | null
  ended_at: string | null
}

type RunStatus = 'idle' | 'running' | 'done' | 'error'

const CONTROL = new Set(['run_started', 'done', 'error'])

export class AgentStore {
  events = $state<AcpEvent[]>([])
  runId = $state<number | null>(null)
  status = $state<RunStatus>('idle')
  error = $state<string | null>(null)
  runs = $state<AgentRun[]>([])

  #ws: WebSocket | null = null

  async #json(path: string): Promise<unknown | null> {
    return jsonFetch(path)
  }

  async loadRuns(): Promise<void> {
    const body = (await this.#json('/api/orchestration/runs')) as { runs: AgentRun[] } | null
    if (body) this.runs = body.runs
  }

  start(prompt: string, cwd: string | null = null, agent = 'claude-code'): void {
    if (this.status === 'running' || !prompt.trim()) return
    this.events = []
    this.error = null
    this.runId = null
    this.status = 'running'

    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = new WebSocket(`${proto}://${location.host}/api/orchestration/runs/ws`)
    ws.onopen = () => ws.send(JSON.stringify({ agent, prompt, cwd }))
    ws.onmessage = (e: MessageEvent) => this.handle(JSON.parse(e.data as string))
    ws.onclose = () => {
      if (this.#ws === ws && this.status === 'running') this.status = 'done'
    }
    this.#ws = ws
  }

  /** Reduce one server message (control frame or ACP event) into state. */
  handle(msg: { type: string; [k: string]: unknown }): void {
    if (msg.type === 'run_started') {
      this.runId = msg.run_id as number
    } else if (msg.type === 'done') {
      this.status = 'done'
      void this.loadRuns()
    } else if (msg.type === 'error') {
      this.status = 'error'
      this.error = (msg.error as string) ?? '运行出错'
    } else if (!CONTROL.has(msg.type)) {
      const event = msg as unknown as AcpEvent
      this.events = [...this.events, event]
      // Link agent tool calls to the cockpit: when the agent edits/writes a
      // file, flash it in the file browser (decision bf5dc16b; ticket f4987eed).
      if (event.type === 'tool_call') this.#flashToolFile(event)
    }
  }

  #flashToolFile(event: AcpEvent): void {
    const input = event.data?.input as Record<string, unknown> | undefined
    const path = (input?.file_path ?? input?.path) as string | undefined
    if (path) cockpit.markChanged(path)
  }

  stop(): void {
    this.#ws?.close()
    this.#ws = null
  }
}

export const agent = new AgentStore()
