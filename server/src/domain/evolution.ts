import { addDays } from '../garminSync.js'
import type { ActivitySummary, HealthDay } from '../types.js'
import { EVOLUTION, PREDICTION } from './domainConstants.js'
import type { Effort, Evolution, MetricSeries, MetricStats, Records, SeriesPoint, WeekTotals } from './domainTypes.js'
import { fitnessFatigueForm, loadFocus } from './load.js'
import { predict, predictionSeries, smoothedVo2max } from './prediction.js'
import { dailyLoad, isRun, weekStartOf } from './today.js'

function mean(values: number[]): number | null {
  return values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length
}

export function movingAverage(points: SeriesPoint[], days: number): SeriesPoint[] {
  const result: SeriesPoint[] = []
  let start = 0
  let sum = 0
  points.forEach(([day, value], index) => {
    sum += value
    const first = addDays(day, 1 - days)
    while ((points[start]?.[0] ?? day) < first) {
      sum -= points[start]?.[1] ?? 0
      start += 1
    }
    result.push([day, sum / (index - start + 1)])
  })
  return result
}

export function metricStats(points: SeriesPoint[]): MetricStats {
  const values = points.map(([, value]) => value)
  const first = values[0]
  const last = values.at(-1)
  return {
    current: last ?? null,
    average: mean(values),
    minimum: values.length === 0 ? null : Math.min(...values),
    maximum: values.length === 0 ? null : Math.max(...values),
    change: values.length >= 2 && first !== undefined && last !== undefined ? last - first : null,
  }
}

function dailyMeans(values: SeriesPoint[]): SeriesPoint[] {
  const groups = new Map<string, number[]>()
  for (const [day, value] of values) {
    groups.set(day, [...(groups.get(day) ?? []), value])
  }
  return [...groups.entries()].sort(([a], [b]) => (a < b ? -1 : 1)).map(([day, list]) => [day, mean(list) ?? 0])
}

function rolling(keys: string[], from: string, today: string, window: number, value: (days: string[]) => number | null): SeriesPoint[] {
  const earliest = [...keys].sort()[0]
  if (earliest === undefined) {
    return []
  }
  const result: SeriesPoint[] = []
  for (let day = earliest > from ? earliest : from; day <= today; day = addDays(day, 1)) {
    const days = Array.from({ length: window }, (_, index) => addDays(day, -index))
    const current = value(days)
    if (current !== null) {
      result.push([day, current])
    }
  }
  return result
}

export function efforts(activities: ActivitySummary[]): Effort[] {
  return activities.filter(isRun).flatMap((run) => {
    const list: Effort[] = []
    if ((run.fastest5kSeconds ?? 0) > 0) {
      list.push({ distance: 5000, seconds: run.fastest5kSeconds ?? 0, day: run.day, kind: 'split5k' })
    }
    if ((run.fastestKmSeconds ?? 0) > 0) {
      list.push({ distance: 1000, seconds: run.fastestKmSeconds ?? 0, day: run.day, kind: 'split1k' })
    }
    return list
  })
}

function series(key: string, all: SeriesPoint[], from: string, band: [number, number] | null = null): MetricSeries {
  const points = all.filter(([day]) => day >= from)
  const average = movingAverage(all, EVOLUTION.movingAverageDays).filter(([day]) => day >= from)
  return { key, points, movingAverage: average, stats: metricStats(points), band: points.length === 0 ? null : band }
}

function records(activities: ActivitySummary[]): Records {
  const runs = activities.filter(isRun)
  const minBy = (pick: (run: ActivitySummary) => number | null | undefined) =>
    runs.reduce<ActivitySummary | undefined>((best, run) => {
      const value = pick(run)
      if (value === null || value === undefined || value <= 0) return best
      const current = best === undefined ? null : pick(best)
      return current === null || current === undefined || value < current ? run : best
    }, undefined)
  const fastestKm = minBy((run) => run.fastestKmSeconds)
  const fastest5k = minBy((run) => run.fastest5kSeconds)
  const longest = runs.reduce<ActivitySummary | undefined>((best, run) => ((run.distanceMeters ?? 0) > (best?.distanceMeters ?? 0) ? run : best), undefined)
  const weeks = new Map<string, number>()
  for (const run of runs) {
    const start = weekStartOf(run.day)
    weeks.set(start, (weeks.get(start) ?? 0) + (run.distanceMeters ?? 0) / 1000)
  }
  const biggest = [...weeks.entries()].sort(([, a], [, b]) => b - a)[0]
  return {
    fastestKm: fastestKm ? { seconds: fastestKm.fastestKmSeconds ?? 0, day: fastestKm.day, name: fastestKm.name } : null,
    fastest5k: fastest5k ? { seconds: fastest5k.fastest5kSeconds ?? 0, day: fastest5k.day, name: fastest5k.name } : null,
    longestRun: longest ? { meters: longest.distanceMeters ?? 0, day: longest.day, name: longest.name } : null,
    biggestWeek: biggest ? { kilometers: biggest[1], start: biggest[0] } : null,
  }
}

