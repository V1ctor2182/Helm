import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import AgentView from './AgentView.svelte'
import CockpitView from '../cockpit/CockpitView.svelte'
import { dock } from '../cockpit/dock.svelte'
import { cockpit } from '../cockpit/cockpit.svelte'
import { agent } from './agentStore.svelte'

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ runs: [], entries: [], projects: [], path: '/' }) }))
})
afterEach(() => {
  vi.restoreAllMocks()
  agent.events = []
  agent.runs = []
  agent.status = 'idle'
  agent.error = null
  agent.runId = null
})

describe('AgentView', () => {
  it('renders the empty hint then a streamed event line', async () => {
    render(AgentView)
    expect(await screen.findByText(/运行一条指令/)).toBeInTheDocument()

    agent.events = [
      { type: 'tool_call', session_id: 's', data: { name: 'Read', input: { file_path: 'a.py' } }, ts: 1 },
    ]
    expect(await screen.findByText(/Read a\.py/)).toBeInTheDocument()
  })

  it('renders a rate-limit line and warns when overage is exhausted', async () => {
    render(AgentView)
    agent.events = [
      { type: 'rate_limit', session_id: 's', data: { status: 'allowed', limit_type: 'five_hour', overage_status: 'rejected' }, ts: 1 },
    ]
    expect(await screen.findByText(/额度状态.*超额额度已用尽/)).toBeInTheDocument()
  })

  it('shows an error banner', async () => {
    agent.status = 'error'
    agent.error = 'agent not found: gemini'
    render(AgentView)
    expect(await screen.findByRole('alert')).toHaveTextContent('gemini')
  })
})

describe('CockpitView(dock 布局,阶段3.5 用户拍板全模块吸附)', () => {
  it('默认布局:文件@主区、预览+Agent@右栏 tab 栈、终端@底栏;点 AGENT tab 切换', async () => {
    dock.resetLayout()
    render(CockpitView)
    expect(screen.getByText('文件 / FILES')).toBeInTheDocument()
    expect(screen.getByText('终端 / TERMINAL')).toBeInTheDocument()
    const agentTab = screen.getByText('AGENT')
    await fireEvent.pointerDown(agentTab)
    await fireEvent.pointerUp(window)
    expect(dock.layout.active.right).toBe('agent')
    expect(await screen.findByLabelText('Agent 指令')).toBeInTheDocument()
  })

  it('dock.move 把终端搬去右栏成 tab 栈;折叠右栏出竖条', async () => {
    dock.resetLayout()
    render(CockpitView)
    dock.move('terminal', 'right')
    expect(dock.layout.zones.right).toEqual(['preview', 'agent', 'terminal'])
    expect(dock.layout.active.right).toBe('terminal')
    expect(dock.layout.zones.bottom).toEqual([])
    dock.toggleCollapse('right')
    expect(await screen.findByText(/预览 · AGENT · 终端/)).toBeInTheDocument()
    dock.resetLayout()
  })
})
