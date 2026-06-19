import { render, screen } from '@testing-library/svelte'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App.svelte'

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        json: () => Promise.resolve({ status: 'ok', version: '0.0.1' }),
      }),
    )
  })

  it('renders the shell with the mode rail', () => {
    render(App)
    expect(screen.getByRole('button', { name: 'Today' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Chat' })).toBeInTheDocument()
  })

  it('shows backend status from /healthz', async () => {
    render(App)
    expect(await screen.findByText(/backend ok · v0\.0\.1/)).toBeInTheDocument()
  })
})
