import type { LapSummary } from '../fit/fitTypes.js'
import { ANALYSIS } from './analysisConstants.js'
import { flatPace, hasElevation } from './elevation.js'
import type { AssessmentContext, BlockKilometers, BlockStatus, Finding, RunContinuity, WorkoutAssessment, WorkoutBlock } from './analysisTypes.js'

const hasTarget = (block: WorkoutBlock) => block.prescribed !== null && block.prescribed.target.kind !== 'open'

function lapSpeed(lap: LapSummary): number {
  if (lap.avgSpeed !== null) return lap.avgSpeed
  return lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : 0
}

const pace = (lap: LapSummary) => 1000 / lapSpeed(lap)
const levelPace = (lap: LapSummary) => flatPace(lap) ?? pace(lap)

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0 ? ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2 : (sorted[middle] ?? 0)
}

function meanHeartRate(laps: LapSummary[]): number | null {
  const values = laps.flatMap((lap) => (lap.avgHeartRate === null ? [] : [lap.avgHeartRate]))
  return values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length
}

const meanSpeed = (laps: LapSummary[]) => laps.reduce((sum, lap) => sum + lapSpeed(lap), 0) / laps.length

function eligibleForLapRules(blocks: WorkoutBlock[], kilometers: BlockKilometers): { position: number; laps: LapSummary[] }[] {
  return blocks.flatMap((block, position) => {
    if (block.kind !== 'active') return []
    const laps = kilometers.get(position)?.flatMap((row) => row.laps) ?? block.laps
    const full = laps.filter((lap) => lap.distance >= ANALYSIS.fullLapMinimumDistance && lapSpeed(lap) > 0)
    return full.length >= ANALYSIS.minimumFullLaps ? [{ position, laps: full }] : []
  })
}

function blockInTarget(blocks: WorkoutBlock[]): Finding[] {
  const targeted = blocks.filter((block) => block.kind === 'active' && hasTarget(block))
  const inTarget = targeted.filter((block) => block.status === 'inTarget').length
  return inTarget > 0 ? [{ group: 'positive', kind: 'blockInTarget', blockOrdinal: null, facts: { inTarget, total: targeted.length } }] : []
}

function steadyPace(blocks: WorkoutBlock[], kilometers: BlockKilometers): Finding[] {
  return eligibleForLapRules(blocks, kilometers).flatMap(({ position, laps }) => {
    const paces = laps.map(levelPace)
    const fastest = Math.min(...paces)
    const slowest = Math.max(...paces)
    const spread = slowest - fastest
    if (spread > ANALYSIS.steadyPaceSpread) return []
    const facts: Record<string, number> = { spread, fastestPace: fastest, slowestPace: slowest }
    if (laps.some(hasElevation)) facts.flatAdjusted = 1
    return [{ group: 'positive' as const, kind: 'steadyPace' as const, blockOrdinal: position, facts }]
  })
}

function paceFade(blocks: WorkoutBlock[], kilometers: BlockKilometers): Finding[] {
  return eligibleForLapRules(blocks, kilometers).flatMap(({ position, laps }) => {
    const paces = laps.map(levelPace)
    const last = paces.at(-1)
    const lastLap = laps.at(-1)
    if (last === undefined || lastLap === undefined) return []
    const middle = median(paces)
    const fade = last - middle
    if (fade < ANALYSIS.fadeThreshold) return []
    const facts: Record<string, number> = { fade, lastPace: last, medianPace: middle }
    if (laps.some(hasElevation)) {
      facts.flatAdjusted = 1
      facts.pace = pace(lastLap)
      facts.lastClimb = lastLap.climb ?? 0
    }
    return [{ group: 'negative' as const, kind: 'paceFade' as const, blockOrdinal: position, facts }]
  })
}

