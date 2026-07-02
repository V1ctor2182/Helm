import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it } from 'vitest'
import Lightbox from './Lightbox.svelte'
import { cockpit } from './cockpit.svelte'

afterEach(() => {
  cockpit.lightboxPath = null
})

describe('Lightbox(灯箱)', () => {
  it('renders raw for native formats, thumb for heic; Esc closes', async () => {
    cockpit.lightboxPath = '/p/photo.jpg'
    render(Lightbox)
    const img = screen.getByRole('dialog').querySelector('img')!
    expect(img.getAttribute('src')).toContain('/api/cockpit/raw')
    cockpit.lightboxPath = '/p/shot.heic'
    await Promise.resolve()
    await fireEvent.keyDown(window, { key: 'Escape' })
    expect(cockpit.lightboxPath).toBeNull()
  })

  it('wheel zooms within 0.2-8x (FanBox 公式)', async () => {
    cockpit.lightboxPath = '/p/photo.png'
    render(Lightbox)
    const dlg = screen.getByRole('dialog')
    await fireEvent.wheel(dlg, { deltaY: -500 }) // scale 1 + 1.0 → 2
    const img = dlg.querySelector('img') as HTMLImageElement
    expect(img.style.transform).toBe('scale(2)')
    await fireEvent.wheel(dlg, { deltaY: -100000 })
    expect(img.style.transform).toBe('scale(8)') // clamp 上限
    await fireEvent.wheel(dlg, { deltaY: 100000 })
    expect(img.style.transform).toBe('scale(0.2)') // clamp 下限
  })

  it('clicking the blank overlay closes; clicking the image does not', async () => {
    cockpit.lightboxPath = '/p/photo.png'
    render(Lightbox)
    const dlg = screen.getByRole('dialog')
    await fireEvent.click(dlg.querySelector('img')!)
    expect(cockpit.lightboxPath).toBe('/p/photo.png')
    await fireEvent.click(dlg)
    expect(cockpit.lightboxPath).toBeNull()
  })
})
