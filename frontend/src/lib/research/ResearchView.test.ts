import { render, screen } from '@testing-library/svelte'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import Research from './Research.svelte'
import { research } from './researchStore.svelte'

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ sessions: [], providers: [] }) }))
})
afterEach(() => {
  vi.restoreAllMocks()
  research.providers = []
  research.providerId = null
  research.sessions = []
  research.current = null
  research.progress = []
  research.status = 'idle'
  research.error = null
})

describe('Research panel', () => {
  it('shows the empty prompt by default', async () => {
    render(Research)
    expect(await screen.findByLabelText('研究问题')).toBeInTheDocument()
    expect(screen.getByText(/输入问题开始一次深度研究/)).toBeInTheDocument()
  })

  it('renders a cited report with numbered citations + sources', async () => {
    research.current = {
      id: 1,
      question: 'is X better than Y?',
      status: 'completed',
      rounds_done: 3,
      error: null,
      created_at: null,
      ended_at: null,
      report: {
        question: 'is X better than Y?',
        summary: 'X wins on cost.',
        claims: [{ text: 'X is cheaper', sources: ['https://a.com', 'https://b.com'] }],
        sources: [
          { url: 'https://a.com', title: 'Source A' },
          { url: 'https://b.com', title: 'Source B' },
        ],
        rounds: 3,
      },
    }
    render(Research)
    expect(await screen.findByText('X wins on cost.')).toBeInTheDocument()
    expect(screen.getByText('X is cheaper')).toBeInTheDocument()
    // citation [1] and [2] link to the two sources
    expect(screen.getByRole('link', { name: '[1]' })).toHaveAttribute('href', 'https://a.com')
    expect(screen.getByRole('link', { name: '[2]' })).toHaveAttribute('href', 'https://b.com')
    expect(screen.getByRole('link', { name: 'Source A' })).toBeInTheDocument()
  })

  it('shows a running progress stream', async () => {
    research.status = 'running'
    research.progress = [{ kind: 'round_start', round: 1 }, { kind: 'synthesize', round: 1 }]
    render(Research)
    // text is split across nodes (kind + "· 第 N 轮"); match on the <li>'s textContent
    expect(
      await screen.findByText(
        (_t, el) => el?.tagName === 'LI' && (el.textContent ?? '').includes('round_start') && el.textContent!.includes('第 1 轮'),
      ),
    ).toBeInTheDocument()
  })
})
