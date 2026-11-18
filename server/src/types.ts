import type { RECORD_FORMATS, RECORD_KINDS } from './constants.js'

export type RecordKind = (typeof RECORD_KINDS)[number]

export type RecordFormat = (typeof RECORD_FORMATS)[number]

export interface IncomingRecord {
  kind: RecordKind
  id: string
  updatedAt: string
  deleted: boolean
  payload: string | null
  format?: RecordFormat
}

export interface StoredRecord extends IncomingRecord {
  seq: number
}

export interface RecordKey {
  kind: RecordKind
  id: string
}

export interface PushResult {
  cursor: number
  ignored: RecordKey[]
}

export interface PullResult {
  records: StoredRecord[]
  cursor: number
  hasMore: boolean
}

export type ParseResult = { ok: true; records: IncomingRecord[] } | { ok: false; error: string }

export type CreateAccountOutcome = 'created' | 'exists' | 'rate_limited'

export interface RequestLogEntry {
  method: string
  route: string
  status: number
  recordCount: number | null
  accountPrefix: string | null
}

export interface Limits {
  maxAccounts: number
  maxAccountBytes: number
}

export type PushOutcome = { status: 'ok'; result: PushResult } | { status: 'quota_exceeded' }

export interface WatchEvent {
  start: number
  title: string
}

export interface WatchFace {
  vo2Delta?: number
  weekPlannedKm?: number
  weekGoalKm?: number
  trainingStatus?: string
  nextWeek?: string
  workout?: string
  workoutShape?: number[][]
  workoutTip?: string
  raceName?: string
  raceDay?: string
  raceGoal?: number
  racePrediction?: number
  events?: WatchEvent[]
}

export interface Readiness {
  day: string
  score?: number
  verdict?: string
  face?: WatchFace
}

export type BodyParseResult<T> = { ok: true; value: T } | { ok: false; error: string }

export type WatchReadinessLookup =
  | { status: 'unknown_token' }
  | { status: 'no_readiness' }
  | { status: 'ok'; readiness: Omit<Readiness, 'face'> & WatchFace }

export interface User {
  id: string
  accountId: string
  email: string
  name: string
  emailVerified: boolean
  role: UserRole
}

export interface SessionInfo {
  id: string
  device: string
  lastSeenAt: string
  current: boolean
}

export interface Mail {
  to: string
  subject: string
  text: string
  html?: string
}

export interface Mailer {
  send: (mail: Mail) => Promise<void>
}

export interface AuthEnv {
  mailer: Mailer | undefined
  appUrl: string
  now: () => Date
  maxAccounts: number
  adminEmails: string[]
}

export type EmailPurpose = 'verify' | 'reset'

export interface SignupInput {
  name: string
  email: string
  password: string
  device: string
  legacyKey: string | undefined
  inviteToken: string | undefined
}

export interface LoginInput {
  email: string
  password: string
  device: string
}

export interface PasswordChangeInput {
  current: string
  next: string
  endOtherSessions: boolean
}

export interface GarminSession {
  accessToken: string
  refreshToken: string | null
  clientId: string
  expiresAt: string
}

export interface GarminPendingLogin {
  method: string
  cookies: string[]
}

export type GarminLoginOutcome =
  | { status: 'signed_in'; session: GarminSession }
  | { status: 'needs_code'; pending: GarminPendingLogin }

export type GarminErrorCode = 'invalid_credentials' | 'invalid_code' | 'rate_limited' | 'unexpected_response' | 'exchange_failed' | 'session_expired'

export type Fetcher = typeof fetch

export interface GarminEnv {
  dataKey: Buffer | undefined
  fetcher: Fetcher
  now: () => Date
}

export type InviteChannel = 'email' | 'whatsapp' | 'link'

export type UserRole = 'member' | 'guest'

export type InviteStatus = 'pending' | 'accepted' | 'expired' | 'canceled'

export interface InviteRow {
  id: string
  name: string
  email: string | null
  channel: InviteChannel
  status: InviteStatus
  createdAt: string
  expiresAt: string
  acceptedAt: string | null
}

export interface InviteInput {
  name: string
  email: string | undefined
  channel: InviteChannel
}

export interface AdminUserRow {
  id: string
  name: string
  email: string
  role: UserRole
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

export interface InviteRequestInput {
  name: string
  email: string
  watch: string
  message: string
}

export interface InviteRequestRow extends InviteRequestInput {
  id: string
  createdAt: string
}

export interface StravaEnv {
  dataKey: Buffer | undefined
  fetcher: Fetcher
  now: () => Date
  clientId: string | undefined
  clientSecret: string | undefined
}

export interface StravaLink {
  athleteId: number
  athleteName: string
  accessToken: string
  refreshToken: string
  expiresAt: string
  scope: string
  format: string
  enabled: boolean
}

export interface StravaTokenSet {
  accessToken: string
  refreshToken: string
  expiresAt: string
  athleteId: number | undefined
  athleteName: string | undefined
}

export type StravaDescribeStatus = 'posted' | 'updated' | 'not_found' | 'edited_by_user' | 'disabled' | 'retry_later'
