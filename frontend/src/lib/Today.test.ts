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

describe('Today · instrument readout(真数据)', () => {
  it('renders the v3 dial anchor, block keys and briefing column', async () => {
    render(Today)
    // 屏锚:时钟(HH:MM)与日期列
    expect(document.querySelector('.clock')).not.toBeNull()
    expect(document.querySelector('.datecol .d1')).not.toBeNull()
    // 区块头 key(捕获坞 chips 也叫「任务/日记」→ 限定在 .bt 区块标题里找)
    const blockTitles = [...document.querySelectorAll('.bt')].map((el) => el.textContent)
    expect(blockTitles).toContain('任务')
    expect(blockTitles).toContain('日记')
    expect(screen.getByText('智能体')).toBeInTheDocument()
    // 捕获坞也在(5 kind chips)
    expect(screen.getByRole('button', { name: '问大脑' })).toBeInTheDocument()
    // 空态
    expect(screen.getByText(/没有定时任务/)).toBeInTheDocument()
    expect(screen.getByText(/没有 agent 运行/)).toBeInTheDocument()
    // 右柱:世界输入
    expect(screen.getByLabelText('世界输入')).toBeInTheDocument()
    expect(screen.getByText('BRIEFING')).toBeInTheDocument()
    // 聚光:默认任务区 focus,点日记区移光
    const blocks = document.querySelectorAll('.blk')
    expect(blocks[0].className).toContain('focus')
    await fireEvent.click(blocks[1])
    expect(blocks[1].className).toContain('focus')
    expect(blocks[0].className).not.toContain('focus')
  })

  it('shows empty states without data', () => {
    render(Today)
    expect(screen.getByText(/没有定时任务/)).toBeInTheDocument()
    expect(screen.getByText(/没有 agent 运行/)).toBeInTheDocument()
    expect(screen.getByText(/还没有项目/)).toBeInTheDocument()
  })

  it('New Chat switches to chat mode and opens a tab', async () => {
    render(Today)
    await fireEvent.click(screen.getByRole('button', { name: /新 Chat/ }))
    expect(layout.mode).toBe('chat')
    expect(layout.tabs.some((t) => t.mode === 'chat')).toBe(true)
  })

  it('发起研究 switches to research mode', async () => {
    render(Today)
    await fireEvent.click(screen.getByRole('button', { name: /发起研究/ }))
    expect(layout.mode).toBe('research')
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
