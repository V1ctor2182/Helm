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

it('T4 每天一篇:今天卡只读展示,点续写开富文本弹窗(预填整篇),保存=整篇替换', async () => {
  const today = (() => {
    const d = new Date(); const p = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
  })()
  const rows = [N({ id: 5, kind: 'journal', journal_date: today, content: '早上定了稿', created_at: `${today}T09:00:00` })]
  vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(
        (init?.method ?? 'GET') !== 'GET' ? {}
        : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  const consolidate = vi.spyOn(notes, 'consolidateJournal').mockResolvedValue(true)
  const create = vi.spyOn(notes, 'create').mockResolvedValue(true)
  render(JournalView)
  await fireEvent.click(screen.getByRole('tab', { name: '日记' }))
  // 今天卡只读展示已有内容(不是 textarea,也没有底部续写输入条)
  await screen.findByText('早上定了稿')
  expect(screen.queryByLabelText('今天的日记')).toBeNull()
  // 点续写 → 富文本弹窗(加粗/斜体/高亮),预填今天整篇
  await fireEvent.click(screen.getByRole('button', { name: '续写' }))
  const editor = (await screen.findByRole('textbox', { name: '内容' })) as HTMLElement
  expect(editor.textContent).toContain('早上定了稿')
  editor.innerHTML = '早上定了稿<br><br>下午又想到一点'
  await fireEvent.input(editor)
  await fireEvent.click(screen.getByRole('button', { name: '保存' }))
  // 整篇替换 → 合并进 id=5,不新建
  expect(consolidate).toHaveBeenCalledWith([5], '早上定了稿\n\n下午又想到一点')
  expect(create).not.toHaveBeenCalled()
})

it('T4:今天没写过时卡是空态,点续写开空弹窗,保存=新建今天一条', async () => {
  vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(
        (init?.method ?? 'GET') !== 'GET' ? {}
        : String(url).includes('/api/notes') ? { notes: [] } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  const create = vi.spyOn(notes, 'create').mockResolvedValue(true)
  render(JournalView)
  await fireEvent.click(screen.getByRole('tab', { name: '日记' }))
  expect(await screen.findByText(/今天还没写/)).toBeInTheDocument()
  await fireEvent.click(screen.getByRole('button', { name: '续写' }))
  const editor = (await screen.findByRole('textbox', { name: '内容' })) as HTMLElement
  editor.innerHTML = '今天第一条'
  await fireEvent.input(editor)
  await fireEvent.click(screen.getByRole('button', { name: '保存' }))
  expect(create).toHaveBeenCalledWith('今天第一条', 'journal', expect.any(String))
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

it('编辑弹层(用户拍板):⋯→编辑打开所见即所得弹层,保存回写 md', async () => {
  const rows = [N({ id: 51, content: '改我这条' })]
  vi.stubGlobal('fetch', vi.fn((url: string, init?: RequestInit) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(
        (init?.method ?? 'GET') !== 'GET' ? {}
        : String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  const spy = vi.spyOn(notes, 'update').mockResolvedValue(true)
  render(JournalView)
  await fireEvent.click(await screen.findByRole('button', { name: '更多操作 改我这条' }))
  await fireEvent.click(screen.getByRole('menuitem', { name: '编辑' }))
  const dialog = await screen.findByRole('dialog', { name: '编辑记录' })
  expect(dialog).toBeInTheDocument()
  // 工具栏三钮在
  for (const b of ['粗体', '斜体', '高亮']) expect(screen.getByRole('button', { name: b })).toBeInTheDocument()
  // 编辑内容(所见即所得:DOM 里是 <b>,存储回 md)
  const editor = screen.getByRole('textbox', { name: '内容' })
  editor.innerHTML = '改成<b>加粗</b>的'
  await fireEvent.input(editor)
  await fireEvent.click(screen.getByRole('button', { name: '保存' }))
  expect(spy).toHaveBeenCalledWith(51, '改成**加粗**的')
})

it('卡片轻渲染:**粗** 显示为加粗而不是星号', async () => {
  const rows = [N({ id: 52, content: '有**重点**的速记' })]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  const strong = await screen.findByText('重点')
  expect(strong.tagName).toBe('B')
  expect(screen.queryByText(/\*\*/)).toBeNull()
})

it('F1 链接分类:family 决定 badge 色/名,label 显示精确类别 chip', async () => {
  const rows = [
    N({ id: 61, content: 'x https://linkedin.com/jobs/1',
      meta: { type: 'article', family: 'link', label: '招聘', title: '后端工程师', url: 'https://linkedin.com/jobs/1' } }),
    N({ id: 62, content: 'v https://bilibili.com/v',
      meta: { type: 'article', family: 'video', label: '视频', title: '布局教程', url: 'https://bilibili.com/v' } }),
  ]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  // 招聘链接:family=link → badge「链接」;label「招聘」单独 chip(与族名不同才显示)
  expect(await screen.findByText('链接')).toBeInTheDocument()
  expect(screen.getByText('招聘')).toBeInTheDocument()
  // bilibili 视频:family=video → badge「视频」;label 也是「视频」→ 不重复显示 chip
  expect(screen.getByText('视频')).toBeInTheDocument()
})

it('F1 兼容:老数据只有 type、无 family 时按 type 推 family', async () => {
  const rows = [N({ id: 63, content: 'yt https://youtu.be/x',
    meta: { type: 'youtube', title: '老视频卡', url: 'https://youtu.be/x' } })]
  vi.stubGlobal('fetch', vi.fn((url: string) =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(String(url).includes('/api/notes') ? { notes: rows } : { notes: [], tasks: [], links: [], events: [] }),
    }),
  ))
  render(JournalView)
  // type=youtube 无 family → 推 video 族 → badge「视频」(不再是旧的 YT/WEB)
  expect(await screen.findByText('视频')).toBeInTheDocument()
})
