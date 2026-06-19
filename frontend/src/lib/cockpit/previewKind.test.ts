import { describe, expect, it } from 'vitest'
import { previewKind, rawUrl } from './previewKind'

describe('previewKind', () => {
  it('maps known categories', () => {
    expect(previewKind('md')).toBe('markdown')
    expect(previewKind('pdf')).toBe('pdf')
    expect(previewKind('zip')).toBe('zip')
    expect(previewKind('png')).toBe('image')
    expect(previewKind('py')).toBe('code')
    expect(previewKind('ts')).toBe('code')
  })

  it('unknown ext → none', () => {
    expect(previewKind('exe')).toBe('none')
    expect(previewKind('')).toBe('none')
  })
})

describe('rawUrl', () => {
  it('encodes the path', () => {
    expect(rawUrl('/a b/c.png')).toBe('/api/cockpit/raw?path=%2Fa%20b%2Fc.png')
  })
})