function elevationKind(lap: LapSummary): 'climbSlower' | 'descentFaster' | null {
  const level = flatPace(lap)
  if (!hasElevation(lap) || level === null) return null
  const effect = pace(lap) - level
  if (effect >= ANALYSIS.elevationEffectSeconds) return 'climbSlower'
  if (effect <= -ANALYSIS.elevationEffectSeconds) return 'descentFaster'
  return null
}

function elevationFinding(kind: 'climbSlower' | 'descentFaster', position: number, from: number, laps: LapSummary[]): Finding {
  const distance = laps.reduce((sum, lap) => sum + lap.distance, 0) / ANALYSIS.metersPerKilometer
  const weighted = (value: (lap: LapSummary) => number) => laps.reduce((sum, lap) => sum + (lap.distance * value(lap)) / ANALYSIS.metersPerKilometer, 0) / distance
  return {
    group: 'positive',
    kind,
    blockOrdinal: position,
    facts: {
      fromKilometer: from,
      toKilometer: from + laps.length - 1,
      climb: laps.reduce((sum, lap) => sum + (lap.climb ?? 0), 0),
      descent: laps.reduce((sum, lap) => sum + (lap.descent ?? 0), 0),
      pace: weighted(pace),
      flatPace: weighted(levelPace),
    },
  }
}

function elevationPace(blocks: WorkoutBlock[], kilometers: BlockKilometers): Finding[] {
  const findings: Finding[] = []
  for (const [position, rows] of [...kilometers.entries()].sort((a, b) => a[0] - b[0])) {
    if (blocks[position]?.kind !== 'active') continue
    const startKm = Math.round(blocks.slice(0, position).reduce((sum, block) => sum + block.distance, 0) / ANALYSIS.metersPerKilometer)
    let segment: { kind: 'climbSlower' | 'descentFaster'; from: number; laps: LapSummary[] } | null = null
    const close = () => {
      if (segment !== null) findings.push(elevationFinding(segment.kind, position, segment.from, segment.laps))
      segment = null
    }
    rows.forEach((row, index) => {
      const lap = row.laps[0]
      const kind = lap !== undefined && lap.distance >= ANALYSIS.fullLapMinimumDistance ? elevationKind(lap) : null
      if (lap === undefined || kind === null) {
        close()
        return
      }
      const current = segment as { kind: 'climbSlower' | 'descentFaster'; from: number; laps: LapSummary[] } | null
      if (current !== null && current.kind === kind) {
        current.laps.push(lap)
      } else {
        close()
        segment = { kind, from: startKm + index + 1, laps: [lap] }
      }
    })
    close()
  }
  return findings
}

function cardiacDrift(blocks: WorkoutBlock[], kilometers: BlockKilometers): Finding[] {
  return eligibleForLapRules(blocks, kilometers).flatMap(({ position, laps }) => {
    const third = Math.max(1, Math.floor(laps.length / 3))
    const first = laps.slice(0, third)
    const final = laps.slice(-third)
    const fromHR = meanHeartRate(first)
    const toHR = meanHeartRate(final)
    if (fromHR === null || toHR === null || fromHR <= 0) return []
    const rise = toHR / fromHR - 1
    const speedChange = Math.abs(meanSpeed(final) / meanSpeed(first) - 1)
    return rise >= ANALYSIS.driftThreshold && speedChange <= ANALYSIS.driftMaxSpeedChange
      ? [{ group: 'attention' as const, kind: 'cardiacDrift' as const, blockOrdinal: position, facts: { rise, fromHR, toHR } }]
      : []
  })
}

function goodRecovery(blocks: WorkoutBlock[]): Finding[] {
  return blocks.flatMap((recovery, position) => {
    const active = blocks[position - 1]
    if (position === 0 || active === undefined || recovery.kind !== 'recovery' || active.kind !== 'active') return []
    const peak = active.maxHeartRate
    const recovered = recovery.avgHeartRate
    if (peak === null || recovered === null) return []
    const drop = peak - recovered
    return drop >= ANALYSIS.goodRecoveryDrop ? [{ group: 'positive' as const, kind: 'goodRecovery' as const, blockOrdinal: position, facts: { drop, peak, recovered } }] : []
  })
}

