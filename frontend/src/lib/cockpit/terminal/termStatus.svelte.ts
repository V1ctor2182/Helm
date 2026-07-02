// 终端状态感知(承 FanBox app:2692-2801,单会话版):
// 输出→busy(回显过滤:距上次输入<400ms 不算 agent 自主干活,busy 只续命不刷工时)、
// 静默 2.5s→idle、进程退→dead;「esc to interrupt」30s 假静默护栏;
// 「N shells still running」阶段性收工不报喜;ask(等你拍板)单音、
// 真任务(工时>4s)收工双音 E5→B5+「轮到你」呼吸 6.5s。皮肤 token 由组件层管。

// 承 FanBox TERM_ASK_RE:claude/codex 审批界面文案
export const TERM_ASK_RE =
  /(Do you want to (proceed|continue|make this edit|allow|use this)|Would you like to proceed|Ready to code\?|created or one you trust\?|tell (Claude|Codex) what to do differently|Yes, and don't ask again|Allow Codex to (run|apply|create)|Codex wants to|[❯›][ \t]*1\.[ \t]*Yes)/

const STILL_RUNNING_RE = /\bstill running\b/i
const FOOT_COUNT_RE = /·\s*\d+\s+(shells?|monitors?|tasks?|agents?)\b/i
const ESC_INTERRUPT_RE = /esc to interrupt/i

const MUTE_KEY = 'helm-term-muted'

type ChimeType = 'done' | 'ask'

let audioCtx: AudioContext | null = null

function playChime(type: ChimeType): void {
  try {
    if (typeof window === 'undefined' || !('AudioContext' in window)) return
    audioCtx = audioCtx ?? new AudioContext()
    const ctx = audioCtx
    const now = ctx.currentTime
    // 完成是 E5→B5 上行小叮,ask 单音(和完成区分开)——承 FanBox playChime
    const notes = type === 'done' ? [659.25, 987.77] : [523.25]
    notes.forEach((f, i) => {
      const o = ctx.createOscillator()
      const g = ctx.createGain()
      o.type = 'sine'
      o.frequency.value = f
      o.connect(g)
      g.connect(ctx.destination)
      const t = now + i * 0.11
      g.gain.setValueAtTime(0, t)
      g.gain.linearRampToValueAtTime(0.11, t + 0.02)
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.4)
      o.start(t)
      o.stop(t + 0.45)
    })
  } catch {
    /* 音频不可用就算了 */
  }
}

export class TermStatus {
  status = $state<'idle' | 'busy' | 'dead'>('idle')
  /** 「轮到你」边缘呼吸(6.5s 自动退) */
  awaiting = $state(false)
  muted = $state(false)

  lastInput = 0
  lastData = 0
  lastReal = 0 // 工时只数 agent 自发输出(回显续命不算)
  busyStart = 0

  /** 组件注入:取终端缓冲区末尾 n 行纯文本(审批框/忙碌页脚都画在底部)。 */
  tailProvider: (n: number) => string = () => ''
  /** 提醒钩子(测试/涟漪用);组件层可覆盖。 */
  onComplete?: () => void
  onAsk?: () => void

  #tick: ReturnType<typeof setInterval> | null = null
  #awaitT: ReturnType<typeof setTimeout> | null = null

  constructor() {
    try {
      this.muted = localStorage.getItem(MUTE_KEY) === '1'
    } catch {
      /* jsdom */
    }
  }

  onInput(now = Date.now()): void {
    this.lastInput = now
  }

  onOutput(now = Date.now()): void {
    this.awaiting = false
    // 回显过滤:距上次用户输入 <400ms 的输出多半是回显/TUI 重绘
    if (now - this.lastInput < 400) {
      if (this.status === 'busy') this.lastData = now // 只续命
      return
    }
    this.lastData = now
    this.lastReal = now
    if (this.status !== 'busy') {
      this.status = 'busy'
      this.busyStart = now
    }
    this.#ensureTick()
  }

  onExit(): void {
    this.status = 'dead'
    this.#stopTick()
  }

  reset(): void {
    this.status = 'idle'
    this.awaiting = false
    this.#stopTick()
    if (this.#awaitT) clearTimeout(this.#awaitT)
  }

  #ensureTick(): void {
    if (this.#tick) return
    // claude/codex 忙碌心跳约 1s 一帧,1s 评估节奏足够
    this.#tick = setInterval(() => this.evaluate(), 1000)
  }

  #stopTick(): void {
    if (this.#tick) clearInterval(this.#tick)
    this.#tick = null
  }

  /** 忙→闲评估(可注入 now 便于测试)。 */
  evaluate(now = Date.now()): void {
    if (this.status !== 'busy') {
      this.#stopTick()
      return
    }
    const quiet = now - this.lastData
    if (quiet <= 2500) return
    const tail = this.tailProvider(25)
    // 假静默护栏:页脚仍挂「esc to interrupt」说明 agent 还在跑,30s 内不判收工
    if (quiet < 30000 && ESC_INTERRUPT_RE.test(tail)) return
    const dur = this.lastReal - this.busyStart
    this.status = 'idle'
    this.#stopTick()
    // 阶段性收工不报喜:底部还挂着后台任务,跑完会自动唤醒接着干
    const foot = this.tailProvider(8)
    if (STILL_RUNNING_RE.test(foot) || FOOT_COUNT_RE.test(foot)) return
    // 停在审批/确认界面:等你拍板(不设 4s 门槛,审批常来得很快)
    const ask = dur > 600 && TERM_ASK_RE.test(tail)
    if (ask || dur > 1500) this.#glow()
    if (ask) {
      if (!this.muted) playChime('ask')
      this.onAsk?.()
      this.#notify('等你拍板', 'agent 在等你确认')
    } else if (dur > 4000) {
      if (!this.muted) playChime('done')
      this.onComplete?.()
      this.#notify('agent 任务完成', '终端已空闲')
    }
  }

  #glow(): void {
    this.awaiting = true
    if (this.#awaitT) clearTimeout(this.#awaitT)
    this.#awaitT = setTimeout(() => (this.awaiting = false), 6500)
  }

  #notify(title: string, body: string): void {
    // 只在页面不可见且早已授权时用系统通知;夜间绝不主动请求权限
    try {
      if (
        typeof document !== 'undefined' &&
        document.hidden &&
        typeof Notification !== 'undefined' &&
        Notification.permission === 'granted'
      ) {
        new Notification(title, { body })
      }
    } catch {
      /* ignore */
    }
  }

  toggleMute(): void {
    this.muted = !this.muted
    try {
      localStorage.setItem(MUTE_KEY, this.muted ? '1' : '0')
    } catch {
      /* jsdom */
    }
    if (!this.muted) playChime('ask') // 开启时试放一声(承 FanBox)
  }
}

export const termStatus = new TermStatus()
