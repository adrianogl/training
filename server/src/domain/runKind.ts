import type { RunShape } from '../fit/fitTypes.js'
import type { ActivitySummary } from '../types.js'
import { RUN_KIND } from './domainConstants.js'
import type { RunKind } from './domainTypes.js'

const normalized = (text: string) => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
const mentions = (text: string, words: readonly string[]) => words.some((word) => text.includes(word))

export function isLongRun(name: string, distanceMeters: number, goalKm: number | null): boolean {
  const text = normalized(name)
  if (mentions(text, RUN_KIND.longWords)) return true
  if (mentions(text, [...RUN_KIND.intervalWords, ...RUN_KIND.easyWords])) return false
  return distanceMeters >= Math.max((goalKm ?? 0) * 1000 * RUN_KIND.longShare, RUN_KIND.longMinimumMeters)
}

export function classifyRun(run: ActivitySummary, shape: RunShape | undefined, raceGoalKms: number[]): RunKind {
  if (shape?.hasRepeats) return 'intervals'
  const names = [shape?.name, run.name].filter((name): name is string => typeof name === 'string').join(' ')
  const text = normalized(names)
  if (mentions(text, RUN_KIND.raceWords)) return 'race'
  if (mentions(text, RUN_KIND.intervalWords)) return 'intervals'
  if (mentions(text, RUN_KIND.longWords)) return 'long'
  if (mentions(text, RUN_KIND.tempoWords)) return 'tempo'
  if (mentions(text, RUN_KIND.easyWords)) return 'easy'
  if (shape?.hasHardActiveStep) return 'tempo'
  const meters = run.distanceMeters ?? 0
  if (raceGoalKms.some((km) => meters >= km * 1000 * RUN_KIND.raceLow && meters <= km * 1000 * RUN_KIND.raceHigh)) return 'race'
  if (shape?.hasRepeatedActiveLaps) return 'intervals'
  if (isLongRun(names, meters, null)) return 'long'
  return 'easy'
}
