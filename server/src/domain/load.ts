import { addDays } from '../garminSync.js'
import { LOAD } from './domainConstants.js'
import type { FFFPoint, LoadFocus } from './domainTypes.js'

export function fitnessFatigueForm(dailyLoad: Map<string, number>, from: string, to: string): FFFPoint[] {
  const points: FFFPoint[] = []
  let fitness = 0
  let fatigue = 0
  for (let day = from; day <= to; day = addDays(day, 1)) {
    const load = dailyLoad.get(day) ?? 0
    const form = fitness - fatigue
    fitness += (load - fitness) / LOAD.fitnessDays
    fatigue += (load - fatigue) / LOAD.fatigueDays
    points.push({ day, fitness, fatigue, form })
  }
  return points
}

export function acuteChronicRatio(dailyLoad: Map<string, number>, on: string): number | null {
  const sum = (days: number) => Array.from({ length: days }, (_, index) => dailyLoad.get(addDays(on, -index)) ?? 0).reduce((total, value) => total + value, 0)
  const chronic = sum(LOAD.chronicDays)
  if (chronic <= 0) {
    return null
  }
  return sum(LOAD.acuteDays) / (chronic / (LOAD.chronicDays / LOAD.acuteDays))
}

export function loadFocus(items: { load: number; zoneSeconds: number[] }[]): LoadFocus | null {
  let low = 0
  let high = 0
  let anaerobic = 0
  for (const item of items) {
    if (item.zoneSeconds.length !== 5 || item.load <= 0) {
      continue
    }
    const total = item.zoneSeconds.reduce((sum, value) => sum + value, 0)
    if (total <= 0) {
      continue
    }
    const [z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0] = item.zoneSeconds
    low += (item.load * (z1 + z2)) / total
    high += (item.load * (z3 + z4)) / total
    anaerobic += (item.load * z5) / total
  }
  const sum = low + high + anaerobic
  return sum > 0 ? { lowAerobic: low / sum, highAerobic: high / sum, anaerobic: anaerobic / sum } : null
}
