import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import QuickCapture from './QuickCapture.svelte'
import { layout } from './layout.svelte'
import { capture } from './capture.svelte'

afterEach(() => layout.closeCapture())

describe('QuickCapture', () => {
  it('renders nothing when closed', () => {
    render(QuickCapture)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('Enter saves the capture and closes', async () => {
    layout.openCapture()
    render(QuickCapture)
    const ta = screen.getByLabelText('速记内容')
    await fireEvent.input(ta, { target: { value: 'remember this' } })
    await fireEvent.keyDown(ta, { key: 'Enter' })

    expect(capture.items[0].text).toBe('remember this')
    // close happens a microtask after the awaited submit
    await vi.waitFor(() => expect(layout.captureOpen).toBe(false))
  })

  it('Escape closes without saving', async () => {
    const before = capture.items.length
    layout.openCapture()
    render(QuickCapture)
    const ta = screen.getByLabelText('速记内容')
    await fireEvent.input(ta, { target: { value: 'discard me' } })
    await fireEvent.keyDown(ta, { key: 'Escape' })

    expect(layout.captureOpen).toBe(false)
    expect(capture.items.length).toBe(before)
  })
})
