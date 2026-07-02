// Cockpit store: browse the local FS via the m1 backend, track the current
// directory / project, and register known projects into the ⌘K palette so
// they're fuzzy-findable (the command-registry seam from workspace-layout m3).

import { commands } from '../commands.svelte'
import { layout } from '../layout.svelte'
import { isNoisyChange } from './watchFilter'
import { termStatus } from './terminal/termStatus.svelte'

export interface Entry {
  name: string
  path: string
  is_dir: boolean
  size: number
  ext: string
  mtime?: number
}

export interface Project {
  path: string
  name: string
  badges: string[]
  last_opened: string | null
}

export class CockpitStore {
  constructor() {
    try {
      const v = localStorage.getItem('helm-ck-view')
      if (v === 'list' || v === 'grid') this.viewMode = v
      const g = localStorage.getItem('helm-ck-gridsize')
      if (g === 'sm' || g === 'md' || g === 'lg') this.gridSize = g
      const k = localStorage.getItem('helm-ck-sort')
      if (k === 'name' || k === 'mtime' || k === 'size') this.sortKey = k
      this.showHidden = localStorage.getItem('helm-ck-hidden') === '1'
    } catch {
      /* jsdom */
    }
  }

  #savePref(key: string, val: string): void {
    try {
      localStorage.setItem(key, val)
    } catch {
      /* jsdom */
    }
  }

  setViewMode(v: 'grid' | 'list'): void {
    this.viewMode = v
    this.#savePref('helm-ck-view', v)
  }

  setGridSize(g: 'sm' | 'md' | 'lg'): void {
    this.gridSize = g
    this.#savePref('helm-ck-gridsize', g)
  }

  setSortKey(k: 'name' | 'mtime' | 'size'): void {
    this.sortKey = k
    this.#savePref('helm-ck-sort', k)
  }

  async toggleHidden(): Promise<void> {
    this.showHidden = !this.showHidden
    this.#savePref('helm-ck-hidden', this.showHidden ? '1' : '0')
    if (this.cwd) await this.browse(this.cwd)
  }

  cwd = $state<string | null>(null)
  entries = $state<Entry[]>([])
  projects = $state<Project[]>([])
  selected = $state<Entry | null>(null)
  // 视图偏好(承 FanBox:双视图/三档网格/排序/隐藏开关,localStorage 持久化)
  viewMode = $state<'grid' | 'list'>('grid')
  gridSize = $state<'sm' | 'md' | 'lg'>('md')
  sortKey = $state<'name' | 'mtime' | 'size'>('name')
  showHidden = $state(false)
  /** 右侧面板 tab:preview 随选中出现;agent 可无选中固定打开。 */
  rightTab = $state<'preview' | 'agent'>('preview')
  /** 图片灯箱(null=关);点预览图/双击网格图片打开。 */
  lightboxPath = $state<string | null>(null)
  // 「改·N」热度:变更按 cwd 顶层项聚合(count+子路径),4.5s 无新事件消退
  changeHeat = $state<Record<string, { count: number; files: string[] }>>({})
  // 变更收件箱:本会话去重计数、最新置顶、封顶 100
  inbox = $state<{ path: string; name: string; count: number; ts: number }[]>([])
  /** 跟随中同一文件继续写 → 只刷视图(PreviewPane 监听此信号)。 */
  followTick = $state(0)
  /** 编辑器有未保存改动时跟随不抢屏(PreviewPane 同步)。 */
  editorBusy = false
  error = $state<string | null>(null)
  changedPaths = $state<Set<string>>(new Set())
  followMode = $state(false)

  #watchWs: WebSocket | null = null
  #flashTimers = new Map<string, ReturnType<typeof setTimeout>>()

  async browse(path: string): Promise<void> {
    try {
      const res = await fetch(`/api/cockpit/files?path=${encodeURIComponent(path)}${this.showHidden ? '&hidden=true' : ''}`)
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
    this.manualTakeover()
    if (entry.is_dir) {
      void this.browse(entry.path)
    } else {
      this.selected = entry
    }
  }

  toggleFollow(): void {
    this.followMode = !this.followMode
    if (this.followMode) {
      // 开启即回溯:跟上 5 分钟内最近一笔变更,不干等下一笔(承 FanBox)
      const recent = this.inbox[0]
      if (recent && Date.now() - recent.ts < 300_000) this.#followSwitch(recent.path)
    }
  }

  #heatTimers = new Map<string, ReturnType<typeof setTimeout>>()

  /** 变更归到 cwd 顶层项:计数+热度+子路径 tooltip,4.5s 无新事件消退(承 FanBox 改·N)。 */
  #rollupHeat(path: string): void {
    const cwd = this.cwd
    if (!cwd || !path.startsWith(cwd + '/')) return
    const rel = path.slice(cwd.length + 1)
    const top = cwd + '/' + rel.split('/')[0]
    const cur = this.changeHeat[top] ?? { count: 0, files: [] }
    const files = cur.files.includes(rel) ? cur.files : [...cur.files.slice(-9), rel]
    this.changeHeat = { ...this.changeHeat, [top]: { count: cur.count + 1, files } }
    const prev = this.#heatTimers.get(top)
    if (prev) clearTimeout(prev)
    this.#heatTimers.set(
      top,
      setTimeout(() => {
        const next = { ...this.changeHeat }
        delete next[top]
        this.changeHeat = next
        this.#heatTimers.delete(top)
      }, 4500),
    )
  }

  #pushInbox(path: string): void {
    const name = path.split('/').pop() ?? path
    const hit = this.inbox.find((i) => i.path === path)
    const rest = this.inbox.filter((i) => i.path !== path)
    this.inbox = [{ path, name, count: (hit?.count ?? 0) + 1, ts: Date.now() }, ...rest].slice(0, 100)
  }

  clearInbox(): void {
    this.inbox = []
  }

  // Live dashboard: flash a card briefly when its file changes.
  markChanged(path: string): void {
    this.#rollupHeat(path)
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

  // ── 文件操作(承 FanBox:新建/重命名/废纸篓,错误透出 server detail) ────
  async #fsPost(path: string, body: unknown): Promise<string | null> {
    try {
      const res = await fetch(path, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (!res.ok) {
        const d = (await res.json().catch(() => null)) as { detail?: string } | null
        this.error = d?.detail ?? '操作失败'
        return null
      }
      this.error = null
      const j = (await res.json()) as { path?: string }
      return j.path ?? ''
    } catch {
      this.error = '操作失败(网络)'
      return null
    }
  }

  async mkdir(name: string): Promise<boolean> {
    if (!this.cwd) return false
    const p = await this.#fsPost('/api/cockpit/fs/mkdir', { dir: this.cwd, name })
    if (p !== null) await this.browse(this.cwd)
    return p !== null
  }

  /** 新建文件并立即选中(空文本→预览即编辑,承 FanBox「新建即编辑」)。 */
  async newFile(name: string): Promise<boolean> {
    if (!this.cwd) return false
    const p = await this.#fsPost('/api/cockpit/fs/newfile', { dir: this.cwd, name })
    if (p === null) return false
    await this.browse(this.cwd)
    const entry = this.entries.find((e) => e.path === p)
    if (entry) this.select(entry)
    return true
  }

  async renameEntry(path: string, name: string): Promise<boolean> {
    const p = await this.#fsPost('/api/cockpit/fs/rename', { path, name })
    if (p !== null && this.cwd) await this.browse(this.cwd)
    if (this.selected?.path === path) this.selected = null
    return p !== null
  }

  async trash(path: string): Promise<boolean> {
    const p = await this.#fsPost('/api/cockpit/fs/trash', { path })
    if (p !== null && this.cwd) await this.browse(this.cwd)
    if (this.selected?.path === path) this.selected = null
    return p !== null
  }

  /** 双击 pdf/压缩包/二进制 → 系统默认 App。 */
  async openWithSystem(path: string): Promise<void> {
    await this.#fsPost('/api/cockpit/fs/open', { path })
  }

  /** 终端路径点击的落点:目录→浏览进去;文件→浏览其目录+选中预览。 */
  openPath(path: string, isDir: boolean): void {
    this.manualTakeover()
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
  #followPending: string | null = null
  #followTimer: ReturnType<typeof setTimeout> | null = null

  /** 归属判定(单终端版,承 FanBox boundAgentActive):agent 正忙或 8s 内有输出。 */
  #agentActive(): boolean {
    return termStatus.status === 'busy' || Date.now() - termStatus.lastData < 8000
  }

  // 看头优先级:html/md「写给人看的」> 代码 > 其它(承 FanBox followPrio)
  #followPrio(p: string): number {
    const ext = (p.split('.').pop() ?? '').toLowerCase()
    if (['md', 'markdown', 'html', 'htm'].includes(ext)) return 3
    if (['ts', 'tsx', 'js', 'jsx', 'py', 'rs', 'go', 'swift', 'svelte', 'css', 'json', 'yaml', 'yml', 'sh', 'c', 'h', 'cpp', 'java', 'rb', 'sql', 'toml', 'txt', 'log'].includes(ext)) return 2
    return 1
  }

  /** 变更进跟随:同文件→刷视图;换文件→节流切目标(定时器只设一次,到点取最新;
   *  低优先级不顶掉已排队的高优先级;首切 120ms 之后 900ms 稳节奏)。 */
  #followChange(full: string): void {
    if (full === this.selected?.path) {
      this.followTick++
      return
    }
    if (this.editorBusy) return // 编辑器开着不抢屏,等用户收工
    if (this.#followTimer && this.#followPending && this.#followPrio(this.#followPending) > this.#followPrio(full)) return
    this.#followPending = full
    if (!this.#followTimer) {
      const wait = this.selected ? 900 : 120
      this.#followTimer = setTimeout(() => {
        this.#followTimer = null
        const p = this.#followPending
        this.#followPending = null
        if (p && this.followMode) this.#followSwitch(p)
      }, wait)
    }
  }

  #followSwitch(path: string): void {
    const name = path.split('/').pop() ?? path
    const dot = name.lastIndexOf('.')
    const ext = dot > 0 ? name.slice(dot + 1).toLowerCase() : ''
    const dir = path.slice(0, path.lastIndexOf('/'))
    if (dir && dir !== this.cwd) void this.browse(dir)
    this.selected = { name, path, is_dir: false, size: 0, ext }
  }

  /** 手动接管即停(承 FanBox):导航/点文件/编辑任一动作关掉跟随。 */
  manualTakeover(): void {
    if (this.followMode) this.followMode = false
  }

  applyChange(ev: { path: string; kind: string }): void {
    // 噪声过滤(高亮/收件箱/跟随共用):相对 cwd 判,不在 cwd 下按全路径判
    const rel = this.cwd && ev.path.startsWith(this.cwd + '/') ? ev.path.slice(this.cwd.length + 1) : ev.path
    if (isNoisyChange(rel)) return
    this.markChanged(ev.path)
    this.#pushInbox(ev.path)
    if (this.followMode && ev.kind !== 'deleted') {
      // 归属双判定:在监听范围内(startWatching 已限 cwd)+ 绑定 agent 此刻在干活
      if (!this.#agentActive()) return
      this.#followChange(ev.path)
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
