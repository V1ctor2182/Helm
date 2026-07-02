import { afterEach, describe, expect, it, vi } from 'vitest'
import { TermStatus, TERM_ASK_RE } from './termStatus.svelte'

afterEach(() => vi.restoreAllMocks())

const mk = () => {
  const s = new TermStatus()
  s.muted = true // 测试不出声
  return s
}

describe('TermStatus(busy/idle/dead + 提醒判定)', () => {
  it('output → busy;2.5s 静默后 evaluate → idle', () => {
    const s = mk()
    s.onOutput(1000)
    expect(s.status).toBe('busy')
    s.evaluate(3000) // quiet 2000 ≤ 2500 → 仍 busy
    expect(s.status).toBe('busy')
    s.evaluate(3600) // quiet 2600 → idle
    expect(s.status).toBe('idle')
  })

  it('回显过滤:输入后 <400ms 的输出不进入 busy;已 busy 只续命不刷工时', () => {
    const s = mk()
    s.onInput(1000)
    s.onOutput(1200) // 回显 → 不 busy
    expect(s.status).toBe('idle')
    s.onOutput(2000) // 自发输出 → busy,busyStart=2000
    s.onInput(9000)
    s.onOutput(9100) // 回显续命:lastData 刷新,lastReal 不动
    expect(s.lastReal).toBe(2000)
    expect(s.lastData).toBe(9100)
  })

  it('「esc to interrupt」30s 内不判收工', () => {
    const s = mk()
    s.tailProvider = () => 'running… esc to interrupt'
    s.onOutput(1000)
    s.evaluate(10000) // quiet 9s < 30s + 护栏文案 → 仍 busy
    expect(s.status).toBe('busy')
    s.evaluate(32000) // 超 30s → 判收工
    expect(s.status).toBe('idle')
  })

  it('真任务(工时>4s)收工触发 onComplete;短任务不触发', () => {
    const s = mk()
    const done = vi.fn()
    s.onComplete = done
    s.tailProvider = () => ''
    s.onOutput(1000)
    s.onOutput(6000) // lastReal=6000,工时 5s
    s.evaluate(9000)
    expect(s.status).toBe('idle')
    expect(done).toHaveBeenCalledTimes(1)
    expect(s.awaiting).toBe(true) // 轮到你呼吸

    const s2 = mk()
    const done2 = vi.fn()
    s2.onComplete = done2
    s2.onOutput(1000) // 工时 0
    s2.evaluate(4000)
    expect(done2).not.toHaveBeenCalled()
  })

  it('审批界面 → onAsk(不设 4s 门槛);still running 页脚压制一切提醒', () => {
    const s = mk()
    const ask = vi.fn()
    const done = vi.fn()
    s.onAsk = ask
    s.onComplete = done
    s.tailProvider = () => 'Do you want to proceed?\n❯ 1. Yes'
    s.onOutput(1000)
    s.onOutput(2000) // 工时 1s > 600ms
    s.evaluate(5000)
    expect(ask).toHaveBeenCalledTimes(1)
    expect(done).not.toHaveBeenCalled()

    const s3 = mk()
    const done3 = vi.fn()
    s3.onComplete = done3
    s3.tailProvider = (n) => (n === 8 ? '2 shells still running' : '')
    s3.onOutput(1000)
    s3.onOutput(9000)
    s3.evaluate(12000)
    expect(s3.status).toBe('idle') // 圆点照常变空闲
    expect(done3).not.toHaveBeenCalled() // 但不报喜
  })

  it('exit → dead;ask 正则认 claude/codex 审批文案', () => {
    const s = mk()
    s.onOutput(1000)
    s.onExit()
    expect(s.status).toBe('dead')
    expect(TERM_ASK_RE.test('Would you like to proceed')).toBe(true)
    expect(TERM_ASK_RE.test('Allow Codex to run npm test')).toBe(true)
    expect(TERM_ASK_RE.test('just some output')).toBe(false)
  })
})
