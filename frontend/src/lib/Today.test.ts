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
  it('renders the readout header, real rows and empty states', async () => {
    tasks.tasks = [
      {
        id: 1, name: '每日邮件摘要', prompt: 'p', schedule_kind: 'cron', schedule_value: { expr: '0 9 * * *' },
        execution_mode: 'new_conversation', enabled: true, next_run: '2026-07-03T01:00:00+00:00',
        last_status: null, run_count: 0, linked_note_id: null,
      },
    ]
    agent.runs = [
      { id: 9, agent: 'claude-code', status: 'completed', prompt: '修构建', project_path: '/p', started_at: '2026-07-02T01:00:00', ended_at: null },
    ]
    cockpit.projects = [{ path: '/tmp/helm', name: 'helm', badges: [], last_opened: '2026-07-01T00:00:00' }]
    render(Today)
    expect(screen.getByRole('heading', { name: /Today/ })).toBeInTheDocument()
    expect(screen.getByText(/任务 \/ TASKS/)).toBeInTheDocument()
    expect(await screen.findByText('每日邮件摘要')).toBeInTheDocument()
    expect(screen.getByText('claude-code')).toBeInTheDocument()
    expect(screen.getByText(/最近项目 \/ PROJECTS/)).toBeInTheDocument()
    expect(screen.getByText('helm')).toBeInTheDocument()
    // 日程空态
    expect(screen.getByText(/没有即将到来的日程/)).toBeInTheDocument()
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
