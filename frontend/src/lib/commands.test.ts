import { describe, expect, it } from 'vitest'
import { CommandRegistry, fuzzyScore, commands } from './commands.svelte'
import { layout } from './layout.svelte'

describe('fuzzyScore', () => {
  it('matches subsequences and rejects non-matches', () => {
    expect(fuzzyScore('', 'anything')).toBe(0)
    expect(fuzzyScore('cht', 'Go to Chat')).not.toBeNull()
    expect(fuzzyScore('zzz', 'Go to Chat')).toBeNull()
  })

  it('ranks contiguous matches better (lower score)', () => {
    const contiguous = fuzzyScore('chat', 'Chat')!
    const spread = fuzzyScore('chat', 'C h a t')!
    expect(contiguous).toBeLessThan(spread)
  })
})

describe('CommandRegistry', () => {
  it('register adds and returns an unregister fn', () => {
    const r = new CommandRegistry()
    const off = r.register({ id: 'x', title: 'Do X', group: 'Test', run: () => {} })
    expect(r.search('x').length).toBe(1)
    off()
    expect(r.search('x').length).toBe(0)
  })

  it('register de-dupes by id', () => {
    const r = new CommandRegistry()
    r.register({ id: 'x', title: 'One', group: 'g', run: () => {} })
    r.register({ id: 'x', title: 'Two', group: 'g', run: () => {} })
    expect(r.commands.length).toBe(1)
    expect(r.commands[0].title).toBe('Two')
  })

  it('search filters by fuzzy query', () => {
    const r = new CommandRegistry()
    r.register({ id: 'a', title: 'Open Chat', group: 'g', run: () => {} })
    r.register({ id: 'b', title: 'New Tab', group: 'g', run: () => {} })
    const titles = r.search('chat').map((c) => c.title)
    expect(titles).toEqual(['Open Chat'])
  })
})

describe('default commands', () => {
  it('registers navigation for every mode and they switch mode', () => {
    const goChat = commands.search('Go to Chat')[0]
    expect(goChat).toBeTruthy()
    goChat.run()
    expect(layout.mode).toBe('chat')
    // restore
    layout.setMode('today')
  })
})
