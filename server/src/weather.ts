import { WEATHER } from './constants.js'
import type { Weather } from './domain/domainTypes.js'
import { daysBetween } from './domain/prediction.js'

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
