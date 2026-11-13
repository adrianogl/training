import type { RECORD_KINDS } from './constants.js'

export type RecordKind = (typeof RECORD_KINDS)[number]

export interface IncomingRecord {
  kind: RecordKind
  id: string
  updatedAt: string
  deleted: boolean
  payload: string | null
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

export interface KindCounts {
  live: number
  deleted: number
}

export interface HourlyBucket {
  hourStart: string
  total: number
  errors: number
}

export interface RecentRequest {
  at: string
  method: string
  route: string
  status: number
  recordCount: number | null
}

export interface AdminMetrics {
  database: { latencyMs: number }
  accounts: number
  records: Record<RecordKind, KindCounts>
  lastWrite: { at: string | null; seq: number }
  errors24h: number
  hourly: HourlyBucket[]
  recent: RecentRequest[]
}

export interface Limits {
  maxAccounts: number
  maxAccountBytes: number
}

export type PushOutcome = { status: 'ok'; result: PushResult } | { status: 'quota_exceeded' }

export interface Readiness {
  day: string
  score: number
  verdict: string
}

export type BodyParseResult<T> = { ok: true; value: T } | { ok: false; error: string }

export type WatchReadinessLookup = { status: 'unknown_token' } | { status: 'no_readiness' } | { status: 'ok'; readiness: Readiness }
