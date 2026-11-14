import { bodyBatteryMorningMax } from './domain/readiness.js'
import type { ActivitySummary, HealthDay } from './types.js'

type Json = Record<string, unknown>

function obj(value: unknown): Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : {}
}

function num(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value !== '' ? value : null
}

function isoFromMillis(value: unknown): string | null {
  const millis = num(value)
  return millis === null ? null : new Date(millis).toISOString()
}

function levelIndex(entry: Json): number {
  const descriptors = entry.bodyBatteryValueDescriptorsDTOList ?? entry.bodyBatteryValueDescriptorDTOList
  if (!Array.isArray(descriptors)) {
    return 1
  }
  const level = descriptors.map(obj).find((descriptor) => descriptor.bodyBatteryValueDescriptorKey === 'bodyBatteryLevel')
  return num(level?.bodyBatteryValueDescriptorIndex) ?? 1
}

export function batterySamples(raw: unknown): [number, number][] {
  const entries = Array.isArray(raw) ? raw.map(obj) : [obj(raw)]
  return entries.flatMap((entry) => {
    const values = Array.isArray(entry.bodyBatteryValuesArray) ? entry.bodyBatteryValuesArray : []
    const index = levelIndex(entry)
    return values.flatMap((point) => {
      if (!Array.isArray(point)) {
        return []
      }
      const time = num(point[0])
      const value = num(point[index])
      return time === null || value === null ? [] : [[time, Math.round(value)] as [number, number]]
    })
  })
}

export function parseHealthDay(day: string, summaryRaw: unknown, hrvRaw: unknown, sleepRaw: unknown, readinessRaw: unknown, batteryRaw: unknown = null): HealthDay {
  const summary = obj(summaryRaw)
  const hrvSummary = obj(obj(hrvRaw).hrvSummary)
  const baseline = obj(hrvSummary.baseline)
  const sleep = obj(obj(sleepRaw).dailySleepDTO)
  const scores = obj(sleep.sleepScores)
  const readinessList = Array.isArray(readinessRaw) ? readinessRaw.map(obj) : [obj(readinessRaw)]
  const readiness = readinessList
    .filter((entry) => entry.calendarDate === day && num(entry.score) !== null)
    .sort((a, b) => String(b.timestamp ?? '').localeCompare(String(a.timestamp ?? '')))[0]
  const sleepSeconds = num(sleep.sleepTimeSeconds)
  const sleepEnd = num(sleep.sleepEndTimestampGMT)
  return {
    day,
    restingHeartRate: num(summary.restingHeartRate),
    averageStress: num(summary.averageStressLevel),
    steps: num(summary.totalSteps),
    bodyBattery: {
      highest: num(summary.bodyBatteryHighestValue),
      lowest: num(summary.bodyBatteryLowestValue),
      atWake: num(summary.bodyBatteryAtWakeTime),
      charged: num(summary.bodyBatteryChargedValue),
      drained: num(summary.bodyBatteryDrainedValue),
      morningMax: sleepEnd === null ? null : bodyBatteryMorningMax(batterySamples(batteryRaw), sleepEnd),
    },
    sleep:
      sleepSeconds === null || sleepSeconds === 0
        ? null
        : {
            seconds: sleepSeconds,
            score: num(obj(scores.overall).value),
            deep: num(sleep.deepSleepSeconds) ?? 0,
            light: num(sleep.lightSleepSeconds) ?? 0,
            rem: num(sleep.remSleepSeconds) ?? 0,
            awake: num(sleep.awakeSleepSeconds) ?? 0,
            start: isoFromMillis(sleep.sleepStartTimestampGMT),
            end: isoFromMillis(sleep.sleepEndTimestampGMT),
          },
    hrv:
      Object.keys(hrvSummary).length === 0
        ? null
        : {
            lastNight: num(hrvSummary.lastNightAvg),
            weeklyAvg: num(hrvSummary.weeklyAvg),
            status: str(hrvSummary.status),
            lowUpper: num(baseline.lowUpper),
            balancedLow: num(baseline.balancedLow),
            balancedUpper: num(baseline.balancedUpper),
          },
    readiness:
      readiness === undefined
        ? null
        : {
            score: num(readiness.score) ?? 0,
            level: str(readiness.level),
            sleepScore: num(readiness.sleepScore),
            recoveryMinutes: num(readiness.recoveryTime),
            acuteLoad: num(readiness.acuteLoad),
          },
  }
}

export function parseActivity(raw: unknown): ActivitySummary | undefined {
  const item = obj(raw)
  const id = num(item.activityId)
  const startLocal = str(item.startTimeLocal)
  if (id === null || startLocal === null) {
    return undefined
  }
  return {
    id,
    name: str(item.activityName) ?? '',
    type: str(obj(item.activityType).typeKey) ?? 'other',
    startLocal: startLocal.replace(' ', 'T'),
    day: startLocal.slice(0, 10),
    distanceMeters: num(item.distance),
    durationSeconds: num(item.duration),
    movingSeconds: num(item.movingDuration),
    elevationGain: num(item.elevationGain),
    averageSpeed: num(item.averageSpeed),
    maxSpeed: num(item.maxSpeed),
    averageHeartRate: num(item.averageHR),
    maxHeartRate: num(item.maxHR),
    cadence: num(item.averageRunningCadenceInStepsPerMinute),
    trainingLoad: num(item.activityTrainingLoad),
    aerobicEffect: num(item.aerobicTrainingEffect),
    anaerobicEffect: num(item.anaerobicTrainingEffect),
    vo2max: num(item.vO2MaxValue),
    zoneSeconds: [1, 2, 3, 4, 5].map((zone) => num(item[`hrTimeInZone_${zone}`]) ?? 0),
    fastestKmSeconds: num(item.fastestSplit_1000),
    fastest5kSeconds: num(item.fastestSplit_5000),
    laps: num(item.lapCount),
    workoutId: num(item.workoutId),
  }
}