function lowerHeartRateThanBefore(blocks: WorkoutBlock[], previous: WorkoutBlock[][]): Finding[] {
  return blocks.flatMap((block, position) => {
    const heartRate = block.avgHeartRate
    const speed = block.avgSpeed
    if (block.kind !== 'active' || heartRate === null || speed === null) return []
    const before = previous.map((list) => list.find((item) => item.label === block.label)).find((item) => item !== undefined)
    const beforeHeartRate = before?.avgHeartRate ?? null
    const beforeSpeed = before?.avgSpeed ?? null
    if (beforeHeartRate === null || beforeSpeed === null || beforeSpeed <= 0) return []
    const delta = beforeHeartRate - heartRate
    return delta >= ANALYSIS.lowerHeartRateMargin && Math.abs(speed / beforeSpeed - 1) <= ANALYSIS.sameSpeedTolerance
      ? [{ group: 'positive' as const, kind: 'lowerHeartRateThanBefore' as const, blockOrdinal: position, facts: { delta, heartRate, beforeHeartRate, speed } }]
      : []
  })
}

const OFF_TARGET: BlockStatus[] = ['faster', 'slower', 'aboveTarget', 'belowTarget']

function blockOffTarget(blocks: WorkoutBlock[]): Finding[] {
  const recoveries = blocks.filter((block) => block.kind === 'recovery').flatMap((block) => (block.avgHeartRate === null ? [] : [block.avgHeartRate]))
  const highestRecovery = recoveries.length === 0 ? null : Math.max(...recoveries)
  return blocks.flatMap((block, position) => {
    if (!OFF_TARGET.includes(block.status)) return []
    const facts: Record<string, number> = {}
    if (block.avgSpeed !== null) facts.speed = block.avgSpeed
    if (block.avgHeartRate !== null) facts.heartRate = block.avgHeartRate
    const before = blocks[position - 1]
    if (position > 0 && before?.kind === 'recovery' && before.avgHeartRate !== null) {
      facts.recoveryHeartRate = before.avgHeartRate
      facts.recoveryHighest = before.avgHeartRate === highestRecovery ? 1 : 0
    }
    const target = block.prescribed?.target
    if (target?.kind === 'speed' || target?.kind === 'heartRateBpm') {
      if (target.low > 0) facts.targetLow = target.low
      if (target.high > 0) facts.targetHigh = target.high
    }
    return [{ group: 'negative' as const, kind: 'blockOffTarget' as const, blockOrdinal: position, facts }]
  })
}

function slowdownFacts(kilometers: WorkoutBlock[]): Record<string, number> {
  const rows = kilometers.flatMap((row, index) => {
    const lap = row.laps[0]
    return lap !== undefined && lap.distance >= ANALYSIS.fullLapMinimumDistance && lapSpeed(lap) > 0 ? [{ kilometer: index + 1, lap }] : []
  })
  const baseline = ANALYSIS.baselineKilometers
  if (rows.length <= baseline) return {}
  const paces = rows.map((row) => levelPace(row.lap))
  const mean = (values: number[]) => values.reduce((sum, value) => sum + value, 0) / values.length
  const reference = mean(paces.slice(0, baseline))
  const facts: Record<string, number> = {}
  for (let index = baseline; index < rows.length; index += 1) {
    const slowdown = mean(paces.slice(index)) - reference
    if ((paces[index] ?? 0) - reference < ANALYSIS.fadeThreshold || slowdown < ANALYSIS.fadeThreshold) continue
    facts.fadeKilometer = rows[index]?.kilometer ?? 0
    facts.slowdown = slowdown
    break
  }
  if (rows.length < baseline * 2) return facts
  const start = meanHeartRate(rows.slice(0, baseline).map((row) => row.lap))
  const end = meanHeartRate(rows.slice(-baseline).map((row) => row.lap))
  if (start !== null && end !== null && end - start >= ANALYSIS.heartRateRiseMinimum) facts.heartRateRise = end - start
  return facts
}

