import { afterEach, describe, expect, it, vi } from 'vitest'
import { extractCandidates, resolveCandidates, clearPathLinkCache } from './pathLinks'

afterEach(() => {
  vi.restoreAllMocks()
  clearPathLinkCache()
})

describe('extractCandidates(四层识别)', () => {
  it('URLs win and strip trailing punctuation', () => {
    const c = extractCandidates('see https://example.com/docs), then go')
    expect(c[0]).toMatchObject({ token: 'https://example.com/docs', kind: 'url' })
  })

  it('quoted paths with spaces survive', () => {
    const c = extractCandidates(`wrote '/tmp/my docs/final report.md' ok`)
    expect(c.some((x) => x.token === '/tmp/my docs/final report.md' && x.kind === 'path')).toBe(true)
  })

  it('slash tokens cut at full-width punctuation, trailing 。 stripped', () => {
    const c = extractCandidates('改了 src/lib/a.ts，另见 /abs/b.py。')
    const toks = c.map((x) => x.token)
    expect(toks).toContain('src/lib/a.ts')
    expect(toks).toContain('/abs/b.py')
  })

  it('bare filename needs a whitelisted extension', () => {
    const c = extractCandidates('open README.md but not binary.xyz9')
    const toks = c.map((x) => x.token)
    expect(toks).toContain('README.md')
    expect(toks).not.toContain('binary.xyz9')
  })

  it('trailing slash dirs and --flag=/path forms', () => {
    const c = extractCandidates('cd dist/ && run --out=/tmp/build/')
    const toks = c.map((x) => x.token)
    expect(toks).toContain('dist/')
    expect(toks).toContain('/tmp/build/')
  })

  it('ranges point at the token inside the line', () => {
    const line = 'x /a/b.md y'
    const c = extractCandidates(line).find((t) => t.token === '/a/b.md')!
    expect(line.slice(c.start, c.end)).toBe('/a/b.md')
  })
})

describe('resolveCandidates(服务端验证+缓存)', () => {
  it('batches unknown tokens and caches results', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ resolved: { 'src/a.ts': { path: '/p/src/a.ts', is_dir: false } } }),
    })
    vi.stubGlobal('fetch', fetchMock)
    const r1 = await resolveCandidates('/p', ['src/a.ts', 'missing.py'])
    expect(r1.get('src/a.ts')).toEqual({ path: '/p/src/a.ts', is_dir: false })
    expect(r1.has('missing.py')).toBe(false)
    // 第二次同 cwd 同 token:全命中缓存,不再发请求
    const r2 = await resolveCandidates('/p', ['src/a.ts', 'missing.py'])
    expect(r2.get('src/a.ts')).toBeTruthy()
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })
})
