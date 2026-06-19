<script lang="ts">
  import FileBrowser from './FileBrowser.svelte'
  import PreviewPane from './PreviewPane.svelte'
</script>

<div class="split">
  <div class="left"><FileBrowser /></div>
  <div class="right"><PreviewPane /></div>
</div>

<style>
  .split {
    display: grid;
    grid-template-columns: minmax(260px, 1fr) minmax(280px, 1.2fr);
    height: 100%;
    min-height: 0;
  }
  .left,
  .right {
    min-height: 0;
    min-width: 0;
  }
</style>
