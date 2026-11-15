import { randomUUID } from 'node:crypto'
import { RACES } from './constants.js'
import type { Sql } from './db.js'
import { addDays as shift } from './garminSync.js'
import type { Weather, WeatherNote } from './domain/domainTypes.js'
import { readStructuredRuns, readTrainingEfforts } from './trainingEffortStore.js'
import { blockStartOf, buildRaceViews, racePoints } from './domain/raceView.js'
import { isRun } from './domain/today.js'
import { fetchMissingLaps, readLaps } from './garminLaps.js'
import { body, failure, garminEnvFromProcess, json, withAccount } from './garminRoutes.js'
import { localDay, readActivitiesSince } from './garminSync.js'
import { limitsFromEnv } from './limits.js'
import { applyRaceEdit, parseRaceEdit } from './raceInput.js'
import { deleteRace, nextUpdatedAt, readRaces, writeRace } from './races.js'
import type { GarminEnv, RaceItem, StoredRace } from './types.js'
import { forecastAvailable, geocode, raceWeather, startHour } from './weather.js'

async function forecasts(env: GarminEnv, races: StoredRace[], today: string): Promise<Map<string, { weather: Weather | null; note: WeatherNote }>> {
  const result = new Map<string, { weather: Weather | null; note: WeatherNote }>()
  for (const { id, race } of races) {
    if (race === null || race.day < today) continue
    if (!forecastAvailable(race.day, today)) {
      result.set(id, { weather: null, note: 'tooFar' })
      continue
    }
    const first = racePoints(race)[0]
    const coordinate = first ? { latitude: first.latitude, longitude: first.longitude } : race.city ? await geocode(env.fetcher, race.city) : null
    if (coordinate === null) {
      result.set(id, { weather: null, note: 'noLocation' })
      continue
    }
    const weather = await raceWeather(env.fetcher, coordinate, race.day, startHour(race.startTime))
    result.set(id, { weather, note: weather === null ? 'unavailable' : null })
  }
  return result
}

export function racesRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'races', async (accountId, key) => {
    const today = localDay(env.now())
    const races = await readRaces(sql, key, accountId)
    const activities = await readActivitiesSince(sql, key, accountId, shift(today, -RACES.activityHistoryDays))
    const starts = races.flatMap(({ race }) => (race !== null && race.day >= today ? [blockStartOf(race, today)] : []))
    const earliest = starts.sort()[0]
    const ids = earliest === undefined ? [] : activities.filter((run) => isRun(run) && run.day >= earliest).map((run) => run.id)
    const keyed = { ...env, dataKey: key }
    const laps = await fetchMissingLaps(sql, keyed, accountId, ids).catch(() => readLaps(sql, key, accountId, ids))
    const views = buildRaceViews(races, { today, activities, laps, weather: await forecasts(env, races, today), trainingEfforts: await readTrainingEfforts(sql, key, accountId, activities, races, today), structuredRuns: await readStructuredRuns(sql, key, accountId, activities, races, ids) })
    const order = (day: string | null) => day ?? ''
    const upcoming = views.filter((view) => view.status === 'upcoming').sort((a, b) => order(a.day).localeCompare(order(b.day)))
    const done = views.filter((view) => view.status === 'done').sort((a, b) => order(b.day).localeCompare(order(a.day)))
    const locked = views.filter((view) => view.status === 'locked')
    return json(200, { today, races: [...upcoming, ...done, ...locked] })
  })
}

export function saveRaceRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess(), maxAccountBytes = limitsFromEnv(process.env).maxAccountBytes): Promise<Response> {
  return withAccount(request, sql, env, 'races', async (accountId, key) => {
    const requested = new URL(request.url).searchParams.get('id')
    const edit = parseRaceEdit(await body(request))
    if (typeof edit === 'string') return failure(400, edit)
    let current: RaceItem | null = null
    let id = randomUUID().toUpperCase()
    if (requested !== null) {
      const stored = (await readRaces(sql, key, accountId)).find((item) => item.id.toLowerCase() === requested.toLowerCase())
      if (stored === undefined) return failure(404, 'race_not_found')
      if (stored.race === null) return failure(409, 'race_locked')
      current = stored.race
      id = stored.id
    }
    const race = applyRaceEdit(current, id, edit, await nextUpdatedAt(sql, accountId, id, env.now()))
    if (!(await writeRace(sql, key, accountId, race, maxAccountBytes))) return failure(413, 'quota_exceeded')
    return json(requested === null ? 201 : 200, { id })
  })
}

export function deleteRaceRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'races', async (accountId, key) => {
    const requested = new URL(request.url).searchParams.get('id') ?? ''
    const stored = (await readRaces(sql, key, accountId)).find((item) => item.id.toLowerCase() === requested.toLowerCase())
    if (stored === undefined) return failure(404, 'race_not_found')
    await deleteRace(sql, accountId, stored.id, await nextUpdatedAt(sql, accountId, stored.id, env.now()))
    return new Response(null, { status: 204 })
  })
}
