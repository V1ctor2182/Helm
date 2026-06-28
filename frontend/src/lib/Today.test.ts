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

describe('Today', () => {
  it('renders quick actions and module cards', () => {
    render(Today)
    expect(screen.getByRole('button', { name: /新建 Chat/ })).toBeInTheDocument()
    expect(screen.getByText('最近项目')).toBeInTheDocument()
    expect(screen.getByText('日历 / 日程')).toBeInTheDocument()
  })

  it('clicking a module enters its mode', async () => {
    render(Today)
    await fireEvent.click(screen.getByText('最近项目'))
    expect(layout.mode).toBe('cockpit')
  })

  it('New Chat switches to chat mode and opens a tab', async () => {
    render(Today)
    await fireEvent.click(screen.getByRole('button', { name: /新建 Chat/ }))
    expect(layout.mode).toBe('chat')
    expect(layout.tabs.some((t) => t.mode === 'chat')).toBe(true)
  })

  it('shows the current project when one is set', () => {
    projects.setCurrent({ path: '/p', name: 'MyProj' })
    render(Today)
    expect(screen.getByText('MyProj')).toBeInTheDocument()
  })

  it('shows "未选择项目" when none is set', () => {
    render(Today)
    expect(screen.getByText('未选择项目')).toBeInTheDocument()
  })
})
