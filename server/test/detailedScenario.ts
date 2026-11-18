import { FIT } from '../src/fit/fitConstants.js'
import type { DetailedInput, DetailedRun } from '../src/analysis/detailedTypes.js'
import type { FitSample, FitSummary } from '../src/fit/fitTypes.js'
import type { ActivitySummary, GoalItem, HealthDay } from '../src/types.js'

interface RunSpec {
  id: number
  day: string
  name: string
  plannedMeters: number | null
  paces: number[]
  tailMeters: number
  heartRates: [number, number]
}

const steady = (pace: number, count: number) => Array.from({ length: count }, () => pace)

function samplesFor(paces: number[], tailMeters: number, heartRates: [number, number]): FitSample[] {
  const segments = [...paces.map((pace) => ({ pace, meters: 1000 })), ...(tailMeters > 0 ? [{ pace: paces.at(-1) ?? 300, meters: tailMeters }] : [])]
  const total = segments.reduce((sum, segment) => sum + (segment.pace * segment.meters) / 1000, 0)
  const samples: FitSample[] = []
  let t = 0
  let meters = 0
  for (const segment of segments) {
    const seconds = (segment.pace * segment.meters) / 1000
    const speed = 1000 / segment.pace
    for (let offset = 0; offset < seconds; offset += 5) {
      const time = t + offset
      samples.push({ t: time, heartRate: Math.round(heartRates[0] + ((heartRates[1] - heartRates[0]) * time) / total), speed, altitude: null, distance: meters + speed * offset })
    }
    t += seconds
    meters += segment.meters
  }
  samples.push({ t, heartRate: heartRates[1], speed: 1000 / (paces.at(-1) ?? 300), altitude: null, distance: meters })
  return samples
}

export function scenarioRun(spec: RunSpec): DetailedRun {
  const samples = samplesFor(spec.paces, spec.tailMeters, spec.heartRates)
  const last = samples.at(-1)
  const distance = last?.distance ?? 0
  const seconds = last?.t ?? 0
  const activity: ActivitySummary = {
    id: spec.id, name: spec.name, type: 'running', startLocal: `${spec.day}T07:00:00`, day: spec.day, distanceMeters: distance, durationSeconds: seconds, movingSeconds: seconds,
    elevationGain: 20, averageSpeed: distance / seconds, maxSpeed: 4.5, averageHeartRate: Math.round((spec.heartRates[0] + spec.heartRates[1]) / 2), maxHeartRate: spec.heartRates[1] + 4,
    cadence: 172, trainingLoad: 120, aerobicEffect: 3, anaerobicEffect: 0.5, vo2max: 52, zoneSeconds: [60, 1200, 1800, 400, 0], fastestKmSeconds: 260, fastest5kSeconds: null, laps: null, workoutId: null,
  }
  const prescription = spec.plannedMeters === null ? null : { name: null, description: null, steps: [{ index: 0, intensity: 'active' as const, duration: { kind: 'distance' as const, meters: spec.plannedMeters }, target: { kind: 'open' as const } }] }
  const fit: FitSummary = { version: FIT.processingVersion, samples, route: [], physio: null, structure: { prescription, laps: [] }, zoneInfo: null }
  return { activity, fit }
}

const fading = (start: number, stableKm: number, tail: number[]) => [...steady(start, stableKm), ...tail]

export const currentSpec: RunSpec = {
  id: 100, day: '2026-11-14', name: 'Longão', plannedMeters: 20_000, paces: fading(271, 9, [283, 291, 299]), tailMeters: 660, heartRates: [158, 171],
}

export const similarSpecs: RunSpec[] = [
  { id: 11, day: '2026-08-26', name: 'Longão', plannedMeters: 20_000, paces: steady(275, 20), tailMeters: 0, heartRates: [150, 160] },
  { id: 12, day: '2026-09-05', name: 'Longão', plannedMeters: 20_000, paces: fading(270, 8, [282, 290, 296, 300, 305, 310]), tailMeters: 0, heartRates: [152, 168] },
  { id: 13, day: '2026-09-15', name: 'Longão', plannedMeters: 20_000, paces: steady(278, 20), tailMeters: 0, heartRates: [152, 163] },
  { id: 14, day: '2026-09-25', name: 'Longão', plannedMeters: null, paces: steady(272, 16), tailMeters: 0, heartRates: [150, 161] },
  { id: 15, day: '2026-10-05', name: 'Longão', plannedMeters: 20_000, paces: fading(268, 9, [281, 289]), tailMeters: 500, heartRates: [154, 170] },
  { id: 16, day: '2026-10-15', name: 'Longão', plannedMeters: 20_000, paces: steady(276, 20), tailMeters: 0, heartRates: [153, 165] },
  { id: 17, day: '2026-10-25', name: 'Longão', plannedMeters: null, paces: steady(274, 18), tailMeters: 0, heartRates: [152, 164] },
  { id: 18, day: '2026-11-04', name: 'Longão', plannedMeters: 20_000, paces: fading(266, 8, [279, 288, 294, 299]), tailMeters: 0, heartRates: [155, 169] },
]

export const weekSpecs: RunSpec[] = [
  { id: 21, day: '2026-11-12', name: 'Rodagem', plannedMeters: null, paces: steady(330, 10), tailMeters: 0, heartRates: [135, 142] },
  { id: 22, day: '2026-11-10', name: 'Tiros 8 x 1000', plannedMeters: null, paces: steady(240, 8), tailMeters: 0, heartRates: [150, 175] },
  { id: 23, day: '2026-11-08', name: 'Rodagem', plannedMeters: null, paces: steady(335, 12), tailMeters: 0, heartRates: [135, 143] },
]

export const outsideSpec: RunSpec = { id: 30, day: '2026-08-01', name: 'Longão', plannedMeters: 20_000, paces: steady(280, 20), tailMeters: 0, heartRates: [150, 160] }

export const readinessScores: Record<string, number> = { '2026-11-14': 55, '2026-09-05': 52, '2026-10-05': 48, '2026-11-04': 58, '2026-08-26': 75, '2026-09-15': 80, '2026-10-15': 72 }

export function healthDay(day: string, score: number): HealthDay {
  return {
    day, restingHeartRate: 50, averageStress: 30, steps: 8000,
    bodyBattery: { highest: 90, lowest: 20, atWake: 70, charged: 60, drained: 55, morningMax: 80 }, sleep: null, hrv: null,
    readiness: { score, level: null, sleepScore: null, recoveryMinutes: null, acuteLoad: null },
  }
}

export const longGoal: GoalItem = {
  id: 'G1', kind: 'continuousLong', distanceKm: 16, targetSeconds: null, deadline: null, paceSecondsPerKm: 290, archived: false, achievedAt: null,
  createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z',
}

export function scenarioInput(): DetailedInput {
  return {
    current: scenarioRun(currentSpec),
    runs: [...similarSpecs, ...weekSpecs, outsideSpec].map(scenarioRun),
    days: Object.entries(readinessScores).map(([day, score]) => healthDay(day, score)),
    goals: [longGoal],
  }
}
