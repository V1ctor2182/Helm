import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { describe, expect, it, vi } from 'vitest'
import CanvasView from './CanvasView.svelte'
import type { Note } from './notesStore.svelte'

const N = (over: Partial<Note> = {}): Note => ({
  id: 1, kind: 'note', title: null, content: '一条速记', tags: [], meta: null,
  pinned: false, source: 'user', journal_date: null, created_at: null, updated_at: null,
  ...over,
})

// 2026-07-08 用户反馈修复:canvas 点击开详情/删除入口/下方不遮挡
describe('CanvasView', () => {
  it('点击(没拖)= 开详情', async () => {
    const onopen = vi.fn()
    render(CanvasView, { props: { notes: [N()], onopen, ondelete: vi.fn() } })
    const node = screen.getByText('一条速记').closest('.cnode') as HTMLElement
    await fireEvent.pointerDown(node, { clientX: 100, clientY: 100 })
    await fireEvent.pointerUp(node)
    expect(onopen).toHaveBeenCalledOnce()
  })

  it('拖动后松手=保存位置,不开详情', async () => {
    const onopen = vi.fn()
    render(CanvasView, { props: { notes: [N()], onopen } })
    const node = screen.getByText('一条速记').closest('.cnode') as HTMLElement
    await fireEvent.pointerDown(node, { clientX: 100, clientY: 100 })
    await fireEvent.pointerMove(node, { clientX: 160, clientY: 140 })
    await fireEvent.pointerUp(node)
    expect(onopen).not.toHaveBeenCalled()
  })

  it('× 两击确认删除', async () => {
    const ondelete = vi.fn()
    render(CanvasView, { props: { notes: [N()], ondelete } })
    const x = screen.getByRole('button', { name: '删除 一条速记' })
    await fireEvent.click(x)
    expect(x.textContent).toBe('确认')
    expect(ondelete).not.toHaveBeenCalled()
    await fireEvent.click(x)
    expect(ondelete).toHaveBeenCalledOnce()
  })

  it('画布高度跟最低的卡走(不裁内容)', () => {
    // 7 张卡默认网格散布:第 3 行 y=16+2*235=486 → 高度 486+340=826
    const many = Array.from({ length: 7 }, (_, i) => N({ id: i + 1 }))
    const { container } = render(CanvasView, { props: { notes: many } })
    const canvas = container.querySelector('.canvas') as HTMLElement
    expect(canvas.style.minHeight).toBe('826px')
  })
})
