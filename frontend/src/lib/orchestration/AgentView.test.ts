import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import AgentView from './AgentView.svelte'
import CockpitView from '../cockpit/CockpitView.svelte'
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

describe('CockpitView(预览按需面板,阶段3.5 结构#1)', () => {
  it('无选中时文件区铺满(右栏不渲染);选中滑出;×关闭回全宽', async () => {
    const { container } = render(CockpitView)
    expect(screen.queryByRole('tab', { name: '预览' })).toBeNull() // 按需:默认无右栏
    cockpit.selected = { name: 'a.md', path: '/p/a.md', is_dir: false, size: 1, ext: 'md', mtime: 0 }
    const agentTab = await screen.findByRole('tab', { name: 'Agent' })
    expect(container.querySelector('.divider')).not.toBeNull() // 可拖中缝
    await fireEvent.click(agentTab)
    expect(screen.getByLabelText('Agent 指令')).toBeInTheDocument()
    await fireEvent.click(screen.getByLabelText('关闭面板'))
    expect(cockpit.selected).toBeNull()
    expect(screen.queryByRole('tab', { name: 'Agent' })).toBeNull()
  })

  it('rightTab=agent 时无选中也能开观察台', async () => {
    cockpit.rightTab = 'agent'
    render(CockpitView)
    expect(await screen.findByLabelText('Agent 指令')).toBeInTheDocument()
    cockpit.rightTab = 'preview'
  })
})
