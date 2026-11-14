import { CHECKLIST_TEXT, KNOWN_DISTANCES, STRETCH_LABELS } from './constants'
import { dayMonth, duration, kmNumber, paceClock } from './format'
import type { ChecklistItem, KmPlan } from './types'

export interface Stretch {
  from: number
  to: number
  label: string
  pace: number
  split: number
}

export function kmLength(index: number, kms: number, distance: number): number {
  return index < kms - 1 ? 1000 : distance - (kms - 1) * 1000
}

export function stretches(kms: KmPlan[], distance: number, factor = 1): Stretch[] {
  const result: Stretch[] = []
  let elapsed = 0
  let previousManual = false
  for (const km of kms) {
    const length = kmLength(km.index, kms.length, distance)
    const seconds = ((km.pace * factor) * length) / 1000
    elapsed += seconds
    const label = STRETCH_LABELS[km.label] ?? km.label
    const last = result.at(-1)
    if (last !== undefined && last.label === label && !km.manual && !previousManual) {
      const covered = (last.to - last.from + 1) * 1000
      last.pace = (last.pace * covered + km.pace * factor * length) / (covered + length)
      last.to = km.index + 1
      last.split = elapsed
    } else {
      result.push({ from: km.index + 1, to: km.index + 1, label, pace: km.pace * factor, split: elapsed })
    }
    previousManual = km.manual
  }
  return result
}

export function parseDistance(text: string): number | null {
  const clean = text.trim().replace(/\s*km$/i, '')
  const known = KNOWN_DISTANCES[clean]
  if (known !== undefined) return known
  const value = Number(clean.replace(',', '.'))
  return Number.isFinite(value) && value > 0 ? value * 1000 : null
}

export function distanceText(meters: number): string {
  const entry = Object.entries(KNOWN_DISTANCES).find(([key, value]) => value === meters && key.includes(','))
  return entry?.[0] ?? kmNumber(meters / 1000, 2)
}

export function checklistLine(item: ChecklistItem): { title: string; detail: string } {
  switch (item.kind) {
    case 'weeklyVolume':
      return { title: CHECKLIST_TEXT.weeklyVolume.title(kmNumber(item.targetKm)), detail: item.averageKm === null ? CHECKLIST_TEXT.weeklyVolume.missing : CHECKLIST_TEXT.weeklyVolume.detail(kmNumber(item.averageKm)) }
    case 'racePace':
      return { title: CHECKLIST_TEXT.racePace.title, detail: item.pace === null ? CHECKLIST_TEXT.racePace.missing : CHECKLIST_TEXT.racePace.detail(kmNumber(item.doneKm), `${paceClock(item.pace)}/km`, kmNumber(item.targetKm)) }
    case 'tuneUp':
      return {
        title: CHECKLIST_TEXT.tuneUp.title(kmNumber(item.distanceKm)),
        detail: item.best === null ? CHECKLIST_TEXT.tuneUp.missing(kmNumber(item.distanceKm)) : CHECKLIST_TEXT.tuneUp.detail(dayMonth(item.best.day), kmNumber(item.best.km), `${paceClock(item.best.pace)}/km`),
      }
    case 'course':
      return { title: CHECKLIST_TEXT.course.title, detail: item.km === null ? CHECKLIST_TEXT.course.missing : CHECKLIST_TEXT.course.detail(kmNumber(item.km), item.gain ?? 0) }
    case 'goal':
      return { title: CHECKLIST_TEXT.goal.title, detail: item.goalSeconds === null ? CHECKLIST_TEXT.goal.missing : CHECKLIST_TEXT.goal.detail(duration(item.goalSeconds), item.priority) }
  }
}
