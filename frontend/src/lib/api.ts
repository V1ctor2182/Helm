// Shared resilient JSON fetch used by every store: returns the parsed body, or
// null on any failure (non-2xx status, network error, or JSON parse error).
// Centralizes the try/catch that each store's private `#json` used to duplicate
// (backlog ticket 4527c95c).
export async function jsonFetch(path: string, init?: RequestInit): Promise<unknown | null> {
  try {
    const res = await fetch(path, init)
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}

// List endpoints all answer `{ <key>: T[] }`. This guards the shape once for
// every store: null = request failed (keep stale data / show error), [] = the
// body arrived but the key was missing or not an array (defensive default),
// so a 200 error-envelope can never crash a view with `undefined.map`.
export async function jsonList<T>(path: string, key: string, init?: RequestInit): Promise<T[] | null> {
  const body = await jsonFetch(path, init)
  if (body === null || typeof body !== 'object') return null
  const xs = (body as Record<string, unknown>)[key]
  return Array.isArray(xs) ? (xs as T[]) : []
}
