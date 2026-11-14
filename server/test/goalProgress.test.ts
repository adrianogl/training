import { describe, expect, it } from 'vitest'
import { meetsContinuousGoal, runContinuity } from '../src/analysis/continuity.js'
import { longCandidates, longGoalProgress, timeGoalProgress } from '../src/domain/goalProgress.js'
import { addDays } from '../src/garminSync.js'
import type { FitSample } from '../src/fit/fitTypes.js'
import type { ActivitySummary, GoalItem } from '../src/types.js'

const speed = 1000 / 285

function sample(t: number, distance: number): FitSample {
  return { t, heartRate: null, speed: null, altitude: null, distance }
}

function steady(start: number, meters: number, from: number): FitSample[] {
  return Array.from({ length: Math.floor(meters / speed) }, (_, index) => sample(start + index + 1, from + (index + 1) * speed))
}

function withStop(stopAtMeters: number, stopSeconds: number, totalMeters: number): FitSample[] {
  const first = steady(0, stopAtMeters, 0)
  const stopAt = first[first.length - 1]?.t ?? 0
  const stopped = Array.from({ length: stopSeconds }, (_, index) => sample(stopAt + index + 1, stopAtMeters))
  return [sample(0, 0), ...first, ...stopped, ...steady(stopAt + stopSeconds, totalMeters - stopAtMeters, stopAtMeters)]
}

const today = '2026-11-14'

function run(id: number, day: string, distanceMeters: number, durationSeconds: number): ActivitySummary {
  return {
    id, name: 'Corrida', type: 'running', startLocal: `${day}T07:00:00`, day, distanceMeters, durationSeconds, movingSeconds: durationSeconds, elevationGain: 0,
    averageSpeed: distanceMeters / durationSeconds, maxSpeed: 4, averageHeartRate: 150, maxHeartRate: 170, cadence: 170, trainingLoad: 100, aerobicEffect: 3, anaerobicEffect: 1, vo2max: 52,
    zoneSeconds: [0, 0, 0, 0, 0], fastestKmSeconds: 240, fastest5kSeconds: 1230, laps: 10, workoutId: null,
  }
}

const longGoal: GoalItem = { id: 'L', kind: 'continuousLong', distanceKm: 16, targetSeconds: null, deadline: null, paceSecondsPerKm: 290, archived: false, achievedAt: null, createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z' }
const timeGoal: GoalItem = { ...longGoal, id: 'T', kind: 'time', distanceKm: 10, targetSeconds: 2400, deadline: '2027-03-15', paceSecondsPerKm: null }

describe('continuidade do treino', () => {
  it('sem parada cumpre a meta; com parada sem pausa automática, não', () => {
    const clean = runContinuity([sample(0, 0), ...steady(0, 16000, 0)])
    expect(clean?.pauses).toEqual([])
    expect(clean && meetsContinuousGoal(clean, 16, 290)).toBe(true)

    const stopped = runContinuity(withStop(11800, 38, 16000))
    expect(stopped?.pauses).toHaveLength(1)
    expect(stopped?.pauses[0]?.seconds).toBe(38)
    expect(Math.abs((stopped?.longestContinuousMeters ?? 0) - 11800)).toBeLessThan(5)
    expect(stopped && meetsContinuousGoal(stopped, 16, 290)).toBe(false)
  })

  it('ignora amostras sem distância', () => {
    expect(runContinuity([{ t: 0, heartRate: 120, speed: null, altitude: null, distance: null }])).toBeNull()
  })
})

describe('progresso das metas', () => {
  it('longão: últimos seis longos, maior trecho e quantos cumpriram', () => {
    const runs = [run(1, '2026-10-20', 15000, 4300), run(2, '2026-11-01', 16100, 4600), run(3, '2026-11-08', 9000, 2600), run(4, '2026-11-12', 16200, 4630)]
    const candidates = longCandidates(longGoal, runs)
    expect(candidates.map((item) => item.id)).toEqual([4, 2, 1])
    const progress = longGoalProgress(longGoal, candidates, new Map([[2, withStop(10600, 30, 16100)], [4, [sample(0, 0), ...steady(0, 16200, 0)]]]))
    expect(progress.runs.map((check) => [check.activityId, check.met])).toEqual([[1, null], [2, false], [4, true]])
    expect(progress.metCount).toBe(1)
    expect(progress.bestContinuousKm).toBeCloseTo(16.2, 1)
    expect(progress.achievedOn).toBe('2026-11-12')
  })

  it('longão: só entram treinos classificados como longão', () => {
    const named = (id: number, name: string, meters: number): ActivitySummary => ({ ...run(id, '2026-11-05', meters, 4000), name })
    const runs = [
      named(1, 'Rodagem', 12660),
      named(2, 'Longão de domingo', 9000),
      named(3, 'Tiros 6x1000', 15500),
      named(4, 'Corrida matinal', 14200),
      named(5, 'Rodagem leve', 16000),
      named(6, 'Corrida matinal', 13900),
    ]
    expect(longCandidates(longGoal, runs).map((item) => item.id).sort()).toEqual([2, 4])
  })

  it('tempo: previsão de hoje, distância até a meta e prova que já cumpriu', () => {
    const efforts = Array.from({ length: 20 }, (_, index) => ({ distance: 5000, seconds: 1260 - index * 2, day: addDays(today, -index * 4), kind: 'split5k' as const }))
    const progress = timeGoalProgress(timeGoal, efforts, [], today)
    expect(progress.todaySeconds).not.toBeNull()
    expect(progress.gapSeconds).toBeCloseTo((progress.todaySeconds ?? 0) - 2400, 5)
    expect(progress.achievedOn).toBeNull()

    const done = timeGoalProgress(timeGoal, efforts, [run(9, '2026-11-10', 10020, 2395)], today)
    expect(done.achievedOn).toBe('2026-11-10')
  })
})
