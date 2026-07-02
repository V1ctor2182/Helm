// Scheduled-tasks store (journal-notes-tasks m5). CRUD over /api/tasks; firing
// happens server-side at due time (the scheduler), so this is list/create/
// toggle/delete only.

import { jsonFetch, jsonList } from '../api'

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

export interface TaskRun {
  id: number
  task_id: number
  status: string
  output: string | null
  started_at: string | null
  ended_at: string | null
}

export class TasksStore {
  tasks = $state<Task[]>([])
  error = $state<string | null>(null)
  // 展开查看某任务的运行历史(task_runs);runsFor=null 表示未展开。
  runsFor = $state<number | null>(null)
  runs = $state<TaskRun[]>([])
  runsLoading = $state(false)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    return jsonFetch(path, init)
  }

  async load(): Promise<void> {
    const xs = await jsonList<Task>('/api/tasks', 'tasks')
    if (xs) this.tasks = xs
  }

  async create(name: string, prompt: string, kind: string, value: Record<string, unknown>): Promise<boolean> {
    if (!prompt.trim()) return false
    this.error = null
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
    if (this.runsFor === id) this.runsFor = null
  }

  /** Toggle the runs-history drawer for a task (loads on expand). */
  async toggleRuns(id: number): Promise<void> {
    if (this.runsFor === id) {
      this.runsFor = null
      return
    }
    this.runsFor = id
    this.runs = []
    this.runsLoading = true
    try {
      const xs = await jsonList<TaskRun>(`/api/tasks/${id}/runs`, 'runs')
      if (xs) this.runs = xs
    } finally {
      this.runsLoading = false
    }
  }
}

export const tasks = new TasksStore()
