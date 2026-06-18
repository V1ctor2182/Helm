import { describe, expect, it, vi } from 'vitest'
import { CaptureStore } from './capture.svelte'

describe('CaptureStore', () => {
  it('submit adds a trimmed item and returns true', async () => {
    const c = new CaptureStore()
    const ok = await c.submit('  hello  ')
    expect(ok).toBe(true)
    expect(c.items.length).toBe(1)
    expect(c.items[0].text).toBe('hello')
  })

  it('ignores empty / whitespace-only input', async () => {
    const c = new CaptureStore()
    expect(await c.submit('   ')).toBe(false)
    expect(c.items.length).toBe(0)
  })

  it('newest item is first', async () => {
    const c = new CaptureStore()
    await c.submit('a')
    await c.submit('b')
    expect(c.items.map((i) => i.text)).toEqual(['b', 'a'])
  })

  it('calls the registered persister with the text (F6 seam)', async () => {
    const c = new CaptureStore()
    const persist = vi.fn()
    c.setPersister(persist)
    await c.submit('note')
    expect(persist).toHaveBeenCalledWith('note')
  })
})
