<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import { Terminal } from '@xterm/xterm'
  import { FitAddon } from '@xterm/addon-fit'
  import '@xterm/xterm/css/xterm.css'
  import { cockpit } from '../cockpit.svelte'
  import { inputMsg, parseServer, resizeMsg, terminalWsUrl } from './termClient'

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

  onMount(() => {
    term = new Terminal({ fontSize: 13, cursorBlink: true, convertEol: false })
    fit = new FitAddon()
    term.loadAddon(fit)
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
