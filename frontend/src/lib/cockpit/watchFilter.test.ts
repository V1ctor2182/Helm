import { describe, expect, it } from 'vitest'
import { isNoisyChange } from './watchFilter'

describe('isNoisyChange(噪声过滤,FanBox 原样)', () => {
  it('构建/依赖/隐藏目录与点文件算噪声', () => {
    expect(isNoisyChange('node_modules/a/b.js')).toBe(true)
    expect(isNoisyChange('.git/HEAD')).toBe(true)
    expect(isNoisyChange('src/.DS_Store')).toBe(true)
    expect(isNoisyChange('dist/out.js')).toBe(true)
    expect(isNoisyChange('.config/x.json')).toBe(true)
  })

  it('原子写中段 .tmp 与 sqlite sidecar 算噪声', () => {
    expect(isNoisyChange('src/foo.swift.tmp.123.abc')).toBe(true)
    expect(isNoisyChange('data/app.db-journal')).toBe(true)
    expect(isNoisyChange('data/app.db-wal')).toBe(true)
    expect(isNoisyChange('a/b.swp')).toBe(true)
    expect(isNoisyChange('a/b~')).toBe(true)
  })

  it('正常源文件放行', () => {
    expect(isNoisyChange('src/lib/a.ts')).toBe(false)
    expect(isNoisyChange('README.md')).toBe(false)
    expect(isNoisyChange('docs/设计.md')).toBe(false)
  })
})
