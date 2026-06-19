// Zero-friction quick-capture store. The shell owns the capture UX (⌘N
// overlay); durable persistence is the journal Room's (F6) job — it calls
// setPersister() to wire a backend endpoint. Until then captures live in
// memory (the seam is intentional, not a stub: the capture flow works
// end-to-end in the UI and F6 makes it durable).

export interface Capture {
  id: string
  text: string
  at: string
}

export type Persister = (text: string) => Promise<void> | void

export class CaptureStore {
  items = $state<Capture[]>([])

  #seq = 0
  #persist: Persister | null = null

  /** F6 wires durable storage here. */
  setPersister(fn: Persister): void {
    this.#persist = fn
  }

  async submit(text: string): Promise<boolean> {
    const t = text.trim()
    if (!t) return false
    const item: Capture = {
      id: `cap-${++this.#seq}`,
      text: t,
      at: new Date().toISOString(),
    }
    this.items = [item, ...this.items]
    if (this.#persist) await this.#persist(t)
    return true
  }
}

export const capture = new CaptureStore()
