import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it } from 'vitest'
import CommandPalette from './CommandPalette.svelte'
import { layout } from './layout.svelte'

afterEach(() => {
  layout.closePalette()
  layout.setMode('today')
})

describe('CommandPalette', () => {
  it('renders nothing when closed', () => {
    render(CommandPalette)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('shows commands when open and filters by query', async () => {
    layout.openPalette()
    render(CommandPalette)
    expect(screen.getByRole('dialog')).toBeInTheDocument()

    const input = screen.getByLabelText('命令')
    await fireEvent.input(input, { target: { value: 'chat' } })
    const options = screen.getAllByRole('option')
    expect(options.length).toBe(1)
    expect(options[0]).toHaveTextContent('Go to Chat')
  })

  it('Enter runs the selected command and closes the palette', async () => {
    layout.openPalette()
    render(CommandPalette)
    const input = screen.getByLabelText('命令')
    await fireEvent.input(input, { target: { value: 'chat' } })
    await fireEvent.keyDown(input, { key: 'Enter' })
    expect(layout.mode).toBe('chat')
    expect(layout.paletteOpen).toBe(false)
  })

  it('Escape closes the palette', async () => {
    layout.openPalette()
    render(CommandPalette)
    const input = screen.getByLabelText('命令')
    await fireEvent.keyDown(input, { key: 'Escape' })
    expect(layout.paletteOpen).toBe(false)
  })
})
