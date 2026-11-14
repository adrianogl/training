import { DEVICE_LABEL } from './constants'
import { readToken } from './session'
import type { Activity, AdminData, Evolution, PlannedWorkout, RaceInput, RaceView, WorkoutAnalysisView, HealthDay, SyncProgress, TodaySummary, ApiResult, AuthResult, GarminStatus, GarminStep, InviteChannel, InvitePreview, InviteResult, InviteRow, SessionInfo, User } from './types'

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
  signup: (name: string, email: string, password: string, inviteToken?: string) =>
    call<AuthResult>('POST', 'auth/signup', { name, email, password, device: DEVICE_LABEL, ...(inviteToken === undefined ? {} : { inviteToken }) }),
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
  garminStatus: () => call<GarminStatus>('GET', 'garmin/status'),
  garminConnect: (email: string, password: string) => call<GarminStep>('POST', 'garmin/connect', { email, password }),
  garminVerify: (code: string) => call<GarminStep>('POST', 'garmin/verify', { code }),
  garminDisconnect: () => call<void>('DELETE', 'garmin/status'),
  garminSync: () => call<SyncProgress>('POST', 'garmin/sync'),
  garminToday: () => call<TodaySummary>('GET', 'garmin/today'),
  garminEvolution: (days: number) => call<Evolution>('GET', `garmin/evolution?days=${days}`),
  garminActivity: (id: number) => call<{ activity: Activity; analysis: WorkoutAnalysisView; fitMissing: boolean }>('GET', `garmin/activity?id=${id}`),
  renameActivity: (id: number, name: string) => call<{ id: number; name: string }>('PUT', `garmin/activity?id=${id}`, { name }),
  garminPlanned: () => call<{ planned: PlannedWorkout[] }>('GET', 'garmin/planned'),
  races: () => call<{ today: string; races: RaceView[] }>('GET', 'races'),
  createRace: (race: RaceInput) => call<{ id: string }>('POST', 'races', race),
  updateRace: (id: string, race: RaceInput) => call<{ id: string }>('PUT', `races?id=${encodeURIComponent(id)}`, race),
  deleteRace: (id: string) => call<void>('DELETE', `races?id=${encodeURIComponent(id)}`),
  garminDays: (from: string, to: string) => call<{ days: HealthDay[] }>('GET', `garmin/days?from=${from}&to=${to}`),
  garminActivities: (limit: number, before?: string) =>
    call<{ activities: Activity[] }>('GET', `garmin/activities?limit=${limit}${before === undefined ? '' : `&before=${before}`}`),
  invitePreview: (token: string) => call<InvitePreview>('GET', `invites/preview?c=${encodeURIComponent(token)}`),
  adminOverview: () => call<AdminData>('GET', 'admin/overview'),
  adminInvite: (name: string, channel: InviteChannel, email?: string) =>
    call<InviteResult>('POST', 'admin/invites', { name, channel, ...(email === undefined || email === '' ? {} : { email }) }),
  adminInviteAction: (id: string, action: 'cancel' | 'renew') => call<InviteResult | { invite: InviteRow }>('POST', 'admin/invites/action', { id, action }),
  adminRequestAction: (id: string, action: 'invite' | 'decline') => call<InviteResult | { id: string; status: string }>('POST', 'admin/invite-requests/action', { id, action }),
  adminRemoveUser: (id: string) => call<void>('DELETE', `admin/users?id=${encodeURIComponent(id)}`),
}
