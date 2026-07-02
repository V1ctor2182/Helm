import { describe, expect, it } from 'vitest'
import {inputMsg, parseServer, resizeMsg, terminalWsUrl, shQuote, dropPath } from './termClient'

describe('termClient protocol', () => {
  it('inputMsg / resizeMsg encode the wire format', () => {
    expect(JSON.parse(inputMsg('ls\n'))).toEqual({ type: 'input', data: 'ls\n' })
    expect(JSON.parse(resizeMsg(120, 30))).toEqual({ type: 'resize', cols: 120, rows: 30 })
  })

  it('parseServer parses output/exit', () => {
    expect(parseServer('{"type":"output","data":"hi"}')).toEqual({
      type: 'output',
      data: 'hi',
    })
    expect(parseServer('{"type":"exit","code":0}')).toEqual({ type: 'exit', code: 0 })
  })

  it('terminalWsUrl builds ws/wss with path + size', () => {
    expect(
      terminalWsUrl({ protocol: 'http:', host: '127.0.0.1:8769' }, '/p roj', 80, 24),
    ).toBe('ws://127.0.0.1:8769/api/cockpit/terminal/ws?path=%2Fp+roj&cols=80&rows=24')
    expect(
      terminalWsUrl({ protocol: 'https:', host: 'x' }, null, 100, 40),
    ).toBe('wss://x/api/cockpit/terminal/ws?cols=100&rows=40')
  })
})

describe('拖拽进终端(shQuote/dropPath)', () => {
  it('shQuote 单引号转义:空格/引号/中文都安全', () => {
    expect(shQuote('/a/b c.md')).toBe("'/a/b c.md'")
    expect(shQuote("/a/it's.md")).toBe("'/a/it'\\''s.md'")
    expect(shQuote('/项目/设计稿.png')).toBe("'/项目/设计稿.png'")
  })

  it('dropPath 自家类型优先,text/plain 兜底', () => {
    const dt = (data: Record<string, string>) =>
      ({ getData: (k: string) => data[k] ?? '' }) as unknown as DataTransfer
    expect(dropPath(dt({ 'application/x-helm-path': '/a/b', 'text/plain': '/x' }))).toBe('/a/b')
    expect(dropPath(dt({ 'text/plain': '/only/plain' }))).toBe('/only/plain')
    expect(dropPath(dt({}))).toBeNull()
    expect(dropPath(null)).toBeNull()
  })
})