function pauseFacts(continuity: RunContinuity | null): Record<string, number> {
  const first = continuity?.pauses[0]
  if (continuity === null || first === undefined) return {}
  return {
    pauseCount: continuity.pauses.length,
    pauseKilometer: first.startMeters / ANALYSIS.metersPerKilometer,
    pauseSeconds: continuity.pauses.reduce((sum, pause) => sum + pause.seconds, 0),
  }
}

function stepIncomplete(blocks: WorkoutBlock[], context: AssessmentContext): Finding[] {
  return blocks.flatMap((block, position) => {
    if (block.status !== 'incomplete' && block.status !== 'notExecuted') return []
    let facts: Record<string, number> = { distance: block.distance, seconds: block.seconds }
    const duration = block.prescribed?.duration
    if (duration?.kind === 'distance') facts.targetDistance = duration.meters
    if (duration?.kind === 'time') facts.targetSeconds = duration.seconds
    if (block.status === 'incomplete' && block.kind === 'active') {
      facts = { ...slowdownFacts(context.kilometers.get(position) ?? []), ...pauseFacts(context.continuity), ...facts }
      if (context.readinessScore !== null && context.readinessScore < ANALYSIS.lowReadiness) facts.readiness = context.readinessScore
      if (context.acuteChronic !== null && context.acuteChronic > ANALYSIS.highAcuteChronic) facts.ratio = context.acuteChronic
    }
    return [{ group: 'negative' as const, kind: 'stepIncomplete' as const, blockOrdinal: position, facts }]
  })
}

function zoneAboveTarget(blocks: WorkoutBlock[]): Finding[] {
  return blocks.flatMap((block, position) => {
    const zone = block.dominantZone
    if (block.kind === 'active' || zone === null || zone < ANALYSIS.easyBlockZoneLimit) return []
    const facts: Record<string, number> = { zone }
    if (block.avgSpeed !== null) facts.speed = block.avgSpeed
    if (block.avgHeartRate !== null) facts.heartRate = block.avgHeartRate
    return [{ group: 'attention' as const, kind: 'zoneAboveTarget' as const, blockOrdinal: position, facts }]
  })
}

function hardOnLowReadiness(blocks: WorkoutBlock[], readiness: number | null): Finding[] {
  if (readiness === null || readiness >= ANALYSIS.lowReadiness) return []
  const isHard = blocks.some((block) => block.kind === 'active' && (hasTarget(block) || (block.dominantZone ?? 0) >= ANALYSIS.hardZone))
  return isHard ? [{ group: 'attention', kind: 'hardOnLowReadiness', blockOrdinal: null, facts: { readiness } }] : []
}

function highAcuteChronic(ratio: number | null): Finding[] {
  return ratio !== null && ratio > ANALYSIS.highAcuteChronic ? [{ group: 'attention', kind: 'highAcuteChronic', blockOrdinal: null, facts: { ratio } }] : []
}

export function assess(blocks: WorkoutBlock[], context: AssessmentContext): WorkoutAssessment {
  const findings = [
    ...blockInTarget(blocks),
    ...steadyPace(blocks, context.kilometers),
    ...lowerHeartRateThanBefore(blocks, context.previous),
    ...goodRecovery(blocks),
    ...blockOffTarget(blocks),
    ...stepIncomplete(blocks, context),
    ...paceFade(blocks, context.kilometers),
    ...elevationPace(blocks, context.kilometers),
    ...cardiacDrift(blocks, context.kilometers),
    ...zoneAboveTarget(blocks),
    ...hardOnLowReadiness(blocks, context.readinessScore),
    ...highAcuteChronic(context.acuteChronic),
  ]
  return {
    positives: findings.filter((finding) => finding.group === 'positive'),
    negatives: findings.filter((finding) => finding.group === 'negative'),
    attention: findings.filter((finding) => finding.group === 'attention'),
  }
}
