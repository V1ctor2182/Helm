import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import JournalView from './JournalView.svelte'
import { notes } from './notesStore.svelte'
import { layout } from '../layout.svelte'

const N = (over: Record<string, unknown> = {}) => ({
  id: 1,
  kind: 'note',
  title: null,
  content: 'a note',
  tags: [],
  meta: null,
  pinned: false,
  source: 'user',
  journal_date: null,
  created_at: null,
  updated_at: null,
  ...over,
})

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ notes: [] }) }))
  layout.journalFilter = 'all' // 共享 store,测试间重置
})
afterEach(() => {
  vi.restoreAllMocks()
  notes.notes = []
  notes.error = null
})

describe('JournalView', () => {
  it('lists quick notes with convert actions in the ⋯ menu', async () => {
    const rows = [N({ id: 7, content: 'buy milk' })]
    vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          (init?.method ?? 'GET') !== 'GET' ? {}
          : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
      }),
    ))
    render(JournalView)
    expect(await screen.findByText('buy milk')).toBeInTheDocument()
    // 操作收进 ⋯ 菜单(2026-07-08 用户拍板),点开才显示
    expect(screen.queryByRole('menuitem', { name: '→日记' })).toBeNull()
    await fireEvent.click(screen.getByRole('button', { name: '更多操作 buy milk' }))
    expect(screen.getByRole('menuitem', { name: '→日记' })).toBeInTheDocument()
    expect(screen.getByRole('menuitem', { name: '→记忆' })).toBeInTheDocument()
    // 删除两击确认
    await fireEvent.click(screen.getByRole('menuitem', { name: '删除' }))
    expect(screen.getByRole('menuitem', { name: '确认删除' })).toBeInTheDocument()
  })

  it('switching to 日记 groups entries by date and renders markdown', async () => {
    notes.notes = [
      N({ id: 1, kind: 'journal', journal_date: '2026-06-27', content: '# Big day\nshipped **m3**' }),
      N({ id: 2, kind: 'journal', journal_date: '2026-06-26', content: 'yesterday' }),
    ]
    render(JournalView)
    await fireEvent.click(screen.getByRole('tab', { name: '日记' }))
    // both date headers present, newest first
    expect(await screen.findByText('6月27日')).toBeInTheDocument()
    expect(screen.getByText('6月26日')).toBeInTheDocument()
    // markdown rendered (bold + heading)
    expect(screen.getByRole('heading', { name: 'Big day' })).toBeInTheDocument()
    expect(screen.getByText('m3').tagName).toBe('STRONG')
  })

  it('convert button calls toJournal', async () => {
    const spy = vi.spyOn(notes, 'toJournal').mockResolvedValue(true)
    const rows = [N({ id: 9, content: 'convert me' })]
    vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          (init?.method ?? 'GET') !== 'GET' ? {}
          : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
      }),
    ))
    render(JournalView)
    await fireEvent.click(await screen.findByRole('button', { name: '更多操作 convert me' }))
    await fireEvent.click(screen.getByRole('menuitem', { name: '→日记' }))
    expect(spy).toHaveBeenCalledWith(9)
  })

  it('shows empty states', async () => {
    render(JournalView)
    expect(await screen.findByText(/还没有速记/)).toBeInTheDocument()
  })

  it('→任务 jumps to the tasks tab with the note pinned', async () => {
    const rows = [N({ id: 11, content: 'summarize inbox daily' })]
    vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          (init?.method ?? 'GET') !== 'GET' ? {}
          : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
      }),
    ))
    render(JournalView)
    await fireEvent.click(await screen.findByRole('button', { name: '更多操作 summarize inbox daily' }))
    await fireEvent.click(screen.getByRole('menuitem', { name: '→任务' }))
    // tasks tab active with the note pinned as a chip; the input now takes the
    // 人话时间 phrase (T2), so it stays editable and empty.
    expect(screen.getByRole('tab', { name: '任务' })).toHaveAttribute('aria-selected', 'true')
    const prompt = screen.getByLabelText('任务指令') as HTMLInputElement
    expect(prompt.value).toBe('')
    expect(prompt.placeholder).toContain('什么时候')
    expect(screen.getByText(/自速记 #11/)).toBeInTheDocument()
  })

  it('pinned note submits via to-task with the typed 人话时间', async () => {
    const spy = vi.spyOn(notes, 'toTaskNL').mockResolvedValue(true)
    const rows = [N({ id: 11, content: 'summarize inbox daily' })]
    vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          (init?.method ?? 'GET') !== 'GET' ? {}
          : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
      }),
    ))
    render(JournalView)
    await fireEvent.click(await screen.findByRole('button', { name: '更多操作 summarize inbox daily' }))
    await fireEvent.click(screen.getByRole('menuitem', { name: '→任务' }))
    await fireEvent.input(screen.getByLabelText('任务指令'), { target: { value: '每天早上9点' } })
    await fireEvent.click(screen.getByRole('button', { name: '交给 agent' }))
    expect(spy).toHaveBeenCalledWith(11, '每天早上9点')
  })
})

