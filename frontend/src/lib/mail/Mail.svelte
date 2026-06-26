<script lang="ts">
  import { onMount } from 'svelte'
  import { mail } from './mailStore.svelte'

  let showAdd = $state(false)
  let acc = $state({ name: '', email_addr: '', imap_host: '', username: '', password: '' })

  onMount(() => {
    void mail.loadAccounts()
    void mail.loadEmails()
    void mail.loadProviders()
  })

  async function addAccount() {
    const ok = await mail.addAccount(acc)
    if (ok) {
      showAdd = false
      acc = { name: '', email_addr: '', imap_host: '', username: '', password: '' }
    }
  }

  const urgencyIcon: Record<string, string> = { high: '🔴', medium: '🟡', low: '⚪' }
</script>

<section class="mail" aria-label="邮件">
  <header>
    <h2>✉ 邮件</h2>
    <div class="tools">
      <button onclick={() => mail.sync()} disabled={mail.syncing || !mail.accounts.length}>
        {mail.syncing ? '收取中…' : '收取'}
      </button>
      <button onclick={() => (showAdd = !showAdd)}>+ 账户</button>
    </div>
  </header>

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
        <pre class="body">{e.body}</pre>
      {/if}
    </div>
  </div>
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
  header h2 {
    margin: 0;
    font-size: 1.1rem;
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
