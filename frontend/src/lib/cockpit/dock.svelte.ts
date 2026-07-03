// 驾驶舱 dock 引擎(阶段3.5 结构#4 升级版,用户拍板:全模块拖拽吸附):
// 三个 zone(main/right/bottom),模块拖标题栏换 zone,同 zone 多模块成 tab 栈。
// 模块组件常驻挂载(CSS 显隐定位,绝不重挂——xterm 的 WS/回滚缓冲不能丢),
// 这里只管"谁在哪/谁活跃/多大",渲染交给 DockHost。布局持久化 localStorage。

export type ZoneId = 'main' | 'right' | 'bottom'
export type ModuleId = 'files' | 'preview' | 'terminal' | 'agent'

export const MODULE_LABEL: Record<ModuleId, string> = {
  files: '文件 / FILES',
  preview: '预览 / PREVIEW',
  terminal: '终端 / TERMINAL',
  agent: 'AGENT',
}

export interface DockLayout {
  zones: Record<ZoneId, ModuleId[]>
  active: Record<ZoneId, ModuleId | null>
  rightW: number // px
  bottomH: number // px
  collapsed: Record<ZoneId, boolean>
}

const DEFAULT_LAYOUT: DockLayout = {
  zones: { main: ['files'], right: ['preview', 'agent'], bottom: ['terminal'] },
  active: { main: 'files', right: 'preview', bottom: 'terminal' },
  rightW: 440,
  bottomH: 260,
  collapsed: { main: false, right: false, bottom: false },
}

function loadLayout(): DockLayout {
  try {
    const raw = localStorage.getItem('helm-ck-dock')
    if (!raw) return structuredClone(DEFAULT_LAYOUT)
    const l = JSON.parse(raw) as DockLayout
    // 校验:四个模块一个不多一个不少,否则回默认(版本升级/手改坏了都能自愈)
    const all = ([] as ModuleId[]).concat(l.zones.main, l.zones.right, l.zones.bottom)
    const want: ModuleId[] = ['files', 'preview', 'terminal', 'agent']
    if (all.length !== 4 || want.some((m) => !all.includes(m))) return structuredClone(DEFAULT_LAYOUT)
    return l
  } catch {
    return structuredClone(DEFAULT_LAYOUT)
  }
}

export class DockStore {
  layout = $state<DockLayout>(loadLayout())
  /** 拖拽进行中:被拖模块 + 悬停 zone(渲染吸附高亮用)。 */
  dragging = $state<ModuleId | null>(null)
  hoverZone = $state<ZoneId | null>(null)

  #persist(): void {
    try {
      localStorage.setItem('helm-ck-dock', JSON.stringify(this.layout))
    } catch {
      /* 私隐模式/jsdom 兜底 */
    }
  }

  zoneOf(mod: ModuleId): ZoneId {
    for (const z of ['main', 'right', 'bottom'] as ZoneId[]) {
      if (this.layout.zones[z].includes(mod)) return z
    }
    return 'main'
  }

  /** 拖拽落位:从原 zone 摘下,插到目标 zone 末尾并设为活跃;原 zone 活跃顺移。 */
  move(mod: ModuleId, to: ZoneId): void {
    const from = this.zoneOf(mod)
    if (from === to) {
      this.activate(to, mod)
      return
    }
    const zones = {
      main: [...this.layout.zones.main],
      right: [...this.layout.zones.right],
      bottom: [...this.layout.zones.bottom],
    }
    zones[from] = zones[from].filter((m) => m !== mod)
    zones[to] = [...zones[to], mod]
    const active = { ...this.layout.active, [to]: mod }
    if (active[from] === mod) active[from] = zones[from][0] ?? null
    this.layout = { ...this.layout, zones, active, collapsed: { ...this.layout.collapsed, [to]: false } }
    this.#persist()
  }

  activate(zone: ZoneId, mod: ModuleId): void {
    if (!this.layout.zones[zone].includes(mod)) return
    this.layout = { ...this.layout, active: { ...this.layout.active, [zone]: mod } }
    this.#persist()
  }

  /** 让某模块可见:展开其所在 zone 并设为活跃(预览"选中即现"/收件箱跳转用)。
   *  幂等:已可见就不碰 layout——这个方法会被 effect 调,重写会自激循环。 */
  reveal(mod: ModuleId): void {
    const z = this.zoneOf(mod)
    if (this.layout.active[z] === mod && !this.layout.collapsed[z]) return
    this.layout = {
      ...this.layout,
      active: { ...this.layout.active, [z]: mod },
      collapsed: { ...this.layout.collapsed, [z]: false },
    }
    this.#persist()
  }

  toggleCollapse(zone: ZoneId): void {
    if (zone === 'main') return // 主区不折叠,永远有着陆点
    this.layout = {
      ...this.layout,
      collapsed: { ...this.layout.collapsed, [zone]: !this.layout.collapsed[zone] },
    }
    this.#persist()
  }

  resize(zone: 'right' | 'bottom', px: number): void {
    const v = zone === 'right' ? Math.min(900, Math.max(280, px)) : Math.min(700, Math.max(120, px))
    this.layout = { ...this.layout, [zone === 'right' ? 'rightW' : 'bottomH']: v }
    this.#persist()
  }

  isVisible(mod: ModuleId): boolean {
    const z = this.zoneOf(mod)
    return !this.layout.collapsed[z] && this.layout.active[z] === mod
  }

  resetLayout(): void {
    this.layout = structuredClone(DEFAULT_LAYOUT)
    this.#persist()
  }
}

export const dock = new DockStore()
