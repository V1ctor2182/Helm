<script lang="ts">
  import Sidebar from './Sidebar.svelte'
  import DockHost from './DockHost.svelte'
  import Lightbox from './Lightbox.svelte'
  import { cockpit } from './cockpit.svelte'
import Resizer from '../Resizer.svelte'

  // 驾驶舱骨架(阶段3.5,用户拍板全模块 docking):固定侧栏 + dock 网格。
  // 文件/预览/终端/Agent 全部是 dock 模块,拖标题 tab 换 zone、吸附、tab 栈,
  // 布局持久化;预览"选中即现"、折叠条等语义都在 DockHost/dock store 里。
</script>

<div class="wrap" style={`grid-template-columns:${cockpit.sidebarOpen ? 'var(--cockpit-side, 200px) ' : ''}minmax(0,1fr)`}>
  {#if cockpit.sidebarOpen}
    <Sidebar />
    <Resizer cssVar="--cockpit-side" storageKey="helm.ui.cockpitSide" min={160} max={360} initial={200}
      style="left:calc(var(--cockpit-side, 200px) - 3px)" />
  {/if}
  <DockHost />
</div>

<Lightbox />

<style>
  .wrap {
    position: relative;
    display: grid;
    height: 100%;
    min-height: 0;
    font-family: var(--sans);
    color: var(--t2);
  }
</style>
