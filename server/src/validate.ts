import {
  MAX_ID_LENGTH,
  MAX_PAYLOAD_CHARS,
  MAX_PUSH_RECORDS,
  READINESS_DAY_PATTERN,
  READINESS_MAX_SCORE,
  READINESS_MAX_VERDICT_LENGTH,
  READINESS_MIN_SCORE,
  RECORD_KINDS,
  SINCE_PATTERN,
  UPDATED_AT_PATTERN,
  WATCH_TOKEN_HASH_PATTERN,
} from './constants.js'
import type { BodyParseResult, IncomingRecord, ParseResult, Readiness, RecordKind } from './types.js'

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isKind(value: unknown): value is RecordKind {
  return RECORD_KINDS.some((kind) => kind === value)
}

function isUpdatedAt(value: unknown): value is string {
  if (typeof value !== 'string' || !UPDATED_AT_PATTERN.test(value)) {
    return false
  }
  const date = new Date(value)
  return !Number.isNaN(date.getTime()) && date.toISOString() === value
}

function validateRecord(value: unknown): IncomingRecord | string {
  if (!isObject(value)) {
    return 'invalid_record'
  }
  const { kind, id, updatedAt, deleted, payload } = value
  if (!isKind(kind)) {
    return 'invalid_kind'
  }
  if (typeof id !== 'string' || id.length === 0 || id.length > MAX_ID_LENGTH) {
    return 'invalid_id'
  }
  if (!isUpdatedAt(updatedAt)) {
    return 'invalid_updated_at'
  }
  if (typeof deleted !== 'boolean') {
    return 'invalid_deleted'
  }
  if (payload !== null && payload !== undefined && typeof payload !== 'string') {
    return 'invalid_payload'
  }
  const storedPayload = payload ?? null
  if (!deleted && (storedPayload === null || storedPayload === '')) {
    return 'missing_payload'
  }
  if (storedPayload !== null && storedPayload.length > MAX_PAYLOAD_CHARS) {
    return 'payload_too_large'
  }
  return { kind, id, updatedAt, deleted, payload: storedPayload }
}

export function parsePushBody(text: string): ParseResult {
  let body: unknown
  try {
    body = JSON.parse(text)
  } catch {
    return { ok: false, error: 'invalid_json' }
  }
  if (!isObject(body) || !Array.isArray(body.records)) {
    return { ok: false, error: 'invalid_body' }
  }
  if (body.records.length > MAX_PUSH_RECORDS) {
    return { ok: false, error: 'too_many_records' }
  }
  const records: IncomingRecord[] = []
  for (const item of body.records) {
    const result = validateRecord(item)
    if (typeof result === 'string') {
      return { ok: false, error: result }
    }
    records.push(result)
  }
  return { ok: true, records }
}

export function parseSince(value: string | null): number | undefined {
  if (value === null) {
    return 0
  }
  return SINCE_PATTERN.test(value) ? Number(value) : undefined
}

function parseObject(text: string): BodyParseResult<Record<string, unknown>> {
  let body: unknown
  try {
    body = JSON.parse(text)
  } catch {
    return { ok: false, error: 'invalid_json' }
  }
  return isObject(body) ? { ok: true, value: body } : { ok: false, error: 'invalid_body' }
}

export function parseWatchTokenBody(text: string): BodyParseResult<string> {
  const body = parseObject(text)
  if (!body.ok) {
    return body
  }
  const { tokenHash } = body.value
  if (typeof tokenHash !== 'string' || !WATCH_TOKEN_HASH_PATTERN.test(tokenHash)) {
    return { ok: false, error: 'invalid_token_hash' }
  }
  return { ok: true, value: tokenHash }
}

function isDay(value: unknown): value is string {
  if (typeof value !== 'string' || !READINESS_DAY_PATTERN.test(value)) {
    return false
  }
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value
}

export function parseReadinessBody(text: string): BodyParseResult<Readiness> {
  const body = parseObject(text)
  if (!body.ok) {
    return body
  }
  const { day, score, verdict } = body.value
  if (!isDay(day)) {
    return { ok: false, error: 'invalid_day' }
  }
  if (typeof score !== 'number' || !Number.isInteger(score) || score < READINESS_MIN_SCORE || score > READINESS_MAX_SCORE) {
    return { ok: false, error: 'invalid_score' }
  }
  const verdictLength = typeof verdict === 'string' ? [...verdict].length : 0
  if (typeof verdict !== 'string' || verdictLength === 0 || verdictLength > READINESS_MAX_VERDICT_LENGTH) {
    return { ok: false, error: 'invalid_verdict' }
  }
  return { ok: true, value: { day, score, verdict } }
}
