import { render, screen } from '@testing-library/svelte'
import { fireEvent } from '@testing-library/dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { SkillsStore } from './skillsStore.svelte'
import Skills from './Skills.svelte'
import { skills } from './skillsStore.svelte'

const ok = (body: unknown) => ({ ok: true, json: () => Promise.resolve(body) })
const SK = (over: Record<string, unknown> = {}) => ({
  name: 'alpha',
  description: 'an alpha skill',
  path: '/root/alpha',
  healthy: true,
  error: null,
  enabled: true,
  uses: 0,
  last_used: null,
  ...over,
})

afterEach(() => {
  vi.restoreAllMocks()
  skills.skills = []
  skills.total = 0
  skills.healthy = 0
  skills.unhealthy = 0
  skills.error = null
})

describe('SkillsStore', () => {
  it('load populates skills + counts', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(ok({ skills: [SK()], total: 1, healthy: 1, unhealthy: 0 })))
    const s = new SkillsStore()
    await s.load()
    expect(s.skills).toHaveLength(1)
    expect(s.healthy).toBe(1)
  })

  it('toggle posts the flipped enabled flag and reloads', async () => {
    const fetchMock = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve(ok({ skills: [], total: 0, healthy: 0, unhealthy: 0 })),
    )
    vi.stubGlobal('fetch', fetchMock)
    const s = new SkillsStore()
    await s.toggle(SK({ name: 'alpha', enabled: true }))
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'POST')
    expect(post![0]).toContain('/api/skills/alpha/enabled')
    expect(JSON.parse((post![1] as RequestInit).body as string)).toEqual({ enabled: false })
  })
})

describe('Skills panel', () => {
  it('renders skills with health + usage; empty state otherwise', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        ok({ skills: [SK({ uses: 3 }), SK({ name: 'broken', healthy: false, error: 'missing description', description: '' })], total: 2, healthy: 1, unhealthy: 1 }),
      ),
    )
    render(Skills)
    expect(await screen.findByText('alpha')).toBeInTheDocument()
    expect(screen.getByText(/触发 3 次/)).toBeInTheDocument()
    expect(screen.getByText('broken')).toBeInTheDocument()
    expect(screen.getByText(/1 异常/)).toBeInTheDocument()
  })
})
