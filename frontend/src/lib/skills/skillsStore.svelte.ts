// Skills store (Svelte 5 runes): a panorama over the machine's agent skills —
// health, enable/disable, and usage counts. Read-mostly; toggling persists the
// Helm-side enabled flag. Mirrors the resilient `#json` helper used elsewhere.

import { jsonFetch } from '../api'

export interface Skill {
  name: string
  description: string
  path: string
  healthy: boolean
  error: string | null
  enabled: boolean
  uses: number
  last_used: string | null
}

export class SkillsStore {
  skills = $state<Skill[]>([])
  total = $state(0)
  healthy = $state(0)
  unhealthy = $state(0)
  error = $state<string | null>(null)

  async #json(path: string, init?: RequestInit): Promise<unknown | null> {
    return jsonFetch(path, init)
  }

  async load(): Promise<void> {
    const body = (await this.#json('/api/skills')) as
      | { skills: Skill[]; total: number; healthy: number; unhealthy: number }
      | null
    if (body) {
      this.skills = body.skills
      this.total = body.total
      this.healthy = body.healthy
      this.unhealthy = body.unhealthy
    }
  }

  async toggle(skill: Skill): Promise<void> {
    const ok = await this.#json(`/api/skills/${encodeURIComponent(skill.name)}/enabled`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ enabled: !skill.enabled }),
    })
    if (ok) await this.load()
    else this.error = '切换失败'
  }
}

export const skills = new SkillsStore()
