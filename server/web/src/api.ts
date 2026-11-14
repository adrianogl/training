import { DEVICE_LABEL } from './constants'
import { readToken } from './session'
import type { ApiResult, AuthResult, SessionInfo, User } from './types'

async function call<T>(method: string, path: string, body?: unknown): Promise<ApiResult<T>> {
  const headers: Record<string, string> = { accept: 'application/json' }
  const token = readToken()
  if (token !== null) {
    headers.authorization = `Bearer ${token}`
  }
  if (body !== undefined) {
    headers['content-type'] = 'application/json'
  }
  let response: Response
  try {
    response = await fetch(`/api/v1/${path}`, { method, headers, body: body === undefined ? null : JSON.stringify(body) })
  } catch {
    return { ok: false, error: 'network', status: 0 }
  }
  if (!response.ok) {
    const parsed = (await response.json().catch(() => ({}))) as { error?: string }
    return { ok: false, error: parsed.error ?? 'unknown', status: response.status }
  }
  if (response.status === 204) {
    return { ok: true, value: undefined as T }
  }
  return { ok: true, value: (await response.json()) as T }
}

export const api = {
  signup: (name: string, email: string, password: string) =>
    call<AuthResult>('POST', 'auth/signup', { name, email, password, device: DEVICE_LABEL }),
  login: (email: string, password: string) => call<AuthResult>('POST', 'auth/login', { email, password, device: DEVICE_LABEL }),
  logout: () => call<void>('POST', 'auth/logout'),
  me: () => call<{ user: User }>('GET', 'auth/me'),
  rename: (name: string) => call<{ user: User }>('PATCH', 'auth/me', { name }),
  changePassword: (current: string, next: string, endOtherSessions: boolean) =>
    call<void>('POST', 'auth/password', { current, next, endOtherSessions }),
  forgot: (email: string) => call<void>('POST', 'auth/forgot', { email }),
  reset: (token: string, password: string) => call<void>('POST', 'auth/reset', { token, password }),
  verify: (token: string) => call<void>('POST', 'auth/verify', { token }),
  resendVerification: () => call<void>('POST', 'auth/resend-verification'),
  sessions: () => call<{ sessions: SessionInfo[] }>('GET', 'auth/sessions'),
  endSession: (id: string) => call<void>('DELETE', `auth/sessions?id=${encodeURIComponent(id)}`),
  deleteAccount: () => call<void>('DELETE', 'account'),
}
