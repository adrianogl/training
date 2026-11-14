import { RACE } from './domainConstants.js'
import type { GpxPoint, KmPlan, ProfilePoint } from './domainTypes.js'

export function minettiCost(grade: number): number {
  return 155.4 * grade ** 5 - 30.4 * grade ** 4 - 43.3 * grade ** 3 + 46.3 * grade ** 2 + 19.5 * grade + 3.6
}

export function kmLength(index: number, kms: number, distance: number): number {
  return index < kms - 1 ? 1000 : distance - (kms - 1) * 1000
}

function kmLabel(index: number, kms: number, grade: number): string {
  if (index >= kms - RACE.finishKms) return RACE.labels.finish
  if (index < RACE.warmupKms) return RACE.labels.warmup
  if (grade > RACE.climbLabelGrade) return RACE.labels.climb
  if (grade < -RACE.climbLabelGrade) return RACE.labels.descent
  return RACE.labels.flat
}

function altitudeAt(distance: number, points: ProfilePoint[]): number {
  const first = points[0]
  const last = points.at(-1)
  if (first === undefined || last === undefined) return 0
  if (distance <= first.distance) return first.altitude
  if (distance >= last.distance) return last.altitude
  const upper = points.findIndex((point) => point.distance >= distance)
  const a = points[upper - 1] ?? first
  const b = points[upper] ?? last
  if (b.distance <= a.distance) return b.altitude
  return a.altitude + ((b.altitude - a.altitude) * (distance - a.distance)) / (b.distance - a.distance)
}

export function paceStrategy(goalSeconds: number, distance: number, profile: ProfilePoint[] | null, manual: Map<number, number>): KmPlan[] {
  const kms = Math.ceil(distance / 1000)
  if (kms <= 0) return []
  const points = [...(profile ?? [])].sort((a, b) => a.distance - b.distance)
  const base = goalSeconds / (distance / 1000)
  const flatCost = minettiCost(0)
  const [minGrade, maxGrade] = RACE.minettiGradeRange
  const plan: KmPlan[] = Array.from({ length: kms }, (_, index) => {
    const start = index * 1000
    const length = kmLength(index, kms, distance)
    const grade = points.length === 0 ? 0 : (altitudeAt(start + length, points) - altitudeAt(start, points)) / length
    const label = kmLabel(index, kms, grade)
    const fixed = manual.get(index)
    if (fixed !== undefined) return { index, pace: fixed, grade, label, manual: true }
    let pace = (base * minettiCost(Math.min(Math.max(grade, minGrade), maxGrade))) / flatCost
    if (index < RACE.warmupKms) pace += RACE.warmupOffset
    if (index >= kms - RACE.finishKms) pace += RACE.finishOffset
    return { index, pace, grade, label, manual: false }
  })
  if (!plan.every((item) => !item.manual || item.pace > 0)) return []
  const freeKm = plan.filter((item) => !item.manual).reduce((sum, item) => sum + kmLength(item.index, kms, distance) / 1000, 0)
  if (freeKm <= 0) return plan
  const planned = plan.reduce((sum, item) => sum + (item.pace * kmLength(item.index, kms, distance)) / 1000, 0)
  const shift = (goalSeconds - planned) / freeKm
  const shifted = plan.map((item) => (item.manual ? item : { ...item, pace: item.pace + shift }))
  return shifted.every((item) => item.pace > 0) ? shifted : []
}

export function gpxPoints(xml: string): GpxPoint[] {
  const points: GpxPoint[] = []
  for (const match of xml.matchAll(/<(trkpt|rtept)\b([^>]*?)(?:\/>|>([\s\S]*?)<\/\1>)/g)) {
    const attributes = match[2] ?? ''
    const latitude = Number(/\blat\s*=\s*["']([^"']+)["']/.exec(attributes)?.[1])
    const longitude = Number(/\blon\s*=\s*["']([^"']+)["']/.exec(attributes)?.[1])
    const elevation = /<ele>([^<]*)<\/ele>/.exec(match[3] ?? '')?.[1]
    const altitude = elevation === undefined ? Number.NaN : Number(elevation.trim())
    if (Number.isFinite(latitude) && Number.isFinite(longitude) && Number.isFinite(altitude)) {
      points.push({ latitude, longitude, altitude })
    }
  }
  return points
}

function haversine(a: GpxPoint, b: GpxPoint): number {
  const toRadians = Math.PI / 180
  const deltaLatitude = (b.latitude - a.latitude) * toRadians
  const deltaLongitude = (b.longitude - a.longitude) * toRadians
  const h = Math.sin(deltaLatitude / 2) ** 2 + Math.cos(a.latitude * toRadians) * Math.cos(b.latitude * toRadians) * Math.sin(deltaLongitude / 2) ** 2
  return 2 * RACE.earthRadiusMeters * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function gpxProfile(points: GpxPoint[]): ProfilePoint[] {
  let distance = 0
  return points.map((point, index) => {
    const previous = points[index - 1]
    if (previous !== undefined) distance += haversine(previous, point)
    return { distance, altitude: point.altitude }
  })
}

export function manualPaces(base64: string | null | undefined): Map<number, number> {
  if (base64 === null || base64 === undefined) return new Map()
  try {
    const value: unknown = JSON.parse(Buffer.from(base64, 'base64').toString('utf8'))
    if (Array.isArray(value)) {
      const pairs = new Map<number, number>()
      for (let index = 0; index + 1 < value.length; index += 2) {
        const key = value[index]
        const pace = value[index + 1]
        if (typeof key === 'number' && typeof pace === 'number') pairs.set(key, pace)
      }
      return pairs
    }
    if (typeof value === 'object' && value !== null) {
      return new Map(Object.entries(value).flatMap(([key, pace]) => (typeof pace === 'number' ? [[Number(key), pace] as [number, number]] : [])))
    }
  } catch {
    return new Map()
  }
  return new Map()
}

export function encodeManualPaces(paces: Map<number, number>): string | null {
  if (paces.size === 0) return null
  return Buffer.from(JSON.stringify([...paces.entries()].flat())).toString('base64')
}
