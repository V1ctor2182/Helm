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
