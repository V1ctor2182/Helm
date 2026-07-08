// 全局专注状态(K8,稿:helm-journal-kinds.html 专注链路)。
// 从任何地方发起(捕获坞/待办),在速记墙顶活着(圆环计时),
// 停止时写入今日日记(「专注 N 分钟 · what」),被日记页详情的专注块聚合。
import { notes } from './notes/notesStore.svelte'

function today(): string {
  const d = new Date()
  const p2 = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`
}

export class FocusStore {
  startAt = $state<number | null>(null)
  what = $state('')
  tick = $state(0)
  private timer: ReturnType<typeof setInterval> | null = null

  get running(): boolean {
    return this.startAt !== null
  }

  get seconds(): number {
    if (this.startAt === null) return 0
    return Math.max(0, Math.floor(((this.tick || Date.now()) - this.startAt) / 1000))
  }

  get mmss(): string {
    const s = this.seconds
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
  }

  /** 圆环进度角度(一小时一圈) */
  get deg(): number {
    return ((this.seconds % 3600) / 3600) * 360
  }

  start(what: string): void {
    this.what = what.trim()
    this.startAt = Date.now()
    this.tick = Date.now()
    this.timer ??= setInterval(() => (this.tick = Date.now()), 1000)
  }

  /** 停止并记入今日日记;返回分钟数 */
  async stop(): Promise<number> {
    const mins = Math.max(1, Math.round(this.seconds / 60))
    const what = this.what ? ` · ${this.what}` : ''
    this.startAt = null
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
    await notes.create(`专注 ${mins} 分钟${what}`, 'journal', today())
    return mins
  }

  cancel(): void {
    this.startAt = null
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}

export const focus = new FocusStore()
