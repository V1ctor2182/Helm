import { afterEach, describe, expect, it, vi } from 'vitest'
import { fetchDiff, langForExt } from './gitClient'

afterEach(() => vi.restoreAllMocks())

describe('langForExt', () => {
  it('maps known extensions to Monaco languages', () => {
    expect(langForExt('ts')).toBe('typescript')
    expect(langForExt('PY')).toBe('python')
    expect(langForExt('md')).toBe('markdown')
  })
  it('unknown → plaintext', () => {
    expect(langForExt('zzz')).toBe('plaintext')
  })
})

describe('fetchDiff', () => {
  it('returns the diff body on 200', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ head: 'a', working: 'b', status: 'modified' }),
      }),
    )
    const d = await fetchDiff('/p/a.py')
    expect(d?.head).toBe('a')
    expect(d?.status).toBe('modified')
  })
  it('returns null when not in a repo (404)', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false }))
    expect(await fetchDiff('/p/loose.txt')).toBeNull()
  })
})
