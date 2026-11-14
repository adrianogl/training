import { minettiCost } from '../domain/raceStrategy.js'
import { FIT } from './fitConstants.js'
import type { FitSample } from './fitTypes.js'

const mean = (values: number[]) => (values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length)

function median(values: number[]): number | null {
  if (values.length === 0) return null
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0 ? ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2 : (sorted[middle] ?? 0)
}

export function zone2Pace(samples: FitSample[], low: number, high: number): number | null {
  const speeds = samples.flatMap((sample) =>
    sample.t >= FIT.warmupSeconds && sample.heartRate !== null && sample.heartRate >= low && sample.heartRate <= high && sample.speed !== null && sample.speed > 0 ? [sample.speed] : [],
  )
  const average = mean(speeds)
  return speeds.length * FIT.bucketSeconds >= FIT.minimumSteadySeconds && average !== null ? 1000 / average : null
}

export function thresholdPace(runs: FitSample[][], lthr: number): number | null {
  const paces: number[] = []
  for (const run of runs) {
    let segment: number[] = []
    let lastTime: number | null = null
    const close = () => {
      if (segment.length * FIT.bucketSeconds >= FIT.minimumSteadySeconds) paces.push(...segment.map((speed) => 1000 / speed))
      segment = []
    }
    for (const sample of run) {
      if (lastTime !== null && sample.t - lastTime > FIT.bucketSeconds) close()
      lastTime = sample.t
      if (sample.heartRate !== null && Math.abs(sample.heartRate - lthr) <= FIT.thresholdHeartRateTolerance && sample.speed !== null && sample.speed > 0) segment.push(sample.speed)
      else close()
    }
    close()
  }
  return median(paces)
}

export function decoupling(samples: FitSample[]): number | null {
  const first = samples[0]
  const last = samples.at(-1)
  if (first === undefined || last === undefined || last.t - first.t < FIT.decouplingMinimumSeconds) return null
  const steady = samples.filter((sample) => sample.t >= FIT.warmupSeconds)
  const start = steady[0]?.t
  const end = steady.at(-1)?.t
  if (start === undefined || end === undefined) return null
  const midpoint = (start + end) / 2
  const ratio = (half: FitSample[]) => {
    const speed = mean(half.flatMap((sample) => (sample.speed === null ? [] : [sample.speed])))
    const heartRate = mean(half.flatMap((sample) => (sample.heartRate === null ? [] : [sample.heartRate])))
    return speed === null || heartRate === null || heartRate <= 0 ? null : speed / heartRate
  }
  const r1 = ratio(steady.filter((sample) => sample.t < midpoint))
  const r2 = ratio(steady.filter((sample) => sample.t >= midpoint))
  return r1 === null || r2 === null || r1 <= 0 ? null : ((r1 - r2) / r1) * 100
}

type GradeClass = 'up' | 'flat' | 'down'

interface GradePoint {
  sample: FitSample
  distance: number
  altitude: number
}

interface GradeSegment {
  kind: GradeClass
  length: number
  climb: number
  samples: FitSample[]
}

const classify = (grade: number): GradeClass => (grade > FIT.flatMaximumGrade ? 'up' : grade < -FIT.flatMaximumGrade ? 'down' : 'flat')

function gradeRuns(samples: FitSample[]): GradePoint[][] {
  const runs: GradePoint[][] = []
  let current: GradePoint[] = []
  for (const sample of samples) {
    if (sample.distance === null || sample.altitude === null) {
      if (current.length > 0) runs.push(current)
      current = []
      continue
    }
    const last = current.at(-1)
    if (last !== undefined && sample.distance <= last.distance) {
      runs.push(current)
      current = []
    }
    current.push({ sample, distance: sample.distance, altitude: sample.altitude })
  }
  if (current.length > 0) runs.push(current)
  return runs
}

function windowGrade(points: GradePoint[], index: number): number {
  const half = FIT.gradeWindowLength / 2
  const at = (i: number) => points[i] as GradePoint
  let low = index
  while (low > 0 && at(index).distance - at(low - 1).distance <= half) low -= 1
  let high = index
  while (high < points.length - 1 && at(high + 1).distance - at(index).distance <= half) high += 1
  const length = at(high).distance - at(low).distance
  return length > 0 ? (at(high).altitude - at(low).altitude) / length : 0
}

function rawGrade(points: GradePoint[], index: number): number {
  const a = points[index - 1] as GradePoint
  const b = points[index] as GradePoint
  return (b.altitude - a.altitude) / (b.distance - a.distance)
}

function deltaKinds(points: GradePoint[]): GradeClass[] {
  const kinds = points.map((_, index) => (index === 0 ? 'flat' : classify(windowGrade(points, index))) as GradeClass)
  const trim = (from: number, to: number, kind: GradeClass) => {
    let start = from
    let end = to
    while (start <= end && classify(rawGrade(points, start)) !== kind) {
      kinds[start] = classify(rawGrade(points, start))
      start += 1
    }
    while (end >= start && classify(rawGrade(points, end)) !== kind) {
      kinds[end] = classify(rawGrade(points, end))
      end -= 1
    }
  }
  let index = 1
  while (index < points.length) {
    const kind = kinds[index] as GradeClass
    let end = index
    while (end + 1 < points.length && kinds[end + 1] === kind) end += 1
    if (kind !== 'flat') trim(index, end, kind)
    index = end + 1
  }
  return kinds
}

function gradeSegments(samples: FitSample[]): GradeSegment[] {
  const segments: GradeSegment[] = []
  for (const points of gradeRuns(samples)) {
    const kinds = deltaKinds(points)
    let current: GradeSegment | null = null
    for (let index = 1; index < points.length; index += 1) {
      const kind = kinds[index] as GradeClass
      if (current === null || current.kind !== kind) {
        if (current !== null) segments.push(current)
        current = { kind, length: 0, climb: 0, samples: [] }
      }
      const a = points[index - 1] as GradePoint
      const b = points[index] as GradePoint
      current.length += b.distance - a.distance
      current.climb += b.altitude - a.altitude
      current.samples.push(b.sample)
    }
    if (current !== null) segments.push(current)
  }
  return segments
}

const gradeOf = (segment: GradeSegment) => (segment.length > 0 ? segment.climb / segment.length : 0)

export function hillIndex(samples: FitSample[]): number | null {
  const segments = gradeSegments(samples)
  const climbs = segments.filter((segment) => segment.kind === 'up' && segment.length >= FIT.climbMinimumLength && gradeOf(segment) >= FIT.climbMinimumGrade)
  const flatCost = minettiCost(0)
  const climbSamples = climbs.flatMap((segment) =>
    segment.samples.flatMap((sample) => (sample.speed !== null && sample.speed > 0 ? [{ speed: (sample.speed * minettiCost(gradeOf(segment))) / flatCost, heartRate: sample.heartRate }] : [])),
  )
  const adjusted = mean(climbSamples.map((item) => item.speed))
  const climbHeartRate = mean(climbSamples.flatMap((item) => (item.heartRate === null ? [] : [item.heartRate])))
  if (adjusted === null || climbHeartRate === null) return null
  const flatSpeeds = segments
    .filter((segment) => segment.kind === 'flat')
    .flatMap((segment) => segment.samples)
    .flatMap((sample) => (sample.speed !== null && sample.speed > 0 && sample.heartRate !== null && Math.abs(sample.heartRate - climbHeartRate) <= FIT.flatHeartRateTolerance ? [sample.speed] : []))
  const flat = mean(flatSpeeds)
  return flat === null || flat <= 0 ? null : (100 * adjusted) / flat
}
