import { describe, expect, it } from 'vitest'
import { buildToday, weekStartOf, weekVolume } from '../src/domain/today.js'
import { batterySamples, parseHealthDay } from '../src/garminParse.js'
import { addDays } from '../src/garminSync.js'
import type { ActivitySummary, HealthDay } from '../src/types.js'

const today = '2026-11-14'

function day(date: string, hrv: number, sleep: number, battery: number): HealthDay {
  return {
    day: date,
    restingHeartRate: 48,
    averageStress: 25,
    steps: 8000,
    bodyBattery: { highest: battery, lowest: 20, atWake: battery - 5, charged: 50, drained: 40, morningMax: battery },
    sleep: { seconds: 27000, score: sleep, deep: 5000, light: 15000, rem: 5000, awake: 2000, start: null, end: null },
    hrv: { lastNight: hrv, weeklyAvg: hrv, status: 'BALANCED', lowUpper: 38, balancedLow: 41, balancedUpper: 53 },
    readiness: { score: 50, level: 'MODERATE', sleepScore: sleep, recoveryMinutes: 600, acuteLoad: 900 },
  }
}

function run(date: string, km: number, load: number): ActivitySummary {
  return {
    id: Number(date.replaceAll('-', '')), name: 'Rodagem', type: 'running', startLocal: `${date}T07:00:00`, day: date,
    distanceMeters: km * 1000, durationSeconds: km * 330, movingSeconds: km * 320, elevationGain: 20, averageSpeed: 3, maxSpeed: 4,
    averageHeartRate: 140, maxHeartRate: 160, cadence: 170, trainingLoad: load, aerobicEffect: 3, anaerobicEffect: 1, vo2max: 50,
    zoneSeconds: [100, 2000, 500, 100, 0], fastestKmSeconds: 280, laps: 8, workoutId: null,
  }
}

describe('resumo do Hoje', () => {
  it('calcula a nossa prontidão com o normal de 30 dias e a carga do dia anterior', () => {
    const days = Array.from({ length: 31 }, (_, index) => {
      const date = addDays(today, -30 + index)
      return date === today ? day(date, 51.5, 54, 85) : day(date, 45.5, 64, 75)
    })
    const runs = Array.from({ length: 60 }, (_, index) => run(addDays(today, -60 + index), 8, 60))

    const summary = buildToday(days, runs, today)

    expect(summary.readiness?.score).toBeGreaterThan(0)
    expect(summary.readiness?.normal).not.toBeNull()
    expect(summary.readiness?.factors[0]?.component).toBe('hrv')
    expect(summary.raw.acuteChronic).toBeCloseTo(1, 6)
    expect(summary.garminReadiness).toBe(50)
    expect(summary.fitness?.fitness).toBeGreaterThan(0)
    expect(summary.focus?.lowAerobic).toBeCloseTo(2100 / 2700, 6)
  })

  it('sem noite de hoje, sem nota', () => {
    const summary = buildToday([], [], today)
    expect(summary.readiness).toBeNull()
    expect(summary.fitness).toBeNull()
  })

  it('volume da semana começa na segunda e guarda as últimas semanas', () => {
    const volume = weekVolume([run('2026-11-09', 8, 50), run('2026-11-12', 10, 50), run('2026-11-05', 12, 50)], today)

    expect(weekStartOf(today)).toBe('2026-11-09')
    expect(volume.total).toBe(18)
    expect(volume.perDay['2026-11-12']).toBe(10)
    expect(volume.lastWeek).toBe(12)
    expect(volume.recentWeeks).toHaveLength(12)
    expect(volume.recentWeeks.at(-1)).toEqual({ start: '2026-11-09', kilometers: 18 })
  })
})

describe('Body Battery da manhã no sync', () => {
  it('lê a série e pega o maior valor nas 3 horas depois de acordar', () => {
    const end = 1_800_000_000_000
    const raw = [{ date: today, bodyBatteryValuesArray: [[end - 60_000, 90], [end + 600_000, 70], [end + 7_200_000, 74], [end + 4 * 3_600_000, 95]] }]
    const parsed = parseHealthDay(today, {}, {}, { dailySleepDTO: { sleepTimeSeconds: 27000, sleepEndTimestampGMT: end } }, [], raw)

    expect(batterySamples(raw)).toHaveLength(4)
    expect(parsed.bodyBattery.morningMax).toBe(74)
  })
})