it('AI 归类:按主题分组显示分区/未归类,≥3 条涌现建议卡', async () => {
  // onMount load() 会覆盖预置 → mock 直接返回带 topic 的 4 条
  const rows = [
    N({ id: 1, content: 'a1', meta: { type: 'text', topic: 'T学习' } }),
    N({ id: 2, content: 'a2', meta: { type: 'text', topic: 'T学习' } }),
    N({ id: 3, content: 'a3', meta: { type: 'text', topic: 'T学习' } }),
    N({ id: 4, content: 'loose' }),
  ]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  await fireEvent.click(screen.getByText('按主题 · AI'))
  // 分区头 + 胶囊 + 建议卡都带主题名(≥2 处)
  expect((await screen.findAllByText('T学习')).length).toBeGreaterThanOrEqual(2)
  expect(screen.getByText('未归类')).toBeInTheDocument()
  // 涌现建议(3 条未确认)
  expect(screen.getByText(/建一个集合/)).toBeInTheDocument()
  await fireEvent.click(screen.getByRole('button', { name: '创建集合' }))
  expect(screen.queryByText(/建一个集合/)).toBeNull()
})

it('T3 待办两层行:临近橙 chip+地点+速记分诊 chips,临近的排上面', async () => {
  const soon = new Date(Date.now() + 3600e3).toISOString().slice(0, 19)
  const rows = [
    N({ id: 22, kind: 'task', content: '整理桌面', created_at: '2026-07-08T10:00:00' }),
    N({ id: 21, kind: 'task', content: '帮荣荣姐做龙虾', created_at: '2026-07-08T09:00:00',
      meta: { type: 'text', when: '明晚 20:00', where: '家', due: soon, triage: { by: 'rule', confident: true } } }),
  ]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  await fireEvent.click(screen.getByRole('tab', { name: '任务' }))
  const chip = await screen.findByText('明晚 20:00')
  expect(chip.classList.contains('duesoon')).toBe(true)      // 24h 内=橙
  expect(screen.getByText('@家')).toBeInTheDocument()
  expect(screen.getByText('速记分诊')).toBeInTheDocument()
  // 有时限的沉不到底:龙虾(due)在整理桌面(无 due)前面
  const txs = screen.getAllByTitle('查看详情').map((b) => b.textContent)
  expect(txs[0]).toContain('龙虾')
  // hover 操作按钮存在(CSS 控制显隐)
  expect(screen.getAllByTitle('开始专注做这件事').length).toBe(2)
  expect(screen.getAllByTitle('转为定时任务(交给 agent)').length).toBe(2)
})

it('T3 墙上分诊徽章:想法蓝 tag;任务回执卡带抽取 chips+已入待办→', async () => {
  const rows = [
    N({ id: 31, kind: 'idea', content: '给 notch 加入场动效' }),
    N({ id: 32, kind: 'task', content: '帮荣荣姐做龙虾', meta: { type: 'text', when: '明晚 20:00', where: '家' } }),
  ]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  expect(await screen.findByText('想法')).toBeInTheDocument()
  const receipt = await screen.findByText('已入待办 →')
  expect(receipt).toBeInTheDocument()
  expect(screen.getByText('明晚 20:00')).toBeInTheDocument()
  expect(screen.getByText('@家')).toBeInTheDocument()
  // 点「已入待办 →」跳任务列
  await fireEvent.click(receipt)
  expect(layout.journalFilter).toBe('task')
})

it('T4 每天一篇:天内段落按时间升序渲染(拼一篇)', async () => {
  const rows = [
    N({ id: 2, kind: 'journal', journal_date: '2026-07-08', content: '下午修了 bug', created_at: '2026-07-08T15:00:00' }),
    N({ id: 1, kind: 'journal', journal_date: '2026-07-08', content: '早上定了稿', created_at: '2026-07-08T09:00:00' }),
  ]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  await fireEvent.click(screen.getByRole('tab', { name: '日记' }))
  const morning = await screen.findByText('早上定了稿')
  const afternoon = screen.getByText('下午修了 bug')
  // DOM 顺序:早上段在下午段之前
  expect(morning.compareDocumentPosition(afternoon) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
})

it('反馈修复:「全部」chip 退场,详情页有删除(两击确认)', async () => {
  const rows = [N({ id: 41, content: '点我看详情' })]
  vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(
        (init?.method ?? 'GET') !== 'GET' ? {}
        : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  layout.journalFilter = 'note'
  render(JournalView)
  // 全部 chip 没了,四分类在
  expect(screen.queryByRole('tab', { name: '全部' })).toBeNull()
  for (const t of ['速记', '日记', '任务', '日历']) expect(screen.getByRole('tab', { name: t })).toBeInTheDocument()
  // 打开详情 → 删除两击确认
  const spy = vi.spyOn(notes, 'remove').mockResolvedValue(undefined as never)
  await fireEvent.click(await screen.findByText('点我看详情'))
  const del = await screen.findByRole('button', { name: '删除' })
  await fireEvent.click(del)
  expect(screen.getByRole('button', { name: '确认删除' })).toBeInTheDocument()
  await fireEvent.click(screen.getByRole('button', { name: '确认删除' }))
  expect(spy).toHaveBeenCalledWith(41)
})
