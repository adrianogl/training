import { Encoder } from '@garmin/fitsdk'
import { zipSync } from 'fflate'
import { describe, expect, it } from 'vitest'
import { FitReadError, readFit, readZip } from '../src/fit/fitReader.js'
import { douglasPeucker, simplify } from '../src/fit/routeSimplifier.js'

const MESG = { FILE_ID: 0, LAP: 19, RECORD: 20, WORKOUT: 26, WORKOUT_STEP: 27, TIME_IN_ZONE: 216 } as const
const start = new Date('2026-11-12T09:10:00.000Z')
const at = (seconds: number) => new Date(start.getTime() + seconds * 1000)
const degreesToSemicircles = (degrees: number) => Math.round((degrees / 180) * 2_147_483_648)

function sampleFit(): Uint8Array {
  const encoder = new Encoder()
  const write = (mesgNum: number, mesg: Record<string, unknown>) => encoder.onMesg(mesgNum, mesg as never)
  write(MESG.FILE_ID, { type: 'activity', manufacturer: 'development', product: 0, timeCreated: start, serialNumber: 1 })
  write(MESG.WORKOUT, { wktName: 'Intervalado 3 x 1000', sport: 'running', numValidSteps: 4 })
  write(MESG.WORKOUT_STEP, { messageIndex: 0, intensity: 'warmup', durationType: 'time', durationValue: 600_000, targetType: 'open' })
  write(MESG.WORKOUT_STEP, { messageIndex: 1, intensity: 'active', durationType: 'distance', durationValue: 100_000, targetType: 'speed', targetValue: 0, customTargetValueLow: 3_900, customTargetValueHigh: 4_100 })
  write(MESG.WORKOUT_STEP, { messageIndex: 2, intensity: 'recovery', durationType: 'time', durationValue: 120_000, targetType: 'heartRate', targetValue: 0, customTargetValueLow: 230, customTargetValueHigh: 245 })
  write(MESG.WORKOUT_STEP, { messageIndex: 3, durationType: 'repeatUntilStepsCmplt', durationValue: 1, targetType: 'open', targetValue: 3 })
  for (let second = 0; second < 30; second += 1) {
    write(MESG.RECORD, {
      timestamp: at(second),
      heartRate: 140 + (second % 5),
      enhancedSpeed: 3 + second / 100,
      enhancedAltitude: 800 + second,
      distance: second * 3,
      positionLat: degreesToSemicircles(-19.9 - second / 10_000),
      positionLong: degreesToSemicircles(-43.9),
    })
  }
  write(MESG.LAP, { timestamp: at(15), startTime: at(0), totalTimerTime: 15, totalDistance: 45, enhancedAvgSpeed: 3.07, avgHeartRate: 142, maxHeartRate: 144, intensity: 'warmup', lapTrigger: 'time', wktStepIndex: 0 })
  write(MESG.LAP, { timestamp: at(30), startTime: at(15), totalTimerTime: 15, totalDistance: 45, enhancedAvgSpeed: 3.22, avgHeartRate: 142, maxHeartRate: 144, intensity: 'active', lapTrigger: 'distance', wktStepIndex: 1 })
  write(MESG.TIME_IN_ZONE, { timestamp: at(30), referenceMesg: 'session', referenceIndex: 0, hrZoneHighBoundary: [120, 135, 147, 153, 170], hrCalcType: 'percentLthr', maxHeartRate: 185, restingHeartRate: 48, thresholdHeartRate: 165 })
  return encoder.close()
}

describe('leitura do FIT (paridade com o FITReader do app)', () => {
  it('reamostra em blocos de 5 s com média de FC, velocidade e altitude', () => {
    const summary = readFit(sampleFit())
    expect(summary.samples).toHaveLength(6)
    expect(summary.samples[0]).toMatchObject({ t: 0, heartRate: 142, speed: expect.closeTo(3.02, 6), altitude: 802, distance: 12 })
    expect(summary.samples[0]?.lat).toBeCloseTo(-19.9002, 4)
    expect(summary.samples[0]?.cadence).toBeNull()
    expect(summary.samples[5]?.t).toBe(25)
    expect(summary.route).toHaveLength(30)
    expect(summary.route[0]?.lat).toBeCloseTo(-19.9, 6)
  })

  it('lê o treino prescrito: tempo, distância, alvo de pace, de FC e repetição', () => {
    const steps = readFit(sampleFit()).structure.prescription?.steps ?? []
    expect(readFit(sampleFit()).structure.prescription?.name).toBe('Intervalado 3 x 1000')
    expect(steps.map((step) => step.intensity)).toEqual(['warmup', 'active', 'recovery', 'active'])
    expect(steps[0]?.duration).toEqual({ kind: 'time', seconds: 600 })
    expect(steps[1]?.duration).toEqual({ kind: 'distance', meters: 1000 })
    expect(steps[1]?.target).toEqual({ kind: 'speed', low: 3.9, high: 4.1 })
    expect(steps[2]?.target).toEqual({ kind: 'heartRateBpm', low: 130, high: 145 })
    expect(steps[3]?.duration).toEqual({ kind: 'repeatSteps', fromIndex: 1, count: 3 })
  })

  it('lê as voltas com o deslocamento desde o início', () => {
    const laps = readFit(sampleFit()).structure.laps
    expect(laps).toEqual([
      { stepIndex: 0, intensity: 'warmup', trigger: 'time', startOffset: 0, timerSeconds: 15, distance: 45, avgSpeed: expect.closeTo(3.07, 3), avgHeartRate: 142, maxHeartRate: 144 },
      { stepIndex: 1, intensity: 'active', trigger: 'distance', startOffset: 15, timerSeconds: 15, distance: 45, avgSpeed: expect.closeTo(3.22, 3), avgHeartRate: 142, maxHeartRate: 144 },
    ])
  })

  it('lê as zonas da sessão', () => {
    expect(readFit(sampleFit()).zoneInfo).toEqual({ thresholdHeartRate: 165, maxHeartRate: 185, restingHeartRate: 48, calcType: 3, floors: [120, 135, 147, 153, 170] })
  })

  it('abre o zip da Garmin e recusa arquivo inválido', () => {
    const zip = zipSync({ '25037588001_ACTIVITY.fit': sampleFit() })
    expect(readZip(zip).samples).toHaveLength(6)
    expect(() => readZip(new Uint8Array([1, 2, 3]))).toThrow(FitReadError)
    expect(() => readZip(zipSync({ 'leia.txt': new Uint8Array([1]) }))).toThrow('no_fit_entry')
    expect(() => readFit(new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]))).toThrow('decode_failed')
  })

  it('simplifica a rota até o limite de pontos', () => {
    const line = Array.from({ length: 50 }, (_, i) => ({ lat: i, lon: i % 2 === 0 ? 0 : 0.5 }))
    expect(simplify(line, 10).length).toBeLessThanOrEqual(10)
    expect(douglasPeucker([{ lat: 0, lon: 0 }, { lat: 1, lon: 0 }, { lat: 2, lon: 0 }], 0.1)).toEqual([{ lat: 0, lon: 0 }, { lat: 2, lon: 0 }])
  })
})
