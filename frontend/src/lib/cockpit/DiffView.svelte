<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import * as monaco from 'monaco-editor'
  import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker'
  import { fetchDiff, langForExt } from './gitClient'

  let { path, ext = '' }: { path: string; ext?: string } = $props()

  let el = $state<HTMLDivElement>()
  let message = $state('加载 diff…')
  let editor: monaco.editor.IStandaloneDiffEditor | undefined
  let models: monaco.editor.ITextModel[] = []

  // Monaco needs its editor worker; set once. (Diff computation runs there.)
  const env = self as unknown as { MonacoEnvironment?: monaco.Environment }
  if (!env.MonacoEnvironment) {
    env.MonacoEnvironment = { getWorker: () => new EditorWorker() }
  }

  onMount(async () => {
    const d = await fetchDiff(path)
    if (!el) return
    if (!d) {
      message = '该文件不在 git 仓库中'
      return
    }
    message = ''
    const lang = langForExt(ext || (path.split('.').pop() ?? ''))
    editor = monaco.editor.createDiffEditor(el, {
      readOnly: true,
      automaticLayout: true,
      renderSideBySide: true,
    })
    const original = monaco.editor.createModel(d.head, lang)
    const modified = monaco.editor.createModel(d.working, lang)
    models = [original, modified]
    editor.setModel({ original, modified })
  })

  onDestroy(() => {
    editor?.dispose()
    models.forEach((m) => m.dispose()) // models aren't freed by editor.dispose()
  })
</script>

{#if message}<p class="msg">{message}</p>{/if}
<div class="diff" bind:this={el}></div>

<style>
  .diff {
    height: 100%;
    width: 100%;
    min-height: 200px;
  }
  .msg {
    color: #999;
    padding: 12px;
  }
</style>
