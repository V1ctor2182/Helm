import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import Sidebar from './Sidebar.svelte'
import { cockpit } from './cockpit.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  cockpit.favorites = []
  cockpit.projects = []
  cockpit.projectActivity = {}
  cockpit.cwd = null
})

describe('Sidebar(阶段3.5 结构#2)', () => {
  it('渲染快速入口;点击走 browse 且手动接管跟随', async () => {
    const calls: string[] = []
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) => {
        calls.push(String(url))
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ path: '/Users/x/Desktop', entries: [] }) })
      }),
    )
    cockpit.followMode = true
    render(Sidebar)
    await fireEvent.click(screen.getByText('桌面'))
    expect(cockpit.followMode).toBe(false) // 导航=手动接管
    await vi.waitFor(() => {
      expect(calls.some((u) => u.includes(encodeURIComponent('~/Desktop')))).toBe(true)
    })
  })

  it('收藏列表随 store 渲染,× 取消收藏并持久化', async () => {
    cockpit.toggleFavorite('/p/工程A')
    render(Sidebar)
    expect(screen.getByText('工程A')).toBeInTheDocument()
    await fireEvent.click(screen.getByLabelText('取消收藏 工程A'))
    expect(cockpit.favorites).toHaveLength(0) // 持久化走 saveJson(try/catch),jsdom localStorage 残缺不直测
  })

  it('Agent 项目显示活跃度徽章(刚刚)', () => {
    cockpit.projects = [{ name: 'helm', path: '/w/helm' } as (typeof cockpit.projects)[number]]
    cockpit.projectActivity = { '/w/helm': Date.now() - 20_000 }
    render(Sidebar)
    expect(screen.getByText('helm')).toBeInTheDocument()
    expect(screen.getByText('刚刚')).toBeInTheDocument()
  })
})
