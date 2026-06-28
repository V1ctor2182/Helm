<script lang="ts">
  import { onMount } from 'svelte'
  import { mail } from './mailStore.svelte'
  import { calendar } from './calendarStore.svelte'

  let panel = $state<'mail' | 'calendar'>('mail')
  let showAdd = $state(false)
  let acc = $state({ name: '', email_addr: '', imap_host: '', username: '', password: '' })
  let evSummary = $state('')
  let evStart = $state('')
  let showCaldav = $state(false)
  let cdav = $state({ name: '', url: '', username: '', password: '' })

  async function addCaldav() {
    if (await calendar.addCaldav(cdav)) {
      showCaldav = false
      cdav = { name: '', url: '', username: '', password: '' }
    }
  }

  onMount(() => {
    void mail.loadAccounts()
    void mail.loadEmails()
    void mail.loadProviders()
    void calendar.load()
    void calendar.loadCaldav()
  })

  async function addEvent() {
    if (await calendar.add(evSummary, evStart)) {
      evSummary = ''
      evStart = ''
    }
  }

  async function doImport() {
    const text = window.prompt?.('粘贴 .ics 内容')
    if (text) await calendar.importIcs(text)
  }

  async function toEvent(id: number) {
    const when = window.prompt?.('事件时间 (YYYY-MM-DDTHH:MM)', new Date().toISOString().slice(0, 16))
    if (when) await mail.toEvent(id, when)
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

  async function addAccount() {
    const ok = await mail.addAccount(acc)
    if (ok) {
      showAdd = false
      acc = { name: '', email_addr: '', imap_host: '', username: '', password: '' }
    }
  }

  const urgencyIcon: Record<string, string> = { high: '🔴', medium: '🟡', low: '⚪' }
</script>

<section class="mail" aria-label="邮件 / 日历">
  <header>
    <div class="seg" role="tablist" aria-label="邮件 / 日历">
      <button role="tab" aria-selected={panel === 'mail'} class:active={panel === 'mail'} onclick={() => (panel = 'mail')}>✉ 邮件</button>
      <button role="tab" aria-selected={panel === 'calendar'} class:active={panel === 'calendar'} onclick={() => (panel = 'calendar')}>📅 日历</button>
    </div>
    {#if panel === 'mail'}
      <div class="tools">
        <button onclick={() => mail.sync()} disabled={mail.syncing || !mail.accounts.length}>
          {mail.syncing ? '收取中…' : '收取'}
        </button>
        <button onclick={() => (showAdd = !showAdd)}>+ 账户</button>
      </div>
    {:else}
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
    {/if}
  </header>

  {#if panel === 'calendar'}
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
  {:else}

  {#if mail.error}<p class="err" role="alert">{mail.error}</p>{/if}

  {#if showAdd || mail.accounts.length === 0}
    <form
      class="addacc"
      onsubmit={(e) => {
        e.preventDefault()
        void addAccount()
      }}
    >
      <input placeholder="名称" bind:value={acc.name} aria-label="账户名称" />
      <input placeholder="邮箱地址" bind:value={acc.email_addr} aria-label="邮箱地址" />
      <input placeholder="IMAP 主机(如 imap.gmail.com)" bind:value={acc.imap_host} aria-label="IMAP 主机" />
      <input placeholder="用户名" bind:value={acc.username} aria-label="用户名" />
      <input type="password" placeholder="密码 / 应用专用密码" bind:value={acc.password} aria-label="密码" />
      <button type="submit" disabled={!acc.imap_host.trim() || !acc.password.trim()}>添加(凭据加密存储)</button>
    </form>
  {/if}

  <div class="split">
    <ul class="inbox" aria-label="收件箱">
      {#if mail.emails.length === 0}
        <li class="empty">收件箱为空 — 添加账户并「收取」。</li>
      {:else}
        {#each mail.emails as e (e.id)}
          <li>
            <button class="row" class:unread={e.unread} class:active={mail.current?.id === e.id} onclick={() => mail.openEmail(e.id)}>
              <span class="badge">{e.triage ? urgencyIcon[e.triage.urgency] ?? '⚪' : (e.unread ? '•' : '')}</span>
              <span class="meta">
                <span class="subj">{e.subject || '(无主题)'}</span>
                <span class="from">{e.from_addr}</span>
              </span>
              {#if e.triage?.is_spam}<span class="spam">垃圾</span>{/if}
            </button>
          </li>
        {/each}
      {/if}
    </ul>

    <div class="detail">
      {#if !mail.current}
        <p class="empty">选择一封邮件查看。</p>
      {:else}
        {@const e = mail.current}
        <h3>{e.subject || '(无主题)'}</h3>
        <p class="dfrom">{e.from_addr}</p>
        {#if e.triage}
          <div class="triage">
            <span class="urg urg-{e.triage.urgency}">{urgencyIcon[e.triage.urgency] ?? ''} {e.triage.urgency}</span>
            <span class="sum">{e.triage.summary}</span>
            {#each e.triage.labels as l (l)}<span class="lbl">{l}</span>{/each}
          </div>
          {#if e.triage.draft}
            <div class="draft">
              <h4>回复草稿</h4>
              <p>{e.triage.draft}</p>
            </div>
          {/if}
        {:else}
          <button class="tri" onclick={() => mail.triage(e.id)} disabled={mail.triaging}>
            {mail.triaging ? 'AI 分诊中…' : '✨ AI 分诊'}
          </button>
        {/if}
        <div class="conv">
          <button onclick={() => mail.toMemory(e.id)}>→记忆</button>
          <button onclick={() => mail.toTask(e.id)}>→任务</button>
          <button onclick={() => toEvent(e.id)}>→日程</button>
          {#if mail.convertMsg}<span class="cmsg">{mail.convertMsg}</span>{/if}
        </div>
        <pre class="body">{e.body}</pre>
      {/if}
    </div>
  </div>
  {/if}
</section>

<style>
  .mail {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    padding: 12px;
    gap: 8px;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .seg {
    display: flex;
    gap: 4px;
  }
  .seg button {
    border: 1px solid #e5e4e7;
    background: #f4f3f5;
    border-radius: 999px;
    padding: 3px 12px;
    cursor: pointer;
    font-size: 0.85rem;
  }
  .seg button.active {
    background: #fff;
    font-weight: 600;
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
  .conv {
    display: flex;
    gap: 6px;
    align-items: center;
    margin: 8px 0;
  }
  .conv button {
    border: 1px solid #e5e4e7;
    background: #f7f6f8;
    border-radius: 6px;
    padding: 3px 10px;
    cursor: pointer;
    font-size: 0.78rem;
  }
  .cmsg {
    font-size: 0.78rem;
    color: #1c7a40;
  }
  .tools {
    display: flex;
    gap: 6px;
  }
  .tools button,
  .tri,
  .addacc button {
    border: 1px solid #cfcdd4;
    background: #fff;
    border-radius: 8px;
    padding: 4px 12px;
    cursor: pointer;
    font-size: 0.82rem;
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
  .split {
    display: grid;
    grid-template-columns: minmax(220px, 0.9fr) minmax(260px, 1.4fr);
    flex: 1;
    min-height: 0;
    gap: 8px;
  }
  .inbox {
    list-style: none;
    margin: 0;
    padding: 0;
    overflow: auto;
    border-right: 1px solid #eee;
  }
  .row {
    display: flex;
    gap: 8px;
    align-items: center;
    width: 100%;
    text-align: left;
    border: 0;
    background: transparent;
    padding: 6px 8px;
    cursor: pointer;
    border-bottom: 1px solid #f2f1f4;
  }
  .row.active {
    background: #eef;
  }
  .row.unread .subj {
    font-weight: 700;
  }
  .badge {
    flex: none;
    width: 16px;
    text-align: center;
  }
  .meta {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .subj {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .from {
    font-size: 0.75rem;
    color: #999;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .spam {
    font-size: 0.66rem;
    color: #c0392b;
    margin-left: auto;
  }
  .detail {
    overflow: auto;
    min-width: 0;
  }
  .dfrom {
    color: #888;
    font-size: 0.85rem;
    margin: 2px 0 8px;
  }
  .triage {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
    padding: 6px 8px;
    background: #f7f6fb;
    border-radius: 8px;
  }
  .urg-high {
    color: #c0392b;
  }
  .urg-medium {
    color: #9a6b00;
  }
  .sum {
    font-size: 0.9rem;
  }
  .lbl {
    font-size: 0.7rem;
    background: #ece9f6;
    border-radius: 999px;
    padding: 1px 8px;
    color: #6b5fa3;
  }
  .draft {
    margin-top: 8px;
    padding: 8px;
    border-left: 3px solid #cfcdef;
    background: #fafaff;
  }
  .draft h4 {
    margin: 0 0 4px;
    font-size: 0.8rem;
  }
  .body {
    white-space: pre-wrap;
    word-break: break-word;
    font-family: inherit;
    margin-top: 10px;
    color: #333;
  }
  .err {
    color: #c0392b;
    font-size: 0.85rem;
  }
  .empty {
    color: #aaa;
    padding: 10px;
  }
</style>
