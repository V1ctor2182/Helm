import { describe, expect, it } from 'vitest'
import { inputMsg, parseServer, resizeMsg, terminalWsUrl } from './termClient'

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
