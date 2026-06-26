// Mail store (email-calendar m3): accounts, inbox, email detail + AI triage.
// Mirrors the resilient `#json`/`#post` pattern used elsewhere.

export interface MailAccount {
  id: number
  name: string
  email_addr: string
  imap_host: string
  has_password: boolean
}

export interface Triage {
  urgency: string
  is_spam: boolean
  summary: string
  labels: string[]
  draft: string
}

export interface EmailItem {
  id: number
  account_id: number
  uid: string
  from_addr: string
  subject: string
  snippet: string
  unread: boolean
  labels: string[]
  triage: Triage | null
  date: string | null
  body?: string
}

export interface MailProvider {
  id: number
  name: string
  models: string[]
}

export class MailStore {
  accounts = $state<MailAccount[]>([])
  emails = $state<EmailItem[]>([])
  current = $state<EmailItem | null>(null)
  providers = $state<MailProvider[]>([])
  syncing = $state(false)
  triaging = $state(false)
  error = $state<string | null>(null)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    try {
      const res = await fetch(path, init)
      if (!res.ok) return null
      return await res.json()
    } catch {
      return null
    }
  }

  #post(path: string, body?: unknown): Promise<unknown | null> {
    return this.#json(path, {
      method: 'POST',
      headers: body ? { 'content-type': 'application/json' } : {},
      body: body ? JSON.stringify(body) : undefined,
    })
  }

  async loadAccounts(): Promise<void> {
    const b = (await this.#json('/api/mail/accounts')) as { accounts: MailAccount[] } | null
    if (b) this.accounts = b.accounts
  }

  async loadEmails(): Promise<void> {
    const b = (await this.#json('/api/mail/emails')) as { emails: EmailItem[] } | null
    if (b) this.emails = b.emails
  }

  async loadProviders(): Promise<void> {
    const b = (await this.#json('/api/providers')) as { providers: MailProvider[] } | null
    if (b) this.providers = b.providers
  }

  async openEmail(id: number): Promise<void> {
    const b = (await this.#json(`/api/mail/emails/${id}`)) as EmailItem | null
    if (b) this.current = b
  }

  async addAccount(a: {
    name: string
    email_addr: string
    imap_host: string
    username: string
    password: string
  }): Promise<boolean> {
    const created = await this.#post('/api/mail/accounts', a)
    if (created) await this.loadAccounts()
    else this.error = '添加账户失败'
    return created !== null
  }

  async sync(): Promise<void> {
    if (!this.accounts.length) return
    this.syncing = true
    try {
      for (const a of this.accounts) await this.#post(`/api/mail/accounts/${a.id}/sync`)
      await this.loadEmails()
    } finally {
      this.syncing = false
    }
  }

  async triage(id: number): Promise<void> {
    const p = this.providers[0]
    if (!p) {
      this.error = '没有可用的模型 provider — 先在 Chat 配置一个'
      return
    }
    this.triaging = true
    try {
      const t = (await this.#post(`/api/mail/emails/${id}/triage`, {
        provider_id: p.id,
        model: p.models[0] ?? '',
      })) as Triage | null
      if (t && this.current?.id === id) this.current = { ...this.current, triage: t }
      await this.loadEmails()
    } finally {
      this.triaging = false
    }
  }
}

export const mail = new MailStore()
