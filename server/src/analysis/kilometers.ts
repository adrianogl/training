import type { FitSample, LapSummary, PrescribedStep } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'
import type { BlockKilometers, BlockKind, HeartRateZones, TrackPoint, WorkoutBlock } from './analysisTypes.js'
import { targetStatus, zoneOf } from './blocks.js'

function trackPoints(samples: FitSample[]): TrackPoint[] {
  let integrated = 0
  let previous: FitSample | undefined
  return [...samples]
    .sort((a, b) => a.t - b.t)
    .map((sample) => {
      if (previous !== undefined && previous.speed !== null) integrated += previous.speed * Math.max(0, sample.t - previous.t)
      previous = sample
      return { t: sample.t, distance: sample.distance ?? integrated, heartRate: sample.heartRate }
    })
}

const isPause = (interval: number, distance: number) => interval > ANALYSIS.pauseGapSeconds && distance < interval * ANALYSIS.pauseMaximumSpeed

function kilometer(ordinal: number, kind: BlockKind, start: number, seconds: number, distance: number, heartRates: number[], prescribed: PrescribedStep | null, zones: HeartRateZones | null): WorkoutBlock {
  const speed = seconds > 0 ? distance / seconds : null
  const average = heartRates.length === 0 ? null : Math.round(heartRates.reduce((sum, value) => sum + value, 0) / heartRates.length)
  const maximum = heartRates.length === 0 ? null : Math.max(...heartRates)
  const lap: LapSummary = { stepIndex: null, intensity: null, trigger: null, startOffset: start, timerSeconds: seconds, distance, avgSpeed: speed, avgHeartRate: average, maxHeartRate: maximum }
  return {
    kind, ordinal, label: `${ANALYSIS.labels.kilometer} ${ordinal}`, prescribed, laps: [lap], seconds, distance, avgSpeed: speed, avgHeartRate: average, maxHeartRate: maximum,
    dominantZone: average === null ? null : zoneOf(average, zones),
    status: prescribed === null ? 'noTarget' : targetStatus(prescribed.target, speed, average, zones),
  }
}

function split(points: TrackPoint[], start: number, kind: BlockKind, prescribed: PrescribedStep | null, zones: HeartRateZones | null): WorkoutBlock[] {
  const first = points[0]
  const last = points.at(-1)
  if (first === undefined || last === undefined) return []
  const rows: WorkoutBlock[] = []
  let startTime = start
  let startDistance = first.distance
  let previousTime = start
  let previousDistance = first.distance
  let seconds = 0
  let heartRates: number[] = []
  const close = (point: TrackPoint) => rows.push(kilometer(rows.length + 1, kind, startTime, seconds, point.distance - startDistance, heartRates, prescribed, zones))
  for (const point of points) {
    const interval = point.t - previousTime
    if (!isPause(interval, point.distance - previousDistance)) seconds += Math.max(0, interval)
    previousTime = point.t
    previousDistance = point.distance
    if (point.heartRate !== null) heartRates.push(point.heartRate)
    if (point.distance - startDistance < ANALYSIS.kilometerSplitDistance) continue
    close(point)
    startTime = point.t
    startDistance = point.distance
    seconds = 0
    heartRates = []
  }
  if (last.distance - startDistance >= ANALYSIS.minimumPartialSplit) close(last)
  return rows
}

export function kilometerSplits(samples: FitSample[], zones: HeartRateZones | null): WorkoutBlock[] {
  const points = trackPoints(samples)
  const first = points[0]
  return first === undefined ? [] : split(points, first.t, 'active', null, zones)
}

const opensInKilometers = (block: WorkoutBlock) => block.distance >= ANALYSIS.splitBlockMinimumDistance || block.seconds >= ANALYSIS.splitBlockMinimumSeconds

export function blockKilometers(blocks: WorkoutBlock[], samples: FitSample[], zones: HeartRateZones | null): BlockKilometers {
  const points = trackPoints(samples)
  const result: BlockKilometers = new Map()
  blocks.forEach((block, position) => {
    if (!opensInKilometers(block)) return
    const firstLap = block.laps[0]
    if (firstLap === undefined) return
    const end = blocks.slice(position + 1).map((next) => next.laps[0]?.startOffset).find((value) => value !== undefined) ?? Number.POSITIVE_INFINITY
    const window = points.filter((point) => point.t >= firstLap.startOffset && point.t <= end)
    const rows = split(window, firstLap.startOffset, block.kind, block.prescribed, zones)
    if (rows.length > 0) result.set(position, rows)
  })
  return result
}
