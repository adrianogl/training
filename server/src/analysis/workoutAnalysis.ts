import type { FitSample, FitSummary } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'
import type { AnalysisInput, ComparisonRow, EvolutionFacts, HeartRateZones, WorkoutAnalysis, WorkoutBlock, WorkoutComparison, WorkoutOccurrence } from './analysisTypes.js'
import { assess } from './assessment.js'
import { buildBlocks, hasPrescription } from './blocks.js'
import { compare } from './comparison.js'
import { runContinuity } from './continuity.js'
import { blockKilometers, kilometerSplits } from './kilometers.js'
import { evolutionText, narrate } from './narrative.js'
import { scoreWorkout } from './workoutScore.js'
import { comparisonKey } from './workoutTitle.js'

export function thresholdZones(thresholdHeartRate: number): HeartRateZones {
  const inner = ANALYSIS.thresholdFloorFractions.map((fraction) => Math.round(thresholdHeartRate * fraction))
  return { floors: [0, ...inner, thresholdHeartRate], maxHeartRate: null }
}

export function zonesFor(fit: FitSummary): HeartRateZones | null {
  const info = fit.zoneInfo
  if (info === null) return null
  if (info.thresholdHeartRate !== null) return { ...thresholdZones(info.thresholdHeartRate), maxHeartRate: info.maxHeartRate }
  return info.floors.length === ANALYSIS.zoneCount ? { floors: info.floors, maxHeartRate: info.maxHeartRate } : null
}

export function zoneSeconds(samples: FitSample[], zones: HeartRateZones): number[] | null {
  if (zones.floors.length === 0) return null
  const seconds = zones.floors.map(() => 0)
  samples.forEach((sample, index) => {
    const next = samples[index + 1]
    if (sample.heartRate === null || sample.heartRate <= 0 || next === undefined) return
    const gap = Math.min(Math.max(next.t - sample.t, 0), ANALYSIS.maxSampleGap)
    let zone = 0
    zones.floors.forEach((floor, position) => {
      if (sample.heartRate !== null && sample.heartRate >= floor) zone = position
    })
    seconds[zone] = (seconds[zone] ?? 0) + gap
  })
  return samples.some((sample) => (sample.heartRate ?? 0) > 0) ? seconds : null
}

const blocksOf = (fit: FitSummary, zones: HeartRateZones | null): WorkoutBlock[] => buildBlocks(fit.structure, zones)

function downsample<T>(items: T[], limit: number): T[] {
  if (items.length <= limit) return items
  const step = items.length / limit
  return Array.from({ length: limit }, (_, index) => items[Math.floor(index * step)] as T)
}

const hasTarget = (block: WorkoutBlock) => block.prescribed !== null && block.prescribed.target.kind !== 'open'

function activeRows(comparison: WorkoutComparison, occurrences: WorkoutOccurrence[], activeLabels: Set<string>): ComparisonRow[] {
  return comparison.occurrences.flatMap((id, index) => {
    const occurrence = occurrences.find((item) => item.activityId === id)
    if (occurrence === undefined) return []
    const active = occurrence.blocks.filter((block) => block.kind === 'active' && (activeLabels.size === 0 || activeLabels.has(block.label)))
    const seconds = active.reduce((sum, block) => sum + block.seconds, 0)
    const speed = seconds > 0 ? active.reduce((sum, block) => sum + block.distance, 0) / seconds : null
    const withHeartRate = active.filter((block) => block.avgHeartRate !== null && block.seconds > 0)
    const heartRateSeconds = withHeartRate.reduce((sum, block) => sum + block.seconds, 0)
    const heartRate = heartRateSeconds > 0 ? withHeartRate.reduce((sum, block) => sum + (block.avgHeartRate ?? 0) * block.seconds, 0) / heartRateSeconds : null
    const targeted = active.filter(hasTarget)
    return [{
      activityId: id, day: occurrence.day, isCurrent: index === 0,
      secondsPerKilometer: speed === null ? null : ANALYSIS.metersPerKilometer / speed,
      heartRate,
      inTarget: targeted.length === 0 ? null : { done: targeted.filter((block) => block.status === 'inTarget').length, total: targeted.length },
    }]
  })
}

function totalRows(comparison: WorkoutComparison, input: AnalysisInput): ComparisonRow[] {
  const records = [input, ...input.previous]
  return comparison.occurrences.flatMap((id, index) => {
    const record = records.find((item) => item.activityId === id)
    if (record === undefined) return []
    const pace = record.distance !== null && record.distance > 0 && record.movingSeconds !== null ? record.movingSeconds / (record.distance / ANALYSIS.metersPerKilometer) : null
    return [{ activityId: id, day: record.day, isCurrent: index === 0, secondsPerKilometer: pace, heartRate: record.averageHeartRate, inTarget: null }]
  })
}

function rowEvolution(rows: ComparisonRow[]): EvolutionFacts | null {
  const current = rows[0]
  const oldest = rows.at(-1)
  if (rows.length <= 1 || current === undefined || oldest === undefined || current.secondsPerKilometer === null || oldest.secondsPerKilometer === null) return null
  return {
    paceDelta: current.secondsPerKilometer - oldest.secondsPerKilometer,
    heartRateDelta: current.heartRate !== null && oldest.heartRate !== null ? current.heartRate - oldest.heartRate : null,
    oldestDate: oldest.day,
  }
}

