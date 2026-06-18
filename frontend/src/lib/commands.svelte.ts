// ⌘K command registry. Navigation + actions today; feature rooms call
// register() to add their own commands (and, later, search providers for
// projects/files/sessions — deferred until those data rooms exist).

import { MODES, layout, type ModeId } from './layout.svelte'

export interface Command {
  id: string
  title: string
  group: string
  run: () => void
  keywords?: string
}

/** Case-insensitive subsequence match → score (lower = better), or null. */
export function fuzzyScore(query: string, text: string): number | null {
  if (!query) return 0
  const q = query.toLowerCase()
  const t = text.toLowerCase()
  let ti = 0
  let score = 0
  let lastMatch = -1
  for (let qi = 0; qi < q.length; qi++) {
    const ch = q[qi]
    const found = t.indexOf(ch, ti)
    if (found === -1) return null
    // gap since the previous matched char; 0 for contiguous (perfect → 0)
    if (lastMatch !== -1) score += found - lastMatch - 1
    lastMatch = found
    ti = found + 1
  }
  return score
}

export class CommandRegistry {
  commands = $state<Command[]>([])

  register(cmd: Command): () => void {
    this.commands = [...this.commands.filter((c) => c.id !== cmd.id), cmd]
    return () => {
      this.commands = this.commands.filter((c) => c.id !== cmd.id)
    }
  }

  search(query: string): Command[] {
    return this.commands
      .map((c) => ({
        c,
        score: fuzzyScore(query, `${c.title} ${c.keywords ?? ''}`),
      }))
      .filter((r): r is { c: Command; score: number } => r.score !== null)
      .sort((a, b) => a.score - b.score)
      .map((r) => r.c)
  }
}

export const commands = new CommandRegistry()

// Default commands: navigate to each mode + a few shell actions. These run
// against the shared `layout` singleton.
for (const m of MODES) {
  commands.register({
    id: `go.${m.id}`,
    title: `Go to ${m.label}`,
    group: 'Navigate',
    keywords: m.id,
    run: () => layout.setMode(m.id as ModeId),
  })
}

commands.register({
  id: 'panel.context',
  title: 'Toggle context panel',
  group: 'View',
  run: () => layout.toggleContext(),
})
commands.register({
  id: 'panel.terminal',
  title: 'Toggle terminal panel',
  group: 'View',
  run: () => layout.toggleTerminal(),
})
commands.register({
  id: 'tab.new',
  title: 'New tab',
  group: 'Workspace',
  run: () => layout.openTab(`Tab ${layout.tabs.length + 1}`),
})
