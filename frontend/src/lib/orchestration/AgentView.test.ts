import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import AgentView from './AgentView.svelte'
import CockpitView from '../cockpit/CockpitView.svelte'
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

  it('shows an error banner', async () => {
    agent.status = 'error'
    agent.error = 'agent not found: gemini'
    render(AgentView)
    expect(await screen.findByRole('alert')).toHaveTextContent('gemini')
  })
})

describe('CockpitView', () => {
  it('toggles the right pane between 预览 and Agent', async () => {
    render(CockpitView)
    // both segmented tabs present; agent tab switches the pane
    const agentTab = await screen.findByRole('tab', { name: 'Agent' })
    await fireEvent.click(agentTab)
    expect(screen.getByLabelText('Agent 指令')).toBeInTheDocument()
  })
})
