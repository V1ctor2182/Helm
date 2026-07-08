import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import Today from './Today.svelte'
import { layout } from './layout.svelte'
import { projects } from './project.svelte'
import { tasks } from './notes/tasksStore.svelte'
import { agent } from './orchestration/agentStore.svelte'
import { cockpit } from './cockpit/cockpit.svelte'
import { calendar } from './mail/calendarStore.svelte'

beforeEach(() => {
  // onMount 的各 load 全走同一个宽容 mock(空数据),测试用预置 store 数据断言
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ tasks: [], notes: [], runs: [], projects: [], events: [], accounts: [] }),
    }),
  )
})

afterEach(() => {
  vi.restoreAllMocks()
  layout.setMode('today')
  layout.tabs = []
  projects.setCurrent(null)
  projects.setRecent([])
  tasks.tasks = []
  agent.runs = []
  cockpit.projects = []
  calendar.events = []
})

describe('Today · NOMI 六卡仪表(真数据)', () => {
  it('renders greeting, capture dock and dashboard cards', () => {
    render(Today)
    // 问候行 + 日期摘要
    expect(document.querySelector('.hi')).not.toBeNull()
    expect(document.querySelector('.sub')).not.toBeNull()
    // 卡标题(捕获坞 chips 也叫「任务/日记」→ 限定在 .ti 卡标题里找)
    const cardTitles = [...document.querySelectorAll('.ti')].map((el) => el.textContent)
    expect(cardTitles).toContain('任务 · 今日')
    expect(cardTitles).toContain('日记 · 今天')
    expect(cardTitles).toContain('智能体')
    expect(cardTitles).toContain('简报 · 世界输入')
    // 捕获坞也在(单入口:输入框+专注钮)
    expect(screen.getByLabelText('捕获内容')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '开始专注' })).toBeInTheDocument()
    // 空态
    expect(screen.getByText(/没有定时任务/)).toBeInTheDocument()
    expect(screen.getByText(/没有 agent 运行/)).toBeInTheDocument()
    // 简报卡保留世界输入语义(功能不减)
    expect(screen.getByLabelText('世界输入')).toBeInTheDocument()
  })

  it('shows empty states without data', () => {
    render(Today)
    expect(screen.getByText(/没有定时任务/)).toBeInTheDocument()
    expect(screen.getByText(/没有 agent 运行/)).toBeInTheDocument()
    expect(screen.getByText(/还没有项目/)).toBeInTheDocument()
  })

  it('quick-action row is gone (dedup: Rail/CaptureDock own those entries)', () => {
    // 2026-07-06 用户拍板:＋新Chat/发起研究/记一条 与 Rail 导航、捕获坞重复,删。
    render(Today)
    expect(screen.queryByRole('button', { name: /新 Chat/ })).toBeNull()
    expect(screen.queryByRole('button', { name: /发起研究/ })).toBeNull()
    expect(screen.queryByRole('button', { name: /记一条/ })).toBeNull()
  })

  it('clicking a recent project enters cockpit mode', async () => {
    // onMount 的 loadProjects 会覆盖预置,让 mock 直接返回该项目
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve(
              String(url).includes('/cockpit/projects')
                ? { projects: [{ path: '/tmp/helm', name: 'helm', badges: [], last_opened: null }] }
                : { tasks: [], notes: [], runs: [], events: [], accounts: [] },
            ),
        }),
      ),
    )
    render(Today)
    await fireEvent.click(await screen.findByRole('button', { name: /helm/ }))
    expect(layout.mode).toBe('cockpit')
  })
})

describe('T4 日记卡 · 每天一篇', () => {
  const today = (() => {
    const d = new Date()
    const p = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
  })()

  it('今日多段按时间升序拼一篇预览,foot 有续写 →', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve(
              String(url).includes('/api/notes')
                ? { notes: [
                    { id: 2, kind: 'journal', title: null, content: '下午修了 bug', tags: [], meta: null, pinned: false, source: 'user', journal_date: today, created_at: `${today}T15:00:00`, updated_at: null },
                    { id: 1, kind: 'journal', title: null, content: '早上定了稿', tags: [], meta: null, pinned: false, source: 'user', journal_date: today, created_at: `${today}T09:00:00`, updated_at: null },
                  ] }
                : { tasks: [], notes: [], runs: [], projects: [], events: [], accounts: [] },
            ),
        }),
      ),
    )
    render(Today)
    const prev = await screen.findByText(/早上定了稿/)
    // 升序拼接:早上在前,下午在后(notch journalToday 同口径)
    expect(prev.textContent).toBe('早上定了稿\n\n下午修了 bug')
    expect(screen.getByText('2 段')).toBeInTheDocument()
    // 续写 → 落到记录页日记 tab
    await fireEvent.click(screen.getByRole('button', { name: '续写 →' }))
    expect(layout.mode).toBe('journal')
    expect(layout.journalIntent).toBe('journal')
  })

  it('没写时给空态引导', async () => {
    render(Today)
    expect(await screen.findByText(/今天还没写/)).toBeInTheDocument()
  })
})