function deltaEvolution(comparison: WorkoutComparison, rows: ComparisonRow[]): EvolutionFacts | null {
  const oldest = rows.at(-1)
  const currentPace = rows[0]?.secondsPerKilometer ?? null
  if (rows.length <= 1 || oldest === undefined || currentPace === null || comparison.activeSpeedDelta === null) return null
  const currentSpeed = ANALYSIS.metersPerKilometer / currentPace
  const oldestSpeed = currentSpeed - comparison.activeSpeedDelta
  if (oldestSpeed <= 0) return null
  return { paceDelta: currentPace - ANALYSIS.metersPerKilometer / oldestSpeed, heartRateDelta: comparison.activeHeartRateDelta, oldestDate: oldest.day }
}

export function analyzeWorkout(input: AnalysisInput, formatDay: (day: string) => string): WorkoutAnalysis {
  const empty: WorkoutAnalysis = { isRun: input.isRun, hasPrescription: false, workoutName: null, zones: null, zoneSeconds: null, blocks: [], kilometers: [], splits: [], chart: [], route: [], findings: [], score: null, comparison: null }
  const fit = input.fit
  if (fit === null) return empty
  const prescribed = hasPrescription(fit.structure)
  const base = { ...empty, hasPrescription: prescribed, workoutName: fit.structure.prescription?.name ?? null, route: fit.route, chart: downsample(fit.samples, ANALYSIS.chartPointLimit) }
  if (!input.isRun) return base
  const zones = zonesFor(fit)
  const blocks = blocksOf(fit, zones)
  const kilometers = prescribed ? blockKilometers(blocks, fit.samples, zones) : new Map<number, WorkoutBlock[]>()
  const previous: WorkoutOccurrence[] = input.previous.flatMap((item) => {
    const itemBlocks = blocksOf(item.fit, zonesFor(item.fit))
    return itemBlocks.length === 0 ? [] : [{ activityId: item.activityId, day: item.day, blocks: itemBlocks }]
  })
  const assessment = assess(blocks, { readinessScore: input.readinessScore, acuteChronic: input.acuteChronic, previous: previous.map((item) => item.blocks), kilometers, continuity: runContinuity(fit.samples) })
  const current: WorkoutOccurrence = { activityId: input.activityId, day: input.day, blocks }
  const comparison = compare(current, previous)
  let comparisonView: WorkoutAnalysis['comparison'] = null
  if (comparison !== null) {
    let rows: ComparisonRow[]
    let evolution: EvolutionFacts | null
    let notice: string | null = null
    if (!prescribed) {
      rows = totalRows(comparison, input)
      evolution = rowEvolution(rows)
    } else {
      const common = new Set(comparison.blocks.map((item) => item.label))
      const activeLabels = new Set(blocks.filter((block) => block.kind === 'active' && common.has(block.label)).map((block) => block.label))
      rows = activeRows(comparison, [current, ...previous], activeLabels)
      if (activeLabels.size === 0) {
        evolution = rowEvolution(rows)
        notice = comparison.sameStructure ? null : ANALYSIS.ownActiveBlocksNotice
      } else {
        evolution = deltaEvolution(comparison, rows)
        notice = comparison.sameStructure ? null : ANALYSIS.commonBlocksNotice
      }
    }
    comparisonView = { rows, notice, evolution: evolution === null ? null : evolutionText({ ...evolution, oldestDate: formatDay(evolution.oldestDate) }) }
  }
  return {
    ...base,
    zones,
    zoneSeconds: zones === null ? null : zoneSeconds(fit.samples, zones),
    blocks,
    kilometers: [...kilometers.entries()].map(([block, rows]) => ({ block, rows })),
    splits: kilometerSplits(fit.samples, zones),
    findings: narrate(assessment, blocks),
    score: scoreWorkout(blocks, zones, previous),
    comparison: comparisonView,
  }
}

export function comparisonCandidates<T extends { id: number; name: string; day: string; startLocal: string; distanceMeters: number | null; workoutId: number | null; type: string }>(current: T, all: T[], isRun: (item: T) => boolean): T[] {
  const earlier = all.filter((item) => item.id !== current.id && item.startLocal < current.startLocal)
  let matches: T[]
  if (current.workoutId !== null) {
    const key = comparisonKey(current.name)
    matches = earlier.filter((item) => item.workoutId === current.workoutId || (item.workoutId !== null && key.length > 0 && comparisonKey(item.name) === key))
  } else {
    const meters = current.distanceMeters ?? 0
    if (meters <= 0) return []
    const windowStart = new Date(new Date(`${current.day}T12:00:00Z`).getTime() - ANALYSIS.similarRunWindowDays * 86_400_000).toISOString().slice(0, 10)
    matches = earlier.filter((item) => isRun(item) && item.day >= windowStart && item.distanceMeters !== null && Math.abs(item.distanceMeters - meters) / meters <= ANALYSIS.similarDistanceTolerance)
  }
  return matches.sort((a, b) => (a.startLocal < b.startLocal ? 1 : -1)).slice(0, ANALYSIS.maxComparisons)
}
