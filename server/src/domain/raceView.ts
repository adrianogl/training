import type { ActivitySummary, RaceItem, StoredRace } from '../types.js'
import type { ChecklistRun, Effort, GpxPoint, Lap, RaceView, Weather, WeatherNote } from './domainTypes.js'
import { efforts as splitEfforts } from './evolution.js'
import { heatAdjustment } from './heat.js'
import { daysBetween } from './prediction.js'
import { raceBlock, raceEfforts, raceOutlook, strategyTarget } from './race.js'
import { raceChecklist } from './raceChecklist.js'
import { gpxPoints, gpxProfile, manualPaces, paceStrategy } from './raceStrategy.js'
import { isRun, weekStartOf } from './today.js'

export interface RaceContext {
  today: string
  activities: ActivitySummary[]
  laps: Map<number, Lap[]>
  weather: Map<string, { weather: Weather | null; note: WeatherNote }>
}

export function racePoints(race: RaceItem): GpxPoint[] {
  return race.gpxData ? gpxPoints(Buffer.from(race.gpxData, 'base64').toString('utf8')) : []
}

export function allEfforts(races: StoredRace[], activities: ActivitySummary[]): Effort[] {
  const results = races.flatMap(({ race }) => (race?.resultActivityId ? [{ activityId: race.resultActivityId }] : []))
  return [...splitEfforts(activities), ...raceEfforts(activities, results)]
}

export function weeklyKm(activities: ActivitySummary[]): Map<string, number> {
  const weeks = new Map<string, number>()
  for (const run of activities.filter(isRun)) {
    const start = weekStartOf(run.day)
    weeks.set(start, (weeks.get(start) ?? 0) + (run.distanceMeters ?? 0) / 1000)
  }
  return weeks
}

export function blockStartOf(race: RaceItem, today: string): string {
  return raceBlock(race.day, today, new Map())[0]?.start ?? race.day
}

const lockedView = (id: string): RaceView => ({
  id, locked: true, name: null, day: null, startTime: null, distance: null, goalSeconds: null, priority: null, city: null, hasCourse: false,
  manualPaces: [], status: 'locked', daysUntil: null, result: null, outlook: null, strategy: null, block: [], checklist: [],
})

export function buildRaceViews(races: StoredRace[], context: RaceContext): RaceView[] {
  const { today, activities } = context
  const efforts = allEfforts(races, activities)
  const weeks = weeklyKm(activities)
  const byId = new Map(activities.map((activity) => [activity.id, activity]))
  return races.map(({ id, race }) => {
    if (race === null) return lockedView(id)
    const result = race.resultActivityId ? byId.get(race.resultActivityId) : undefined
    const paces = manualPaces(race.manualPacesData)
    const points = racePoints(race)
    const base = {
      id, locked: false, name: race.name, day: race.day, startTime: race.startTime ?? null, distance: race.distance, goalSeconds: race.goalSeconds ?? null,
      priority: race.priority, city: race.city ?? null, hasCourse: points.length > 1, manualPaces: [...paces.entries()],
      result: result ? { activityId: result.id, seconds: result.durationSeconds ?? 0, distance: result.distanceMeters ?? 0, day: result.day } : null,
    }
    if (race.day < today) {
      return { ...base, status: 'done' as const, daysUntil: null, outlook: null, strategy: null, block: [], checklist: [] }
    }
    const outlook = raceOutlook(race.distance, race.day, race.goalSeconds ?? null, efforts, today)
    const target = strategyTarget(race, outlook)
    const profile = points.length > 1 ? gpxProfile(points) : null
    const forecast = context.weather.get(id) ?? { weather: null, note: 'tooFar' as const }
    const heat = target && forecast.weather ? heatAdjustment(forecast.weather, target.seconds) : null
    const goal = heat?.adjustedSeconds ?? target?.seconds ?? null
    const block = raceBlock(race.day, today, weeks)
    const blockStart = block[0]?.start ?? race.day
    const runs: ChecklistRun[] = activities
      .filter((activity) => isRun(activity) && activity.day >= blockStart)
      .map((run) => ({ day: run.day, distance: run.distanceMeters, seconds: run.movingSeconds ?? run.durationSeconds, laps: context.laps.get(run.id) ?? [] }))
    const { longProjection: _long, ...outlookView } = outlook
    return {
      ...base,
      status: 'upcoming' as const,
      daysUntil: daysBetween(today, race.day),
      outlook: outlookView,
      strategy: { target, heat, weatherNote: forecast.note, kms: goal === null ? [] : paceStrategy(goal, race.distance, profile, paces) },
      block,
      checklist: raceChecklist({
        today, blockStart, distance: race.distance, goalSeconds: race.goalSeconds ?? null, priority: race.priority, profile,
        targetPace: target === null ? null : target.seconds / (race.distance / 1000), weeklyKm: weeks, runs,
      }),
    }
  })
}
