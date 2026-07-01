import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it } from 'vitest'
import Today from './Today.svelte'
import { layout } from './layout.svelte'
import { projects } from './project.svelte'

afterEach(() => {
  layout.setMode('today')
  layout.tabs = []
  projects.setCurrent(null)
  projects.setRecent([])
})

describe('Today · instrument readout', () => {
  it('renders the readout header, sections and mock rows', () => {
    render(Today)
    expect(screen.getByRole('heading', { name: /Today/ })).toBeInTheDocument()
    expect(screen.getByText(/任务 \/ TASKS/)).toBeInTheDocument()
    expect(screen.getByText(/notch scroll/)).toBeInTheDocument()
    expect(screen.getByText(/最近项目 \/ PROJECTS/)).toBeInTheDocument()
    // agent viewport row
    expect(screen.getByText('notch')).toBeInTheDocument()
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
    render(Today)
    // 用分支名唯一定位「最近项目」里的 helm 按钮（agent 行也有 "helm" 文本）
    await fireEvent.click(screen.getByRole('button', { name: /feat\/notch/ }))
    expect(layout.mode).toBe('cockpit')
  })
})
