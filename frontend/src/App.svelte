<script lang="ts">
  import { onMount } from 'svelte'
  import Shell from './lib/Shell.svelte'
  import { notes } from './lib/notes/notesStore.svelte'

  let backendStatus = $state('connecting…')

  onMount(() => {
    notes.wireCapture() // ⌘N quick captures persist to /api/notes
    void check()
  })

  async function check() {
    try {
      const res = await fetch('/healthz')
      const body = await res.json()
      backendStatus = `backend ok · v${body.version}`
    } catch {
      backendStatus = 'backend unreachable'
    }
  }
</script>

<Shell {backendStatus} />
