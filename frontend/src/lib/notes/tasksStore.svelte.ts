// Scheduled-tasks store (journal-notes-tasks m5). CRUD over /api/tasks; firing
// happens server-side at due time (the scheduler), so this is list/create/
// toggle/delete only.

export interface Task {
  id: number
  name: string
  prompt: string
  schedule_kind: string
  schedule_value: Record<string, unknown>
  execution_mode: string
  enabled: boolean
  next_run: string | null
  last_status: string | null
  run_count: number
  linked_note_id: number | null
}

export class TasksStore {
  tasks = $state<Task[]>([])
  error = $state<string | null>(null)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    try {
      const res = await fetch(path, init)
      if (!res.ok) return null
      return await res.json()
    } catch {
      return null
    }
  }

  async load(): Promise<void> {
    const body = (await this.#json('/api/tasks')) as { tasks: Task[] } | null
    if (body) this.tasks = body.tasks
  }

  async create(name: string, prompt: string, kind: string, value: Record<string, unknown>): Promise<boolean> {
    if (!prompt.trim()) return false
    const ok = await this.#json('/api/tasks', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: name || prompt.slice(0, 30), prompt, schedule_kind: kind, schedule_value: value }),
    })
    if (ok) await this.load()
    else this.error = '创建任务失败(检查 schedule)'
    return ok !== null
  }

  async toggle(t: Task): Promise<void> {
    const ok = await this.#json(`/api/tasks/${t.id}/enabled`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ enabled: !t.enabled }),
    })
    if (ok) await this.load()
  }

  async remove(id: number): Promise<void> {
    const ok = await this.#json(`/api/tasks/${id}`, { method: 'DELETE' })
    if (ok) await this.load()
  }
}

export const tasks = new TasksStore()
