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

export interface HealthDay {
  day: string
  restingHeartRate: number | null
  averageStress: number | null
  steps: number | null
  bodyBattery: { highest: number | null; lowest: number | null; atWake: number | null; charged: number | null; drained: number | null }
  sleep: { seconds: number; score: number | null; deep: number; light: number; rem: number; awake: number; start: string | null; end: string | null } | null
  hrv: { lastNight: number | null; weeklyAvg: number | null; status: string | null; lowUpper: number | null; balancedLow: number | null; balancedUpper: number | null } | null
  readiness: { score: number; level: string | null; sleepScore: number | null; recoveryMinutes: number | null; acuteLoad: number | null } | null
}

export interface Activity {
  id: number
  name: string
  type: string
  startLocal: string
  day: string
  distanceMeters: number | null
  durationSeconds: number | null
  movingSeconds: number | null
  elevationGain: number | null
  averageSpeed: number | null
  maxSpeed: number | null
  averageHeartRate: number | null
  maxHeartRate: number | null
  cadence: number | null
  trainingLoad: number | null
  aerobicEffect: number | null
  anaerobicEffect: number | null
  vo2max: number | null
  zoneSeconds: number[]
  fastestKmSeconds: number | null
  laps: number | null
  workoutId: number | null
}

export interface SyncProgress {
  done: boolean
  days: number
  activities: number
  oldestDay: string | null
}

export type SyncState = { kind: 'idle' } | { kind: 'running'; days: number } | { kind: 'done'; at: Date } | { kind: 'error'; message: string } | { kind: 'disconnected' }

export interface ReadinessFactor {
  component: 'hrv' | 'sleep' | 'bodyBattery' | 'load'
  todayScore: number | null
  normalScore: number | null
  points: number | null
  weight: number
}

export interface TodaySummary {
  day: string
  readiness: { score: number; normal: number | null; verdict: 'rest' | 'moderate' | 'hard'; factors: ReadinessFactor[] } | null
  raw: {
    hrvLastNight: number | null
    hrvBalancedLow: number | null
    hrvBalancedUpper: number | null
    sleepScore: number | null
    sleepSeconds: number | null
    bodyBatteryMorningMax: number | null
    acuteChronic: number | null
    restingHeartRate: number | null
    stress: number | null
  }
  recoveryMinutes: number | null
  garminReadiness: number | null
  fitness: { fitness: number; fatigue: number; form: number } | null
  week: { perDay: Record<string, number>; total: number; lastWeek: number; average4Weeks: number; recentWeeks: { start: string; kilometers: number }[] }
  focus: { lowAerobic: number; highAerobic: number; anaerobic: number } | null
}
