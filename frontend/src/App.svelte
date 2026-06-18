<script lang="ts">
  import { onMount } from 'svelte'

  // m1 skeleton: prove the Svelte app renders in the shell and can reach the
  // backend. The real three-pane layout (Rail + panels + tabs) arrives in m2.
  let status = $state('connecting…')

  onMount(() => {
    void check()
  })

  async function check() {
    try {
      const res = await fetch('/healthz')
      const body = await res.json()
      status = `backend ok · v${body.version}`
    } catch {
      status = 'backend unreachable'
    }
  }
</script>

<main>
  <h1>Helm</h1>
  <p class="status">{status}</p>
</main>

<style>
  main {
    height: 100vh;
    display: grid;
    place-items: center;
    font-family: -apple-system, system-ui, sans-serif;
    color: #222;
  }
  h1 {
    font-weight: 600;
    margin: 0 0 0.25rem;
    letter-spacing: 0.02em;
  }
  .status {
    color: #888;
    font-size: 0.9rem;
  }
</style>
