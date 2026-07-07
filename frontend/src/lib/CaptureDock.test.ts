import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import CaptureDock from './CaptureDock.svelte'

// 捕获坞(去重定稿 2026-07-08):无 kind chips——AI 判定徽章分流(可点轮换),
// 任务时双轨浮现,⏱ 专注,疑问句→问大脑。
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

  it('单入口:输入框+专注钮在,老 kind chips 不在', () => {
    render(CaptureDock)
    expect(screen.getByLabelText('捕获内容')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '开始专注' })).toBeInTheDocument()
    // 旧 chips 行退场(专注/问大脑不再是 chip)
    expect(screen.queryByRole('button', { name: '专注' })).toBeNull()
    expect(screen.queryByRole('button', { name: '问大脑' })).toBeNull()
  })

  it('AI 判类:时间词→任务+双轨浮现;徽章点击轮换=手动接管', async () => {
    render(CaptureDock)
    const input = screen.getByLabelText('捕获内容') as HTMLInputElement
    await fireEvent.input(input, { target: { value: '明早 9 点跑回归测试' } })
    expect(await screen.findByText(/AI · 任务/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '给自己' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '交给 agent' })).toBeInTheDocument()
    // 点徽章轮换 → 手动
    await fireEvent.click(screen.getByText(/AI · 任务/))
    expect(screen.getByText(/手动/)).toBeInTheDocument()
  })

  it('自动挡发送=后端分诊(triage:true 不带 kind)+ 结构化回执 toast', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string, init?: RequestInit) => {
        const method = init?.method ?? 'GET'
        if (String(url) === '/api/notes' && method === 'POST')
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              id: 5, kind: 'task', meta: { when: '明天 09:00', where: null },
              triage: { kind: 'task', when: '明天 09:00', where: null, due: null, recurring: false, confident: true },
            }),
          })
        if (String(url) === '/api/notes/5' && method === 'PATCH')
          return Promise.resolve({ ok: true, json: () => Promise.resolve({ id: 5, kind: 'note' }) })
        return Promise.resolve({ ok: true, json: () => Promise.resolve({ notes: [] }) })
      }),
    )
    render(CaptureDock)
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '明天买牛奶' } })
    await screen.findByRole('button', { name: '给自己' })
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    // POST 带 triage:true、不带 kind(后端为准)
    const calls = (fetch as ReturnType<typeof vi.fn>).mock.calls
    const post = calls.find(([u, i]) => u === '/api/notes' && (i as RequestInit)?.method === 'POST')
    const body = JSON.parse((post![1] as RequestInit).body as string)
    expect(body.triage).toBe(true)
    expect(body.kind).toBeUndefined()
    // 回执 toast:类型 chip + 抽取 chip + 已入待办 + 改
    expect(await screen.findByText('已结构化入库')).toBeInTheDocument()
    expect(screen.getByText('明天 09:00')).toBeInTheDocument()
    expect(screen.getByText('→ 已入待办')).toBeInTheDocument()
    // 「改」纠正回流:task → note(PATCH kind)
    await fireEvent.click(screen.getByRole('button', { name: '改' }))
    const patch = (fetch as ReturnType<typeof vi.fn>).mock.calls.find(
      ([u, i]) => u === '/api/notes/5' && (i as RequestInit)?.method === 'PATCH')
    expect(JSON.parse((patch![1] as RequestInit).body as string)).toEqual({ kind: 'note' })
  })

  it('手动接管发送=显式 kind,不走分诊', async () => {
    render(CaptureDock)
    // 叙事→AI 判日记;点徽章轮换一档(CYCLE journal→task)=手动 · 任务
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '今天终于把三态设计稿全部定下来了,感觉很顺' } })
    await fireEvent.click(await screen.findByText(/AI · 日记/))
    expect(screen.getByText(/手动 · 任务/)).toBeInTheDocument()
    await screen.findByRole('button', { name: '给自己' })
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    const post = (fetch as ReturnType<typeof vi.fn>).mock.calls.find(
      ([u, i]) => u === '/api/notes' && (i as RequestInit)?.method === 'POST')
    const body = JSON.parse((post![1] as RequestInit).body as string)
    expect(body.kind).toBe('task')
    expect(body.triage).toBeUndefined()
  })

  it('task→交给 agent posts to /api/tasks with prompt', async () => {
    render(CaptureDock)
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '明早 9 点到点跑测试' } })
    await fireEvent.click(await screen.findByRole('button', { name: '交给 agent' }))
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    const calls = (fetch as ReturnType<typeof vi.fn>).mock.calls
    const post = calls.find(([u]) => u === '/api/tasks')
    expect(post).toBeTruthy()
    expect(JSON.parse((post![1] as RequestInit).body as string).prompt).toBe('明早 9 点到点跑测试')
  })

  it('疑问句→问大脑并显示回答', async () => {
    render(CaptureDock)
    await fireEvent.input(screen.getByLabelText('捕获内容'), { target: { value: '怎么配后端?' } })
    expect(await screen.findByText(/AI · 问大脑/)).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('button', { name: '发送' }))
    expect(await screen.findByText('好的')).toBeInTheDocument()
  })
})
