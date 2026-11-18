import type { FitSample } from '../fit/fitTypes.js'
import { ANALYSIS, ANALYSIS_WEATHER as W } from './analysisConstants.js'
import type { BlockKilometers, DayCondition, Finding, RunWeather, WeatherEffect, WorkoutBlock } from './analysisTypes.js'
import { headwindOf, windCost } from './weatherEffect.js'

const radians = (degrees: number) => (degrees * Math.PI) / 180
const mean = (values: number[]) => (values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length)

function bearing(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const y = Math.sin(radians(lon2 - lon1)) * Math.cos(radians(lat2))
  const x = Math.cos(radians(lat1)) * Math.sin(radians(lat2)) - Math.sin(radians(lat1)) * Math.cos(radians(lat2)) * Math.cos(radians(lon2 - lon1))
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360
}

function meters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const a = Math.sin(radians(lat2 - lat1) / 2) ** 2 + Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(radians(lon2 - lon1) / 2) ** 2
  return 2 * 6_371_000 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function sampleHeadwinds(samples: FitSample[], windSpeed: number, windFrom: number): { t: number; headwind: number }[] {
  const located = samples.filter((sample) => typeof sample.lat === 'number' && typeof sample.lon === 'number').sort((a, b) => a.t - b.t)
  const result: { t: number; headwind: number }[] = []
  let anchor = located[0]
  for (const sample of located.slice(1)) {
    if (anchor === undefined) break
    const [lat1, lon1, lat2, lon2] = [anchor.lat ?? 0, anchor.lon ?? 0, sample.lat ?? 0, sample.lon ?? 0]
    if (meters(lat1, lon1, lat2, lon2) < W.minimumHeadingMeters) continue
    result.push({ t: sample.t, headwind: headwindOf(windSpeed, windFrom, bearing(lat1, lon1, lat2, lon2)) })
    anchor = sample
  }
  return result
}

export function applyWind(blocks: WorkoutBlock[], samples: FitSample[], weather: RunWeather | null): WorkoutBlock[] {
  const speed = weather?.windSpeed
  const from = weather?.windFrom
  if (typeof speed !== 'number' || typeof from !== 'number' || speed <= 0) return blocks
  const headwinds = sampleHeadwinds(samples, speed, from)
  if (headwinds.length === 0) return blocks
  return blocks.map((block, position) => {
    const start = block.laps[0]?.startOffset
    if (start === undefined) return block
    const next = blocks.slice(position + 1).find((item) => item.laps[0] !== undefined)?.laps[0]?.startOffset
    const last = block.laps.at(-1)
    const end = next ?? (last === undefined ? start : last.startOffset + last.timerSeconds)
    const inside = headwinds.filter((item) => item.t >= start && item.t < end)
    if (inside.length === 0) return block
    return {
      ...block,
      headwind: inside.reduce((sum, item) => sum + item.headwind, 0) / inside.length,
      windFactor: inside.reduce((sum, item) => sum + windCost(item.headwind), 0) / inside.length,
    }
  })
}

export function applyWindKilometers(kilometers: BlockKilometers, samples: FitSample[], weather: RunWeather | null): BlockKilometers {
  return new Map([...kilometers.entries()].map(([position, rows]) => [position, applyWind(rows, samples, weather)]))
}

export function windSeconds(block: WorkoutBlock): number | null {
  if (block.windFactor === undefined || block.avgSpeed === null || block.avgSpeed <= 0) return null
  const pace = ANALYSIS.metersPerKilometer / block.avgSpeed
  return pace - pace / (1 + block.windFactor)
}

export function windAgainst(blocks: WorkoutBlock[], kilometers: BlockKilometers, weather: WeatherEffect | null): Finding[] {
  const windSpeed = weather?.weather.windSpeed
  if (typeof windSpeed !== 'number' || windSpeed <= 0) return []
  const free = kilometers.size === 0 && blocks.every((block) => block.prescribed === null)
  const sources: { position: number | null; startKm: number; rows: WorkoutBlock[] }[] = free
    ? [{ position: null, startKm: 0, rows: blocks }]
    : [...kilometers.entries()].sort((a, b) => a[0] - b[0]).flatMap(([position, rows]) => {
        if (blocks[position]?.kind !== 'active') return []
        const startKm = blocks.slice(0, position).reduce((sum, block) => sum + block.distance, 0) / ANALYSIS.metersPerKilometer
        return [{ position, startKm: Math.round(startKm), rows }]
      })
  const findings: Finding[] = []
  for (const source of sources) {
    let segment: { from: number; rows: WorkoutBlock[] } | null = null
    const close = () => {
      if (segment !== null) findings.push(windFinding(source.position, segment.from, segment.rows, windSpeed))
      segment = null
    }
    source.rows.forEach((row, index) => {
      if (row.distance < ANALYSIS.fullLapMinimumDistance || (windSeconds(row) ?? 0) < W.windEffectSeconds) {
        close()
        return
      }
      if (segment === null) segment = { from: source.startKm + index + 1, rows: [] }
      segment.rows.push(row)
    })
    close()
  }
  return findings
}

