import {
  FACE_MAX_RACE_SECONDS,
  FACE_MAX_SHAPE_STEPS,
  FACE_MAX_SHAPE_WEIGHT,
  FACE_MAX_TEXT_LENGTH,
  FACE_MAX_VO2_DELTA,
  FACE_MAX_WEEK_KM,
  FACE_MAX_ZONE,
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
import type { BodyParseResult, IncomingRecord, ParseResult, Readiness, RecordKind, WatchFace } from './types.js'

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
  const { day, score, verdict, face } = body.value
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
  if (face === undefined) {
    return { ok: true, value: { day, score, verdict } }
  }
  const parsedFace = parseFace(face)
  if (parsedFace === undefined) {
    return { ok: false, error: 'invalid_face' }
  }
  return { ok: true, value: { day, score, verdict, face: parsedFace } }
}

function isText(value: unknown): value is string {
  return typeof value === 'string' && [...value].length > 0 && [...value].length <= FACE_MAX_TEXT_LENGTH
}

function isNumberIn(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max
}

function isIntegerIn(value: unknown, min: number, max: number): value is number {
  return isNumberIn(value, min, max) && Number.isInteger(value)
}

function isShape(value: unknown): value is number[][] {
  return Array.isArray(value)
    && value.length > 0
    && value.length <= FACE_MAX_SHAPE_STEPS
    && value.every((step) => Array.isArray(step)
      && step.length === 2
      && isIntegerIn(step[0], 1, FACE_MAX_SHAPE_WEIGHT)
      && isIntegerIn(step[1], 1, FACE_MAX_ZONE))
}

function parseFace(value: unknown): WatchFace | undefined {
  if (!isObject(value)) {
    return undefined
  }
  const checks: [keyof WatchFace, (field: unknown) => boolean][] = [
    ['vo2Delta', (field) => isNumberIn(field, -FACE_MAX_VO2_DELTA, FACE_MAX_VO2_DELTA)],
    ['weekPlannedKm', (field) => isNumberIn(field, 0, FACE_MAX_WEEK_KM)],
    ['weekGoalKm', (field) => isNumberIn(field, 0, FACE_MAX_WEEK_KM)],
    ['workout', isText],
    ['workoutShape', isShape],
    ['workoutTip', isText],
    ['raceName', isText],
    ['raceDay', isDay],
    ['raceGoal', (field) => isIntegerIn(field, 1, FACE_MAX_RACE_SECONDS)],
    ['racePrediction', (field) => isIntegerIn(field, 1, FACE_MAX_RACE_SECONDS)],
  ]
  const face: Record<string, unknown> = {}
  for (const [key, check] of checks) {
    const field = value[key]
    if (field === undefined) {
      continue
    }
    if (!check(field)) {
      return undefined
    }
    face[key] = field
  }
  return face as WatchFace
}
