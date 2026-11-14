import { Decoder, Stream } from '@garmin/fitsdk'
import { unzipSync } from 'fflate'
import { FIT } from './fitConstants.js'
import type { Coordinate, FitMessage, FitSample, FitSummary, HeartRateZoneInfo, PhysioMetrics } from './fitTypes.js'
import { simplify } from './routeSimplifier.js'
import { workoutStructure } from './workoutStructure.js'

export type FitReadErrorCode = 'invalid_zip' | 'no_fit_entry' | 'decode_failed'

export class FitReadError extends Error {
  readonly code: FitReadErrorCode

  constructor(code: FitReadErrorCode) {
    super(code)
    this.code = code
  }
}

const num = (value: unknown): number | null => (typeof value === 'number' && Number.isFinite(value) ? value : null)
const seconds = (value: unknown): number | null => (value instanceof Date ? value.getTime() / 1000 : null)
const mean = (values: number[]): number | null => (values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length)

export function readZip(zip: Uint8Array): FitSummary {
  let files: Record<string, Uint8Array>
  try {
    files = unzipSync(zip)
  } catch {
    throw new FitReadError('invalid_zip')
  }
  const entry = Object.keys(files).find((name) => name.toLowerCase().endsWith('.fit') && !name.endsWith('/'))
  const fit = entry === undefined ? undefined : files[entry]
  if (fit === undefined) throw new FitReadError('no_fit_entry')
  return readFit(fit)
}

function resample(records: FitMessage[]): FitSample[] {
  const timed = records.flatMap((record) => {
    const t = seconds(record.timestamp)
    return t === null ? [] : [{ record, t }]
  })
  const origin = timed[0]?.t
  if (origin === undefined) return []
  const buckets = new Map<number, FitMessage[]>()
  for (const { record, t } of timed) {
    const key = Math.trunc((t - origin) / FIT.bucketSeconds)
    buckets.set(key, [...(buckets.get(key) ?? []), record])
  }
  return [...buckets.keys()]
    .sort((a, b) => a - b)
    .map((key) => {
      const group = buckets.get(key) ?? []
      const pick = (read: (record: FitMessage) => number | null) => group.flatMap((record) => {
        const value = read(record)
        return value === null ? [] : [value]
      })
      const heartRate = mean(pick((record) => num(record.heartRate)))
      const distances = pick((record) => num(record.distance))
      return {
        t: key * FIT.bucketSeconds,
        heartRate: heartRate === null ? null : Math.round(heartRate),
        speed: mean(pick((record) => num(record.enhancedSpeed) ?? num(record.speed))),
        altitude: mean(pick((record) => num(record.enhancedAltitude) ?? num(record.altitude))),
        distance: distances.at(-1) ?? null,
      }
    })
}

function route(records: FitMessage[]): Coordinate[] {
  return records.flatMap((record) => {
    const lat = num(record.positionLat)
    const lon = num(record.positionLong)
    return lat === null || lon === null ? [] : [{ lat: lat * FIT.semicircleToDegrees, lon: lon * FIT.semicircleToDegrees }]
  })
}

function physio(messages: FitMessage[]): PhysioMetrics | null {
  if (messages.length === 0) return null
  const metrics: PhysioMetrics = { vo2max: null, recoveryMinutes: null, performanceCondition: null }
  for (const message of messages) {
    const vo2 = num(message[FIT.vo2maxField])
    if (vo2 !== null && vo2 > 0) metrics.vo2max = (vo2 / FIT.vo2maxDivisor) * FIT.vo2maxFactor
    const recovery = num(message[FIT.recoveryMinutesField])
    if (recovery !== null) metrics.recoveryMinutes = Math.trunc(recovery)
    const condition = num(message[FIT.performanceConditionField])
    if (condition !== null) metrics.performanceCondition = Math.trunc(condition)
  }
  return metrics
}

function heartRate(value: unknown): number | null {
  const bpm = num(value)
  return bpm === null || bpm <= 0 || bpm === FIT.invalidHeartRate ? null : Math.trunc(bpm)
}

function zoneInfo(message: FitMessage): HeartRateZoneInfo {
  const boundaries = Array.isArray(message.hrZoneHighBoundary) ? message.hrZoneHighBoundary.slice(0, FIT.watchZoneFloorCount) : []
  const floors = boundaries.map(heartRate).filter((value): value is number => value !== null)
  const calc = typeof message.hrCalcType === 'string' ? (FIT.hrCalcTypes[message.hrCalcType] ?? null) : num(message.hrCalcType)
  return {
    thresholdHeartRate: heartRate(message.thresholdHeartRate),
    maxHeartRate: heartRate(message.maxHeartRate),
    restingHeartRate: heartRate(message.restingHeartRate),
    calcType: calc,
    floors: floors.length === FIT.watchZoneFloorCount ? floors : [],
  }
}

export function readFit(bytes: Uint8Array): FitSummary {
  const stream = Stream.fromByteArray(Array.from(bytes))
  if (!Decoder.isFIT(stream)) throw new FitReadError('decode_failed')
  const decoder = new Decoder(stream)
  const { messages, errors } = decoder.read({ includeUnknownData: true, mergeHeartRates: false })
  if (errors.length > 0) throw new FitReadError('decode_failed')
  const list = (key: string) => ((messages as Record<string, unknown>)[key] as FitMessage[] | undefined) ?? []
  const records = list('recordMesgs')
  const origin = records.map((record) => seconds(record.timestamp)).find((value) => value !== null) ?? null
  const sessionZones = list('timeInZoneMesgs').find((message) => message.referenceMesg === 'session')
  return {
    version: FIT.processingVersion,
    samples: resample(records),
    route: simplify(route(records), FIT.maxRoutePoints),
    physio: physio(list(FIT.physioMessageKey)),
    structure: workoutStructure(list('workoutMesgs'), list('workoutStepMesgs'), list('lapMesgs'), origin),
    zoneInfo: sessionZones === undefined ? null : zoneInfo(sessionZones),
  }
}
