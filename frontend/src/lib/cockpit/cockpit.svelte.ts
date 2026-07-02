// Cockpit store: browse the local FS via the m1 backend, track the current
// directory / project, and register known projects into the ⌘K palette so
// they're fuzzy-findable (the command-registry seam from workspace-layout m3).

import { commands } from '../commands.svelte'
import { layout } from '../layout.svelte'

export interface Entry {
  name: string
  path: string
  is_dir: boolean
  size: number
  ext: string
}

export interface Project {
  path: string
  name: string
  badges: string[]
  last_opened: string | null
}

export class CockpitStore {
  cwd = $state<string | null>(null)
  entries = $state<Entry[]>([])
  projects = $state<Project[]>([])
  selected = $state<Entry | null>(null)
  error = $state<string | null>(null)
  changedPaths = $state<Set<string>>(new Set())
  followMode = $state(false)

  #watchWs: WebSocket | null = null
  #flashTimers = new Map<string, ReturnType<typeof setTimeout>>()

  async browse(path: string): Promise<void> {
    try {
      const res = await fetch(`/api/cockpit/files?path=${encodeURIComponent(path)}`)
      if (!res.ok) {
        this.error = '无法打开该目录'
        return
      }
      const body = await res.json()
      this.cwd = body.path
      this.entries = body.entries
      this.error = null
    } catch {
      this.error = '网络错误'
    }
  }

  async loadProjects(): Promise<void> {
    try {
      const res = await fetch('/api/cockpit/projects')
      if (res.ok) {
        this.projects = (await res.json()).projects
        this.#registerProjectCommands()
      }
    } catch {
      this.error = '网络错误'
    }
  }

  async openProject(path: string): Promise<void> {
    const res = await fetch('/api/cockpit/projects', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ path }),
    })
    if (!res.ok) {
      this.error = '无法打开项目'
      return
    }
    const project: Project = await res.json()
    await this.loadProjects()
    layout.setMode('cockpit')
    await this.browse(project.path)
    this.startWatching(project.path)
  }

  select(entry: Entry): void {
    if (entry.is_dir) {
      void this.browse(entry.path)
    } else {
      this.selected = entry
    }
  }

  toggleFollow(): void {
    this.followMode = !this.followMode
  }

  // Live dashboard: flash a card briefly when its file changes.
  markChanged(path: string): void {
    const next = new Set(this.changedPaths)
    next.add(path)
    this.changedPaths = next
    // Re-arm rather than stack timers on rapid re-changes to the same path.
    const prev = this.#flashTimers.get(path)
    if (prev) clearTimeout(prev)
    this.#flashTimers.set(
      path,
      setTimeout(() => {
        const after = new Set(this.changedPaths)
        after.delete(path)
        this.changedPaths = after
        this.#flashTimers.delete(path)
      }, 1500),
    )
  }

  /** 终端路径点击的落点:目录→浏览进去;文件→浏览其目录+选中预览。 */
  openPath(path: string, isDir: boolean): void {
    if (isDir) {
      void this.browse(path)
      return
    }
    const name = path.split('/').pop() ?? path
    const dot = name.lastIndexOf('.')
    const ext = dot > 0 ? name.slice(dot + 1).toLowerCase() : ''
    const dir = path.slice(0, path.lastIndexOf('/'))
    if (dir && dir !== this.cwd) void this.browse(dir)
    this.selected = { name, path, is_dir: false, size: 0, ext }
  }

  // Apply a watch event: always flash; in follow mode also track the file
  // (browse to its dir if needed + preview it).
  applyChange(ev: { path: string; kind: string }): void {
    this.markChanged(ev.path)
    if (this.followMode && ev.kind !== 'deleted') {
      const name = ev.path.split('/').pop() ?? ev.path
      const dot = name.lastIndexOf('.')
      const ext = dot > 0 ? name.slice(dot + 1).toLowerCase() : ''
      const dir = ev.path.slice(0, ev.path.lastIndexOf('/'))
      if (dir && dir !== this.cwd) void this.browse(dir)
      this.selected = { name, path: ev.path, is_dir: false, size: 0, ext }
    }
  }

  startWatching(path: string): void {
    this.stopWatching()
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const url = `${proto}://${location.host}/api/cockpit/watch/ws?path=${encodeURIComponent(path)}`
    const ws = new WebSocket(url)
    ws.onmessage = (e) => {
      try {
        const m = JSON.parse(e.data as string)
        if (m.type === 'change') this.applyChange(m)
      } catch {
        /* ignore malformed frame */
      }
    }
    this.#watchWs = ws
  }

  stopWatching(): void {
    this.#watchWs?.close()
    this.#watchWs = null
  }

  #registerProjectCommands(): void {
    for (const p of this.projects) {
      commands.register({
        id: `cockpit.project.${p.path}`,
        title: `项目：${p.name}`,
        group: 'Projects',
        keywords: p.path,
        run: () => void this.openProject(p.path),
      })
    }
  }
}

export const cockpit = new CockpitStore()
