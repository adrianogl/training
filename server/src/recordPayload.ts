import { open, seal } from './cipher.js'
import { BASE64_PATTERN, DAY_PATTERN, GOALS, PLAIN_LIMITS, RECORD_CONTEXT_PREFIX, TRAINER_RECORD_ID } from './constants.js'
import type { IncomingRecord, RecordKind, StoredRecord } from './types.js'

type Check = (value: unknown) => boolean

const isText = (max: number): Check => (value) => typeof value === 'string' && value.length > 0 && value.length <= max
const isDay: Check = (value) => typeof value === 'string' && DAY_PATTERN.test(value)
const isPositive = (max: number): Check => (value) => typeof value === 'number' && Number.isFinite(value) && value > 0 && value <= max
const isNonNegative = (max: number): Check => (value) => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= max
const isBase64: Check = (value) => typeof value === 'string' && BASE64_PATTERN.test(value)
const isInteger: Check = (value) => typeof value === 'number' && Number.isSafeInteger(value)
const isBoolean: Check = (value) => typeof value === 'boolean'
const isString: Check = (value) => typeof value === 'string'
const isArray: Check = (value) => Array.isArray(value)
const isObject: Check = (value) => typeof value === 'object' && value !== null && !Array.isArray(value)
const optional = (check: Check): Check => (value) => value === undefined || value === null || check(value)

const RACE_FIELDS: Record<string, Check> = {
  id: isText(64),
  name: isText(PLAIN_LIMITS.name),
  day: isDay,
  startTime: optional(isText(8)),
  distance: isPositive(PLAIN_LIMITS.maxDistance),
  goalSeconds: optional(isNonNegative(PLAIN_LIMITS.maxSeconds)),
  priority: isText(PLAIN_LIMITS.priority),
  city: optional(isText(PLAIN_LIMITS.city)),
  gpxData: optional(isBase64),
  manualPacesData: optional(isBase64),
  customLabelsData: optional(isBase64),
  resultActivityId: optional(isInteger),
  frozenTargetSeconds: optional(isNonNegative(PLAIN_LIMITS.maxSeconds)),
  frozenTargetDay: optional(isDay),
  manuallyUnlinked: optional(isBoolean),
  updatedAt: isString,
}

const GOAL_FIELDS: Record<string, Check> = {
  id: isText(64),
  kind: (value) => GOALS.kinds.some((kind) => kind === value),
  distanceKm: isPositive(GOALS.maxDistanceKm),
  targetSeconds: optional(isPositive(GOALS.maxTargetSeconds)),
  deadline: optional(isDay),
  paceSecondsPerKm: optional(isPositive(GOALS.maxPaceSecondsPerKm)),
  archived: isBoolean,
  achievedAt: optional(isDay),
  createdAt: isString,
  updatedAt: isString,
}

const TRAINER_FIELDS: Record<string, Check> = {
  target: isObject,
  paces: isObject,
  weeks: isArray,
  workouts: isArray,
  versions: isArray,
}

const DECISION_FIELDS: Record<string, Check> = {
  activityId: isInteger,
  decision: isText(PLAIN_LIMITS.decision),
}

function parseObject(payload: string): Record<string, unknown> | undefined {
  try {
    const value: unknown = JSON.parse(payload)
    return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : undefined
  } catch {
    return undefined
  }
}

export function plainPayloadError(kind: RecordKind, id: string, payload: string): string | null {
  const value = parseObject(payload)
  if (value === undefined) {
    return 'invalid_plain_payload'
  }
  const fields = kind === 'race' ? RACE_FIELDS : kind === 'goal' ? GOAL_FIELDS : kind === 'trainer' ? TRAINER_FIELDS : DECISION_FIELDS
  if (!Object.entries(fields).every(([name, check]) => check(value[name]))) {
    return 'invalid_plain_payload'
  }
  if (kind === 'trainer') {
    return id === TRAINER_RECORD_ID ? null : 'invalid_plain_payload'
  }
  const ownId = kind === 'decision' ? String(value.activityId) : String(value.id).toLowerCase()
  return ownId === id.toLowerCase() ? null : 'invalid_plain_payload'
}

function context(accountId: string, kind: RecordKind, id: string): string {
  return `${RECORD_CONTEXT_PREFIX}:${accountId}:${kind}:${id}`
}

export function sealPlainRecords(records: IncomingRecord[], key: Buffer, accountId: string): IncomingRecord[] {
  return records.map((record) =>
    record.format === 'plain' && record.payload !== null ? { ...record, payload: seal(key, record.payload, context(accountId, record.kind, record.id)) } : record,
  )
}

export function openPlainRecords(records: StoredRecord[], key: Buffer | undefined, accountId: string): StoredRecord[] {
  return records.map((record) => {
    if (record.format !== 'plain' || key === undefined) {
      const { format: _format, ...rest } = record
      return rest
    }
    return { ...record, payload: record.payload === null ? null : (open(key, record.payload, context(accountId, record.kind, record.id)) ?? null) }
  })
}

export function openPlainPayload(key: Buffer, accountId: string, kind: RecordKind, id: string, payload: string): string | undefined {
  return open(key, payload, context(accountId, kind, id))
}

export function hasPlain(records: IncomingRecord[]): boolean {
  return records.some((record) => record.format === 'plain')
}
