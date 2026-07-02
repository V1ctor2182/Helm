<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import { Terminal } from '@xterm/xterm'
  import { FitAddon } from '@xterm/addon-fit'
  import '@xterm/xterm/css/xterm.css'
  import { cockpit } from '../cockpit.svelte'
  import { layout } from '../../layout.svelte'
  import { inputMsg, parseServer, resizeMsg, terminalWsUrl } from './termClient'
  import { extractCandidates, resolveCandidates } from './pathLinks'

  let el = $state<HTMLDivElement>()
  let term: Terminal | undefined
  let ws: WebSocket | undefined
  let fit: FitAddon | undefined

  function send(msg: string) {
    if (ws && ws.readyState === WebSocket.OPEN) ws.send(msg)
  }

  function onWindowResize() {
    fit?.fit()
    if (term) send(resizeMsg(term.cols, term.rows))
  }

  // 折行拼回:从 lineNo 所在的逻辑行(向上找非 isWrapped 起点、向下吃 isWrapped)
  // 拼出整行文本;字符 index ↔ (row,col) 按 cols 整除映射(中间行都是满宽)。
  function logicalLine(lineNo0: number): { text: string; firstRow: number } | null {
    if (!term) return null
    const buf = term.buffer.active
    let first = lineNo0
    while (first > 0 && buf.getLine(first)?.isWrapped) first--
    let text = ''
    let r = first
    for (;;) {
      const l = buf.getLine(r)
      if (!l) break
      if (r !== first && !l.isWrapped) break
      const next = buf.getLine(r + 1)
      const isLast = !next || !next.isWrapped
      text += l.translateToString(isLast)
      r++
      if (isLast) break
    }
    return { text, firstRow: first }
  }

  async function provideLinks(lineNo: number, cb: (links: import('@xterm/xterm').ILink[] | undefined) => void) {
    if (!term) return cb(undefined)
    const logical = logicalLine(lineNo - 1)
    if (!logical) return cb(undefined)
    const cands = extractCandidates(logical.text)
    if (!cands.length) return cb(undefined)
    const pathToks = cands.filter((c) => c.kind === 'path').map((c) => c.token)
    const resolved = pathToks.length ? await resolveCandidates(cockpit.cwd, pathToks) : new Map()
    const cols = term.cols
    const links: import('@xterm/xterm').ILink[] = []
    for (const c of cands) {
      const hit = c.kind === 'path' ? resolved.get(c.token) : null
      if (c.kind === 'path' && !hit) continue // 宽进严出:验证过才划线
      // 逻辑行 index → 终端 1-based (row,col);只给出现在本物理行的链接
      const startRow = logical.firstRow + Math.floor(c.start / cols)
      const endRow = logical.firstRow + Math.floor((c.end - 1) / cols)
      if (lineNo - 1 < startRow || lineNo - 1 > endRow) continue
      links.push({
        range: {
          start: { x: (c.start % cols) + 1, y: startRow + 1 },
          end: { x: ((c.end - 1) % cols) + 1, y: endRow + 1 },
        },
        text: c.token,
        activate: () => {
          if (c.kind === 'url') {
            window.open(c.token, '_blank', 'noopener')
          } else if (hit) {
            layout.setMode('cockpit')
            cockpit.openPath(hit.path, hit.is_dir)
          }
        },
      })
    }
    cb(links.length ? links : undefined)
  }

  onMount(() => {
    term = new Terminal({ fontSize: 13, cursorBlink: true, convertEol: false })
    fit = new FitAddon()
    term.loadAddon(fit)
    term.registerLinkProvider({
      provideLinks: (lineNo, cb) => void provideLinks(lineNo, cb),
    })
    if (el) term.open(el)
    fit.fit()

    ws = new WebSocket(terminalWsUrl(window.location, cockpit.cwd, term.cols, term.rows))
    ws.onopen = () => term && send(resizeMsg(term.cols, term.rows))
    ws.onmessage = (e) => {
      const m = parseServer(e.data as string)
      if (m.type === 'output') term?.write(m.data)
      else if (m.type === 'exit') term?.write(`\r\n[process exited: ${m.code}]\r\n`)
    }
    term.onData((d) => send(inputMsg(d)))
    window.addEventListener('resize', onWindowResize)
  })

  onDestroy(() => {
    window.removeEventListener('resize', onWindowResize)
    ws?.close()
    term?.dispose()
  })
</script>

<div class="term" bind:this={el}></div>

<style>
  .term {
    height: 100%;
    width: 100%;
    background: #1e1e1e;
  }
  .term :global(.xterm) {
    height: 100%;
    padding: 6px;
  }
</style>