export function weekTotals(activities: ActivitySummary[], from: string, today: string): WeekTotals[] {
  const weeks: WeekTotals[] = []
  for (let start = weekStartOf(from); start <= today; start = addDays(start, 7)) {
    weeks.push({ start, kilometers: 0, zoneSeconds: [0, 0, 0, 0, 0] })
  }
  for (const run of activities.filter(isRun)) {
    const week = weeks.find((item) => item.start === weekStartOf(run.day))
    if (week === undefined || run.day > today) continue
    week.kilometers += (run.distanceMeters ?? 0) / 1000
    if (run.zoneSeconds.length === 5) {
      week.zoneSeconds = week.zoneSeconds.map((value, index) => value + (run.zoneSeconds[index] ?? 0))
    }
  }
  return weeks
}

export function buildEvolution(days: HealthDay[], activities: ActivitySummary[], today: string, periodDays: number): Evolution {
  const from = addDays(today, 1 - periodDays)
  const runs = activities.filter(isRun)
  const daily = (pick: (day: HealthDay) => number | null | undefined): SeriesPoint[] =>
    days.flatMap((day) => {
      const value = pick(day)
      return value === null || value === undefined ? [] : [[day.day, value] as SeriesPoint]
    })
  const vo2 = new Map(smoothedVo2max(runs.flatMap((run) => (run.vo2max === null ? [] : [[run.day, run.vo2max] as SeriesPoint])), EVOLUTION.vo2SmoothingDays))
  const load = dailyLoad(activities)
  const firstLoad = [...load.keys()].sort()[0]
  const form = firstLoad === undefined ? [] : fitnessFatigueForm(load, firstLoad, today)
  const fitness: SeriesPoint[] = form.map((point) => [point.day, point.fitness])
  const fatigue: SeriesPoint[] = form.map((point) => [point.day, point.fatigue])
  const km = new Map<string, number>()
  for (const run of runs) {
    km.set(run.day, (km.get(run.day) ?? 0) + (run.distanceMeters ?? 0) / 1000)
  }
  const focusItems = new Map<string, { load: number; zoneSeconds: number[] }[]>()
  const zoneSeconds = new Map<string, number[]>()
  for (const activity of activities) {
    if (activity.trainingLoad !== null && activity.zoneSeconds.length === 5) {
      focusItems.set(activity.day, [...(focusItems.get(activity.day) ?? []), { load: activity.trainingLoad, zoneSeconds: activity.zoneSeconds }])
    }
    if (isRun(activity) && activity.zoneSeconds.length === 5) {
      const current = zoneSeconds.get(activity.day) ?? [0, 0, 0, 0, 0]
      zoneSeconds.set(activity.day, current.map((value, index) => value + (activity.zoneSeconds[index] ?? 0)))
    }
  }
  const latestBand = [...days].reverse().find((day) => day.hrv?.balancedLow != null && day.hrv?.balancedUpper != null)?.hrv
  const allEfforts = efforts(activities)
  const predictionFrom = addDays(from, -1)
  const predictionList = PREDICTION.distances.map((distance) => {
    const current = predict(distance.meters, allEfforts, today)
    const before = predict(distance.meters, allEfforts, predictionFrom)
    return { key: distance.key, label: distance.label, seconds: current, change: current !== null && before !== null ? current - before : null }
  })
  return {
    day: today,
    periodDays,
    series: [
      series('vo2max', [...vo2.entries()], from),
      series('fitness', fitness, from),
      series('fatigue', fatigue, from),
      series('monthlyVolume', rolling([...km.keys()], from, today, EVOLUTION.volumeWindowDays, (window) => window.reduce((sum, day) => sum + (km.get(day) ?? 0), 0)), from),
      series('hrv', daily((day) => day.hrv?.lastNight), from, latestBand ? [latestBand.balancedLow ?? 0, latestBand.balancedUpper ?? 0] : null),
      series('restingHeartRate', daily((day) => day.restingHeartRate), from),
      series('sleep', daily((day) => day.sleep?.score), from),
      series('bodyBattery', daily((day) => day.bodyBattery.morningMax), from),
      series('loadFocus', rolling([...focusItems.keys()], from, today, EVOLUTION.focusWindowDays, (window) => {
        const focus = loadFocus(window.flatMap((day) => focusItems.get(day) ?? []))
        return focus === null ? null : focus.lowAerobic * 100
      }), from),
      series('zoneDistribution', rolling([...zoneSeconds.keys()], from, today, EVOLUTION.focusWindowDays, (window) => {
        const zones = window.flatMap((day) => (zoneSeconds.has(day) ? [zoneSeconds.get(day) ?? []] : []))
        const total = zones.reduce((sum, list) => sum + list.reduce((a, b) => a + b, 0), 0)
        return total > 0 ? (zones.reduce((sum, list) => sum + list.slice(0, EVOLUTION.lowZoneCount).reduce((a, b) => a + b, 0), 0) / total) * 100 : null
      }), from),
      series('cadence', dailyMeans(runs.flatMap((run) => (run.cadence === null ? [] : [[run.day, run.cadence] as SeriesPoint]))), from),
      ...PREDICTION.distances.map((distance) => series(distance.key, predictionSeries(distance.meters, allEfforts, from, today), from)),
    ],
    weeks: weekTotals(activities, from, today),
    predictions: predictionList,
    records: records(activities),
  }
}
