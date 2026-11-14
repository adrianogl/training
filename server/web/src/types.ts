export interface User {
  email: string
  name: string
  emailVerified: boolean
}

export interface AuthResult {
  token: string
  user: User
}

export interface SessionInfo {
  id: string
  device: string
  lastSeenAt: string
  current: boolean
}

export type ApiResult<T> = { ok: true; value: T } | { ok: false; error: string; status: number }

export type Route =
  | 'login'
  | 'signup'
  | 'forgot'
  | 'reset'
  | 'confirm'
  | 'today'
  | 'workouts'
  | 'races'
  | 'evolution'
  | 'settings'
  | 'password'

export interface NavItem {
  route: Route
  label: string
  icon: string
}
