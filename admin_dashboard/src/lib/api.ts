/**
 * Typed fetch wrapper for the FastAPI backend.
 *
 * Base URL comes from VITE_API_BASE_URL (see .env.example) and defaults to
 * the deployed Render service, matching the mobile apps' AppConfig.
 */

const BASE = (import.meta.env.VITE_API_BASE_URL ?? 'https://ibajay-delivery.onrender.com').replace(/\/$/, '')

const TOKEN_KEY = 'ibaeats.admin.token'

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY)
}

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

interface ApiOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'
  body?: unknown
  query?: Record<string, string | number | boolean | undefined>
}

export async function api<T>(path: string, opts: ApiOptions = {}): Promise<T> {
  const url = new URL(`${BASE}/api/v1${path}`)
  if (opts.query) {
    for (const [k, v] of Object.entries(opts.query)) {
      if (v !== undefined) url.searchParams.set(k, String(v))
    }
  }

  const headers: Record<string, string> = { Accept: 'application/json' }
  if (opts.body !== undefined) headers['Content-Type'] = 'application/json'
  const token = getToken()
  if (token) headers.Authorization = `Bearer ${token}`

  let res: Response
  try {
    res = await fetch(url.toString(), {
      method: opts.method ?? 'GET',
      headers,
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
    })
  } catch {
    throw new ApiError('Could not reach the server. Check your connection and try again.', 0)
  }

  if (res.status === 204) return undefined as T

  let data: unknown = null
  try {
    data = res.status === 204 ? null : await res.json()
  } catch {
    data = null
  }

  if (!res.ok) {
    const detail =
      data && typeof data === 'object' && 'detail' in (data as Record<string, unknown>)
        ? String((data as Record<string, unknown>).detail)
        : `Request failed (${res.status})`
    // Expired/invalid admin session — drop the stale token.
    if (res.status === 401 && getToken()) clearToken()
    throw new ApiError(detail, res.status)
  }

  return data as T
}
