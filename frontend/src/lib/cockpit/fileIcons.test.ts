import { describe, expect, it } from 'vitest'
import { iconFor } from './fileIcons'

describe('iconFor', () => {
  it('folders get the folder icon', () => {
    expect(iconFor({ is_dir: true, ext: '' }).glyph).toBe('📁')
  })

  it('known extensions get strong-color specs', () => {
    expect(iconFor({ is_dir: false, ext: 'pdf' }).color).toBe('#e5484d')
    expect(iconFor({ is_dir: false, ext: 'js' }).glyph).toBe('JS')
    expect(iconFor({ is_dir: false, ext: 'md' }).color).toBe('#4250ff')
  })

  it('unknown extension falls back to generic', () => {
    expect(iconFor({ is_dir: false, ext: 'xyz' }).glyph).toBe('📄')
  })
})
