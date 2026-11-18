import { WEATHER } from './constants.js'
import type { Weather } from './domain/domainTypes.js'
import { daysBetween } from './domain/prediction.js'
import { addDays } from './garminSync.js'
import type { RunWeather } from './analysis/analysisTypes.js'

export interface Coordinate {
  latitude: number
  longitude: number
}

type Fetcher = (input: string, init?: RequestInit) => Promise<Response>

const rounded = (value: number) => (Math.round(value * WEATHER.coordinateScale) / WEATHER.coordinateScale).toFixed(1)

async function getJson(fetcher: Fetcher, url: string): Promise<unknown> {
  try {
    const response = await fetcher(url, { signal: AbortSignal.timeout(WEATHER.timeoutMs) })
    return response.ok ? await response.json() : null
  } catch {
    return null
  }
}

export async function geocode(fetcher: Fetcher, city: string): Promise<Coordinate | null> {
  const params = new URLSearchParams({ name: city, count: '1', language: 'pt', format: 'json' })
  const body = (await getJson(fetcher, `${WEATHER.geocodingUrl}?${params}`)) as { results?: { latitude?: number; longitude?: number }[] } | null
  const first = body?.results?.[0]
  return typeof first?.latitude === 'number' && typeof first.longitude === 'number' ? { latitude: first.latitude, longitude: first.longitude } : null
}

export function startHour(startTime: string | null | undefined): number {
  const hour = Number(startTime?.slice(0, 2))
  return Number.isInteger(hour) && hour >= 0 && hour < 24 ? hour : WEATHER.defaultStartHour
}

export function forecastAvailable(day: string, today: string): boolean {
  const ahead = daysBetween(today, day)
  return ahead >= 0 && ahead < WEATHER.forecastDaysAhead
}

export function pickHour(body: unknown, hour: number): Weather | null {
  const hourly = (body as { hourly?: { time?: string[]; temperature_2m?: (number | null)[]; dew_point_2m?: (number | null)[] } } | null)?.hourly
  const index = hourly?.time?.findIndex((time) => Number(time.slice(11, 13)) === hour) ?? -1
  const temperature = hourly?.temperature_2m?.[index]
  const dewPoint = hourly?.dew_point_2m?.[index]
  return index >= 0 && typeof temperature === 'number' && typeof dewPoint === 'number' ? { hour, temperature, dewPoint } : null
}

export async function raceWeather(fetcher: Fetcher, coordinate: Coordinate, day: string, hour: number): Promise<Weather | null> {
  const params = new URLSearchParams({
    latitude: rounded(coordinate.latitude),
    longitude: rounded(coordinate.longitude),
    hourly: WEATHER.fields,
    timezone: 'auto',
    start_date: day,
    end_date: day,
  })
  return pickHour(await getJson(fetcher, `${WEATHER.forecastUrl}?${params}`), hour)
}

interface HourlyBody {
  hourly?: {
    time?: string[]
    temperature_2m?: (number | null)[]
    dew_point_2m?: (number | null)[]
    wind_speed_10m?: (number | null)[]
    wind_direction_10m?: (number | null)[]
    shortwave_radiation?: (number | null)[]
  }
}

const minutesOf = (local: string) => Date.parse(`${local.slice(0, 16)}:00Z`) / 60_000

export function averageWeather(body: unknown, startLocal: string, durationSeconds: number): RunWeather | null {
  const hourly = (body as HourlyBody | null)?.hourly
  const start = minutesOf(startLocal)
  const end = start + Math.max(durationSeconds / 60, 1)
  const sums = { weight: 0, temperature: 0, dewWeight: 0, dew: 0, windWeight: 0, wind: 0, east: 0, north: 0, sunWeight: 0, sun: 0 }
  hourly?.time?.forEach((time, index) => {
    const hourStart = minutesOf(time)
    const overlap = Math.min(end, hourStart + 60) - Math.max(start, hourStart)
    const value = hourly.temperature_2m?.[index]
    if (overlap <= 0 || typeof value !== 'number') return
    sums.weight += overlap
    sums.temperature += value * overlap
    const dew = hourly.dew_point_2m?.[index]
    if (typeof dew === 'number') {
      sums.dewWeight += overlap
      sums.dew += dew * overlap
    }
    const speed = hourly.wind_speed_10m?.[index]
    const from = hourly.wind_direction_10m?.[index]
    if (typeof speed === 'number' && typeof from === 'number') {
      sums.windWeight += overlap
      sums.wind += speed * overlap
      sums.east += speed * Math.sin((from * Math.PI) / 180) * overlap
      sums.north += speed * Math.cos((from * Math.PI) / 180) * overlap
    }
    const sun = hourly.shortwave_radiation?.[index]
    if (typeof sun === 'number') {
      sums.sunWeight += overlap
      sums.sun += sun * overlap
    }
  })
  if (sums.weight <= 0) return null
  return {
    temperature: sums.temperature / sums.weight,
    dewPoint: sums.dewWeight > 0 ? sums.dew / sums.dewWeight : null,
    windSpeed: sums.windWeight > 0 ? sums.wind / sums.windWeight : null,
    windFrom: sums.windWeight > 0 ? ((Math.atan2(sums.east, sums.north) * 180) / Math.PI + 360) % 360 : null,
    radiation: sums.sunWeight > 0 ? sums.sun / sums.sunWeight : null,
  }
}

export interface RunWindow {
  startLocal: string
  seconds: number
}

export async function activityWeather(
  fetcher: Fetcher, coordinate: Coordinate, run: RunWindow, earlier: RunWindow[], today: string, isHot: (weather: RunWeather | null) => boolean,
): Promise<{ weather: RunWeather | null; hotSessions: number }> {
  const day = run.startLocal.slice(0, 10)
  const first = addDays(day, -WEATHER.adaptationDays)
  const archive = daysBetween(first, today) > WEATHER.forecastHistoryDays
  const params = new URLSearchParams({
    latitude: rounded(coordinate.latitude),
    longitude: rounded(coordinate.longitude),
    hourly: WEATHER.activityFields,
    wind_speed_unit: WEATHER.windUnit,
    timezone: 'auto',
    start_date: first,
    end_date: day,
  })
  const body = await getJson(fetcher, `${archive ? WEATHER.archiveUrl : WEATHER.forecastUrl}?${params}`)
  const hotSessions = earlier.filter((item) => item.startLocal >= first && item.startLocal < run.startLocal && isHot(averageWeather(body, item.startLocal, item.seconds))).length
  return { weather: averageWeather(body, run.startLocal, run.seconds), hotSessions }
}
