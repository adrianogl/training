import type { PrescribedStep } from '../fit/fitTypes.js'
import { unroll } from './blocks.js'
import { runContinuity } from './continuity.js'
import { DETAILED } from './detailedConstants.js'
import type { DetailedKind, DetailedRun, KilometerPoint, RunFacts } from './detailedTypes.js'
import { kilometerSplits } from './kilometers.js'
import { zonesFor } from './workoutAnalysis.js'

const NAME_ORDER = ['intervals', 'long', 'race', 'tempo', 'easy'] as const

export const round = (value: number, places = 1) => Math.round(value * 10 ** places) / 10 ** places

export const mean = (values: number[]): number | null => (values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length)

export function median(values: number[]): number | null {
  if (values.length === 0) return null
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 1 ? (sorted[middle] ?? null) : ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2
}

function normalized(text: string): string {
  return text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
}

export function classify(run: DetailedRun): DetailedKind {
  const prescription = run.fit?.structure.prescription ?? null
  if ((prescription?.steps ?? []).some((step) => step.duration.kind === 'repeatSteps' && step.duration.count >= DETAILED.minimumRepetitions)) return 'intervals'
  const name = normalized(`${run.activity.name} ${prescription?.name ?? ''}`)
  for (const kind of NAME_ORDER) {
    if (DETAILED.words[kind].some((word) => name.includes(word))) return kind
  }
  const zones = run.activity.zoneSeconds
  const total = zones.reduce((sum, value) => sum + value, 0)
  const hard = zones.slice(DETAILED.hardZoneIndex).reduce((sum, value) => sum + value, 0)
  if (total > 0 && hard / total >= DETAILED.hardZoneShare) return 'tempo'
  return (run.activity.distanceMeters ?? 0) >= DETAILED.longMinimumMeters ? 'long' : 'easy'
}

export function kilometerPoints(run: DetailedRun): KilometerPoint[] {
  if (run.fit === null) return []
  return kilometerSplits(run.fit.samples, zonesFor(run.fit))
    .filter((block) => block.distance >= DETAILED.fullKilometerMeters && block.seconds > 0)
    .map((block) => ({ km: block.ordinal, paceSeconds: round((block.seconds * DETAILED.metersPerKilometer) / block.distance), heartRate: block.avgHeartRate }))
}

export function fadeKilometer(splits: KilometerPoint[]): number | null {
  for (let index = DETAILED.fadeMinimumKm - 1; index < splits.length - 1; index += 1) {
    const baseline = median(splits.slice(0, index).map((point) => point.paceSeconds))
    const current = splits[index]
    const next = splits[index + 1]
    if (baseline === null || current === undefined || next === undefined) continue
    if (current.paceSeconds - baseline >= DETAILED.fadeSeconds && next.paceSeconds - baseline >= DETAILED.fadeSeconds) return current.km
  }
  return null
}

export function heartRateDrift(splits: KilometerPoint[]): number | null {
  const rows = splits.flatMap((point) => (point.heartRate === null || point.heartRate <= 0 ? [] : [{ pace: point.paceSeconds, heartRate: point.heartRate }]))
  if (rows.length < DETAILED.driftMinimumKilometers) return null
  const half = Math.floor(rows.length / 2)
  const efficiency = (part: typeof rows) => (mean(part.map((row) => DETAILED.metersPerKilometer / row.pace)) ?? 0) / (mean(part.map((row) => row.heartRate)) ?? 1)
  const first = efficiency(rows.slice(0, half))
  return first > 0 ? round(((first - efficiency(rows.slice(rows.length - half))) / first) * 100) : null
}

export function startPace(splits: KilometerPoint[]): number | null {
  return splits.length < DETAILED.startKilometers ? null : round(mean(splits.slice(0, DETAILED.startKilometers).map((point) => point.paceSeconds)) ?? 0)
}

function stepMeters(step: PrescribedStep): number | null {
  if (step.duration.kind === 'distance') return step.duration.meters
  if (step.duration.kind === 'time' && step.target.kind === 'speed') return (step.duration.seconds * (step.target.low + step.target.high)) / 2
  return null
}

export function plannedMeters(run: DetailedRun): number | null {
  const steps = run.fit?.structure.prescription?.steps
  if (steps === undefined || steps.length === 0) return null
  const meters = unroll(steps).map((item) => stepMeters(item.step))
  if (meters.length === 0 || meters.some((value) => value === null)) return null
  const total = meters.reduce<number>((sum, value) => sum + (value ?? 0), 0)
  return total > 0 ? total : null
}

export function runFacts(run: DetailedRun): RunFacts {
  const splits = kilometerPoints(run)
  const kind = classify(run)
  const steady = kind !== 'intervals'
  return {
    run,
    kind,
    splits,
    fadeKm: steady ? fadeKilometer(splits) : null,
    drift: steady ? heartRateDrift(splits) : null,
    plannedMeters: plannedMeters(run),
    continuity: run.fit === null ? null : runContinuity(run.fit.samples),
  }
}
