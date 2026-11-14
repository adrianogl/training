export interface User {
  email: string
  name: string
  emailVerified: boolean
  role: 'member' | 'guest'
  admin: boolean
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
  | 'admin'
  | 'invite'

export interface NavItem {
  route: Route
  label: string
  icon: string
}

export interface GarminStatus {
  connected: boolean
  connectedAt: string | null
}

export interface GarminStep {
  status: 'connected' | 'needs_code'
  method?: string
}

export type GarminModalStep = 'credentials' | 'code' | 'done'

export type InviteChannel = 'email' | 'whatsapp' | 'link'

export interface InviteRow {
  id: string
  name: string
  email: string | null
  channel: InviteChannel
  status: 'pending' | 'accepted' | 'expired' | 'canceled'
  createdAt: string
  expiresAt: string
  acceptedAt: string | null
}

export interface InviteResult {
  invite: InviteRow
  link: string
  message: string
  mailed: boolean
}

export interface InvitePreview {
  name: string
  email: string | null
  inviterName: string | null
  expiresAt: string
}

export interface AdminUser {
  id: string
  name: string
  email: string
  role: 'member' | 'guest'
  admin: boolean
  garminConnected: boolean
  lastSeenAt: string | null
  dataBytes: number
}

export interface AdminOverview {
  accounts: number
  maxAccounts: number
  pendingInvites: number
  expiringInvites: number
  activeAccounts: number
  garminConnected: number
  requests24h: number
  errors24h: number
  requestsByHour: { hour: string; count: number }[]
  requestsByRoute: { route: string; count: number }[]
  databaseBytes: number | null
}

export interface AdminData {
  overview: AdminOverview
  users: AdminUser[]
  invites: InviteRow[]
}
