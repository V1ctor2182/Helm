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
  }

  select(entry: Entry): void {
    if (entry.is_dir) {
      void this.browse(entry.path)
    } else {
      this.selected = entry
    }
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
