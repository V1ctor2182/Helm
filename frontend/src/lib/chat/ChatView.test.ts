import { render, screen } from '@testing-library/svelte'
import { afterEach, describe, expect, it, vi } from 'vitest'
import Chat from './Chat.svelte'
import { chat } from './chatStore.svelte'

afterEach(() => {
  vi.restoreAllMocks()
  chat.providers = []
  chat.sessions = []
  chat.current = null
  chat.messages = []
})

function stubFetch(map: Record<string, unknown>) {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) => {
      const key = Object.keys(map).find((k) => url.includes(k))
      return Promise.resolve({ ok: true, json: () => Promise.resolve(key ? map[key] : {}) })
    }),
  )
}

describe('Chat', () => {
  it('prompts to start a session when none is open, and lists providers', async () => {
    stubFetch({
      '/api/providers': {
        providers: [{ id: 1, type: 'ollama', name: 'Ollama', base_url: 'u', models: ['llama3'], has_key: false }],
      },
      '/api/sessions': { sessions: [] },
    })
    render(Chat)
    expect(screen.getByText('新会话')).toBeInTheDocument()
    expect(await screen.findByRole('option', { name: 'Ollama' })).toBeInTheDocument()
    expect(screen.getByText('新建或选择一个会话开始对话。')).toBeInTheDocument()
  })

  it('renders the session list', async () => {
    stubFetch({
      '/api/providers': { providers: [] },
      '/api/sessions': {
        sessions: [{ id: 7, title: '问答', provider_id: 1, model: 'm', system_prompt: null }],
      },
    })
    render(Chat)
    expect(await screen.findByText(/问答/)).toBeInTheDocument()
  })
})
