import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import CaptureDock from './CaptureDock.svelte'

// 捕获坞:5-kind 切换 + 任务给自己/交给 agent 分流(语义同 notch)。
describe('CaptureDock', () => {
  beforeEach(() => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ notes: [], answer: '好的' }),
      }),
    )
  })
  afterEach(() => vi.unstubAllGlobals())

  it('renders the five kinds and switches placeholder', async () => {
    render(CaptureDock)
    for (const label of ['速记', '日记', '任务', '专注', '问大脑']) {
      expect(screen.getByRole('button', { name: label })).toBeInTheDocument()
    }
    await fireEvent.click(screen.getByRole('button', { name: '任务' }))
    // 任务模式露出目标二段
    expect(screen.getByRole('button', { name: '给自己' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '交给 agent' })).toBeInTheDocument()
  })

  it('task→给自己 posts a task note (notes kind:task)', async () => {
    render(CaptureDock)
    await fireEvent.click(screen.getByRole('button', { name: '任务' }))
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '买牛奶' } })
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    const calls = (fetch as ReturnType<typeof vi.fn>).mock.calls
    const post = calls.find(([u, i]) => u === '/api/notes' && (i as RequestInit)?.method === 'POST')
    expect(post).toBeTruthy()
    expect(JSON.parse((post![1] as RequestInit).body as string).kind).toBe('task')
  })

  it('task→交给 agent posts to /api/tasks with prompt', async () => {
    render(CaptureDock)
    await fireEvent.click(screen.getByRole('button', { name: '任务' }))
    await fireEvent.click(screen.getByRole('button', { name: '交给 agent' }))
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '到点跑测试' } })
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    const calls = (fetch as ReturnType<typeof vi.fn>).mock.calls
    const post = calls.find(([u]) => u === '/api/tasks')
    expect(post).toBeTruthy()
    expect(JSON.parse((post![1] as RequestInit).body as string).prompt).toBe('到点跑测试')
  })

  it('ask shows the brain answer', async () => {
    render(CaptureDock)
    await fireEvent.click(screen.getByRole('button', { name: '问大脑' }))
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '怎么配后端?' } })
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    expect(await screen.findByText('好的')).toBeInTheDocument()
  })
})

it('K7 智能判类:时间词自动切任务,点 chip 手动接管', async () => {
  render(CaptureDock)
  const input = screen.getByLabelText('捕获内容') as HTMLInputElement
  await fireEvent.input(input, { target: { value: '明早 9 点跑回归测试' } })
  // AI 判定徽章出现且 kind 自动切到任务(给自己/交给 agent 双轨浮现)
  expect(await screen.findByText(/AI · 任务/)).toBeInTheDocument()
  expect(screen.getByRole('button', { name: '给自己' })).toBeInTheDocument()
  // 手动点「速记」chip → 接管,显示手动徽章
  await fireEvent.click(screen.getByRole('button', { name: '速记' }))
  expect(screen.getByText(/手动/)).toBeInTheDocument()
})
