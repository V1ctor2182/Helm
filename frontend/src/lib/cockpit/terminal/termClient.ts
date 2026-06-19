// Terminal WS protocol helpers (pure, testable). The xterm wiring lives in
// Terminal.svelte (GUI, manual-verify). Protocol mirrors the backend:
//   client → {type:'input',data} / {type:'resize',cols,rows}
//   server → {type:'output',data} / {type:'exit',code}

export type ServerMsg =
  | { type: 'output'; data: string }
  | { type: 'exit'; code: number | null }

export function inputMsg(data: string): string {
  return JSON.stringify({ type: 'input', data })
}

export function resizeMsg(cols: number, rows: number): string {
  return JSON.stringify({ type: 'resize', cols, rows })
}

export function parseServer(raw: string): ServerMsg {
  return JSON.parse(raw) as ServerMsg
}

export function terminalWsUrl(
  loc: { protocol: string; host: string },
  path: string | null,
  cols: number,
  rows: number,
): string {
  const proto = loc.protocol === 'https:' ? 'wss' : 'ws'
  const q = new URLSearchParams()
  if (path) q.set('path', path)
  q.set('cols', String(cols))
  q.set('rows', String(rows))
  return `${proto}://${loc.host}/api/cockpit/terminal/ws?${q}`
}
