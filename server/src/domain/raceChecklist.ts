import { addDays } from '../garminSync.js'
import { CHECKLIST } from './domainConstants.js'
import type { ChecklistItem, ChecklistRun, Lap, ProfilePoint } from './domainTypes.js'
import { weekStartOf } from './today.js'

export function weeklyVolumeTarget(distance: number): number {
  return CHECKLIST.weeklyVolumeTargets.find(([upTo]) => distance <= upTo)?.[1] ?? 0
}

export function racePaceTarget(distance: number): number {
  return Math.round((distance / 1000) * CHECKLIST.racePaceVolumeRatio)
}

export function tuneUpDistance(distance: number): number {
  return Math.floor(distance / 1000 / 2)
}

export function recentAverage(weeklyKm: Map<string, number>, today: string): number | null {
  const current = weekStartOf(today)
  const known = Array.from({ length: CHECKLIST.recentWeeks }, (_, index) => weeklyKm.get(addDays(current, -7 * (index + 1)))).filter((value): value is number => value !== undefined)
  return known.length === 0 ? null : known.reduce((sum, value) => sum + value, 0) / CHECKLIST.recentWeeks
}

export function racePaceKm(laps: Lap[], targetPace: number): number {
  return (
    laps
      .filter((lap) => lap.distance >= 1000 * CHECKLIST.fullSplitRatio && lap.seconds > 0)
      .filter((lap) => {
        const pace = lap.seconds / (lap.distance / 1000)
        return pace >= targetPace - CHECKLIST.racePaceFaster && pace <= targetPace + CHECKLIST.racePaceSlower
      })
      .reduce((sum, lap) => sum + lap.distance, 0) / 1000
  )
}

export interface ChecklistInput {
  today: string
  blockStart: string
  distance: number
  goalSeconds: number | null
  priority: string
  profile: ProfilePoint[] | null
  targetPace: number | null
  weeklyKm: Map<string, number>
  runs: ChecklistRun[]
}

export function raceChecklist(input: ChecklistInput): ChecklistItem[] {
  const inBlock = input.runs.filter((run) => run.day >= input.blockStart)
  const volumeTarget = weeklyVolumeTarget(input.distance)
  const average = recentAverage(input.weeklyKm, input.today)
  const paceTarget = racePaceTarget(input.distance)
  const done = input.targetPace === null ? 0 : racePaceKm(inBlock.flatMap((run) => run.laps), input.targetPace)
  const tuneUpKm = tuneUpDistance(input.distance)
  const pace = input.targetPace
  const tuneUps =
    pace === null
      ? []
      : inBlock.filter((run) => (run.distance ?? 0) >= tuneUpKm * 1000 * CHECKLIST.tuneUpDistanceRatio && (run.seconds ?? 0) > 0 && (run.seconds ?? 0) / ((run.distance ?? 1) / 1000) <= pace + CHECKLIST.tuneUpPaceMargin)
  const best = tuneUps.reduce<ChecklistRun | undefined>((latest, run) => (latest === undefined || run.day >= latest.day ? run : latest), undefined)
  const profile = input.profile !== null && input.profile.length > 1 ? input.profile : null
  const gain = profile === null ? null : profile.slice(1).reduce((sum, point, index) => sum + Math.max(0, point.altitude - (profile[index]?.altitude ?? point.altitude)), 0)
  return [
    { kind: 'weeklyVolume', status: average === null ? 'missing' : average >= volumeTarget ? 'ok' : 'attention', targetKm: volumeTarget, averageKm: average },
    { kind: 'racePace', status: pace === null ? 'missing' : done >= paceTarget ? 'ok' : 'attention', targetKm: paceTarget, doneKm: done, pace },
    {
      kind: 'tuneUp',
      status: best === undefined ? 'missing' : 'ok',
      distanceKm: tuneUpKm,
      best: best === undefined ? null : { day: best.day, km: (best.distance ?? 0) / 1000, pace: (best.seconds ?? 0) / ((best.distance ?? 1) / 1000) },
    },
    { kind: 'course', status: profile === null ? 'missing' : 'ok', km: profile === null ? null : (profile.at(-1)?.distance ?? 0) / 1000, gain: gain === null ? null : Math.round(gain) },
    { kind: 'goal', status: input.goalSeconds === null ? 'missing' : 'ok', goalSeconds: input.goalSeconds, priority: input.priority },
  ]
}
