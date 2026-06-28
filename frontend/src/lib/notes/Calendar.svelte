<script lang="ts">
  // Calendar lives with journal/tasks (the time/planning cluster). The store
  // still sits under mail/ from the original email-calendar room; mail itself
  // is currently disabled but the calendar capability stands alone.
  import { calendar } from '../mail/calendarStore.svelte'

  let evSummary = $state('')
  let evStart = $state('')
  let showCaldav = $state(false)
  let cdav = $state({ name: '', url: '', username: '', password: '' })

  async function addEvent() {
    if (await calendar.add(evSummary, evStart)) {
      evSummary = ''
      evStart = ''
    }
  }

  async function addCaldav() {
    if (await calendar.addCaldav(cdav)) {
      showCaldav = false
      cdav = { name: '', url: '', username: '', password: '' }
    }
  }

  async function doImport() {
    const text = window.prompt?.('粘贴 .ics 内容')
    if (text) await calendar.importIcs(text)
  }

  async function doExport() {
    const ics = await calendar.exportIcs()
    if (ics && typeof URL.createObjectURL === 'function') {
      const url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' }))
      const a = document.createElement('a')
      a.href = url
      a.download = 'helm-calendar.ics'
      a.click()
      URL.revokeObjectURL(url)
    }
  }
</script>

<div class="cal">
  <div class="tools">
    <button onclick={doImport}>导入 .ics</button>
    <button onclick={doExport} disabled={!calendar.events.length}>导出 .ics</button>
    {#if calendar.caldavAccounts.length}
      <button onclick={() => calendar.syncCaldav()} disabled={calendar.syncing}>
        {calendar.syncing ? 'CalDAV 同步中…' : 'CalDAV 同步'}
      </button>
    {/if}
    <button onclick={() => (showCaldav = !showCaldav)}>+ CalDAV</button>
  </div>

  <form class="addev" onsubmit={(e) => { e.preventDefault(); void addEvent() }}>
    <input placeholder="事件标题" bind:value={evSummary} aria-label="事件标题" />
    <input type="datetime-local" bind:value={evStart} aria-label="开始时间" />
    <button type="submit" disabled={!evSummary.trim() || !evStart}>加事件</button>
  </form>

  {#if showCaldav}
    <form class="addacc" onsubmit={(e) => { e.preventDefault(); void addCaldav() }}>
      <input placeholder="名称" bind:value={cdav.name} aria-label="CalDAV 名称" />
      <input placeholder="CalDAV URL(如 https://caldav.icloud.com)" bind:value={cdav.url} aria-label="CalDAV URL" />
      <input placeholder="用户名" bind:value={cdav.username} aria-label="CalDAV 用户名" />
      <input type="password" placeholder="密码 / 应用专用密码" bind:value={cdav.password} aria-label="CalDAV 密码" />
      <button type="submit" disabled={!cdav.url.trim() || !cdav.password.trim()}>添加(凭据加密存储)</button>
    </form>
  {/if}
  {#if calendar.syncMsg}<p class="cmsg">{calendar.syncMsg}</p>{/if}

  {#if calendar.events.length === 0}
    <p class="empty">还没有日程 — 加一个事件,或导入 .ics。</p>
  {:else}
    <ul class="events">
      {#each calendar.events as ev (ev.id)}
        <li class="event">
          <span class="when">{ev.all_day ? (ev.start?.slice(0, 10) ?? '') : (ev.start?.slice(0, 16).replace('T', ' ') ?? '')}</span>
          <span class="esum">{ev.summary}</span>
          <button class="del" aria-label={`删除 ${ev.summary}`} onclick={() => calendar.remove(ev.id)}>🗑</button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .cal {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .tools {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  .tools button,
  .addacc button {
    border: 1px solid #cfcdd4;
    background: #fff;
    border-radius: 8px;
    padding: 4px 12px;
    cursor: pointer;
    font-size: 0.82rem;
  }
  .addev {
    display: flex;
    gap: 6px;
  }
  .addev input {
    padding: 5px 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .addacc {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    padding: 8px;
    background: #fafafa;
    border-radius: 8px;
  }
  .addacc input {
    padding: 5px 8px;
    border: 1px solid #ddd;
    border-radius: 8px;
    flex: 1;
    min-width: 140px;
  }
  .cmsg {
    font-size: 0.78rem;
    color: #1c7a40;
  }
  .events {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
    overflow: auto;
  }
  .event {
    display: flex;
    gap: 10px;
    align-items: center;
    padding: 5px 8px;
    border: 1px solid #eceaef;
    border-radius: 8px;
    background: #fff;
  }
  .when {
    font-family: ui-monospace, monospace;
    font-size: 0.8rem;
    color: #777;
    flex: none;
  }
  .esum {
    flex: 1;
  }
  .del {
    border: 0;
    background: transparent;
    cursor: pointer;
  }
  .empty {
    color: #aaa;
  }
</style>