function windFinding(position: number | null, from: number, rows: WorkoutBlock[], windSpeed: number): Finding {
  const kilometers = rows.reduce((sum, row) => sum + row.distance, 0) / ANALYSIS.metersPerKilometer
  const seconds = rows.reduce((sum, row) => sum + row.seconds, 0)
  const calm = rows.reduce((sum, row) => sum + row.seconds / (1 + (row.windFactor ?? 0)), 0)
  return {
    group: 'positive',
    kind: 'windAgainst',
    blockOrdinal: position,
    facts: {
      fromKilometer: from,
      toKilometer: from + rows.length - 1,
      windSpeed: windSpeed * W.metersPerSecondToKmh,
      headwind: (rows.reduce((sum, row) => sum + (row.headwind ?? 0), 0) / rows.length) * W.metersPerSecondToKmh,
      pace: seconds / kilometers,
      mildPace: calm / kilometers,
    },
  }
}

function formFinding(position: number | null, window: FitSample[]): Finding | null {
  const moving = window.filter((sample) => (sample.speed ?? 0) > ANALYSIS.pauseMaximumSpeed)
  const first = moving[0]?.t
  const last = moving.at(-1)?.t
  if (first === undefined || last === undefined || last - first < W.formMinimumSeconds) return null
  const third = (last - first) / 3
  const opening = moving.filter((sample) => sample.t < first + third)
  const closing = moving.filter((sample) => sample.t >= last - third)
  const values = (list: FitSample[], read: (sample: FitSample) => number | null | undefined) => list.flatMap((sample) => {
    const value = read(sample)
    return typeof value === 'number' ? [value] : []
  })
  const openingSpeed = mean(values(opening, (sample) => sample.speed))
  const closingSpeed = mean(values(closing, (sample) => sample.speed))
  if (openingSpeed === null || closingSpeed === null || closingSpeed > openingSpeed * (1 + W.formSpeedTolerance)) return null
  const facts: Record<string, number> = {}
  let fading = false
  const cadenceFrom = mean(values(opening, (sample) => sample.cadence))
  const cadenceTo = mean(values(closing, (sample) => sample.cadence))
  if (cadenceFrom !== null && cadenceTo !== null) {
    Object.assign(facts, { cadenceFrom, cadenceTo })
    fading ||= cadenceFrom - cadenceTo >= W.cadenceDrop
  }
  const stanceFrom = mean(values(opening, (sample) => sample.stanceTime))
  const stanceTo = mean(values(closing, (sample) => sample.stanceTime))
  if (stanceFrom !== null && stanceTo !== null && stanceFrom > 0) {
    Object.assign(facts, { stanceFrom, stanceTo })
    fading ||= stanceTo / stanceFrom - 1 >= W.stanceRise
  }
  return fading ? { group: 'attention', kind: 'runFormFade', blockOrdinal: position, facts } : null
}

export function runFormFade(blocks: WorkoutBlock[], samples: FitSample[]): Finding[] {
  if (!samples.some((sample) => typeof sample.cadence === 'number' || typeof sample.stanceTime === 'number')) return []
  const ordered = [...samples].sort((a, b) => a.t - b.t)
  if (blocks.every((block) => block.prescribed === null)) {
    const finding = formFinding(null, ordered)
    return finding === null ? [] : [finding]
  }
  return blocks.flatMap((block, position) => {
    const start = block.laps[0]?.startOffset
    if (block.kind !== 'active' || block.seconds < W.formMinimumSeconds || start === undefined) return []
    const end = blocks.slice(position + 1).find((item) => item.laps[0] !== undefined)?.laps[0]?.startOffset ?? Infinity
    const finding = formFinding(position, ordered.filter((sample) => sample.t >= start && sample.t < end))
    return finding === null ? [] : [finding]
  })
}

export function dayFacts(day: DayCondition | null | undefined): Record<string, number> {
  if (day === null || day === undefined) return {}
  const facts: Record<string, number> = {}
  if (day.sleepSeconds !== null && day.sleepSeconds < W.shortSleepSeconds) facts.sleepSeconds = day.sleepSeconds
  if (day.sleepScore !== null && day.sleepScore < W.lowSleepScore) facts.sleepScore = day.sleepScore
  if (day.hrvBelowBalanced) facts.hrvLow = 1
  if (day.bodyBattery !== null && day.bodyBattery < W.lowBodyBattery) facts.bodyBattery = day.bodyBattery
  if (day.previousDay !== null) facts.previousDay = day.previousDay
  return facts
}
