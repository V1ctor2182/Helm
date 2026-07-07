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
  it('lists quick notes with convert actions', async () => {
    notes.notes = [N({ id: 7, content: 'buy milk' })]
    render(JournalView)
    expect(await screen.findByText('buy milk')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '→日记' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '→记忆' })).toBeInTheDocument()
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
    notes.notes = [N({ id: 9, content: 'convert me' })]
    render(JournalView)
    await fireEvent.click(await screen.findByRole('button', { name: '→日记' }))
    expect(spy).toHaveBeenCalledWith(9)
  })

  it('shows empty states', async () => {
    render(JournalView)
    expect(await screen.findByText(/还没有速记/)).toBeInTheDocument()
  })

  it('→任务 jumps to the tasks tab with the note pinned', async () => {
    notes.notes = [N({ id: 11, content: 'summarize inbox daily' })]
    render(JournalView)
    await fireEvent.click(await screen.findByRole('button', { name: '→任务' }))
    // tasks tab is now active, prompt prefilled from the note and locked
    expect(screen.getByRole('tab', { name: '任务' })).toHaveAttribute('aria-selected', 'true')
    const prompt = screen.getByLabelText('任务指令') as HTMLInputElement
    expect(prompt.value).toBe('summarize inbox daily')
    expect(prompt).toHaveAttribute('readonly')
    expect(screen.getByText(/自速记 #11/)).toBeInTheDocument()
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
