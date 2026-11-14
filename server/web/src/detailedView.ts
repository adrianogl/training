import { DETAILED_TEXT } from './constants'
import { dayMonth, kmNumber, paceClock, signedNumber } from './format'
import type { DetailedAnalysisView, DetailedFinding, DetailedRecommendation } from './types'

type Values = DetailedFinding['values']

const number = (values: Values, key: string): number | null => {
  const value = values[key]
  return typeof value === 'number' ? value : null
}

const text = (values: Values, key: string): string => {
  const value = values[key]
  return typeof value === 'string' ? value : ''
}

const percent = (value: number) => kmNumber(value, 1)

export function findingText(finding: DetailedFinding): string {
  const { values } = finding
  const t = DETAILED_TEXT.findings
  switch (finding.key) {
    case 'completion': {
      const done = kmNumber(number(values, 'doneKm') ?? 0, 2)
      const reference = kmNumber(number(values, 'referenceKm') ?? 0, 2)
      const share = percent(number(values, 'percent') ?? 0)
      const average = number(values, 'similarAverage')
      const base = text(values, 'source') === 'plan' ? t.completionPlan(done, reference, share) : t.completionSimilar(done, reference, share)
      return average === null ? base : base + t.completionAverage(percent(average))
    }
    case 'fadeKm': {
      const fade = number(values, 'fadeKm')
      const median = number(values, 'similarMedian')
      const faded = number(values, 'similarFaded') ?? 0
      const total = number(values, 'similarTotal') ?? 0
      if (fade === null) return t.noFade + (faded > 0 ? t.fadeNone(faded, total) : '')
      return t.fadeAt(fade) + (median === null ? '' : t.fadeMedian(kmNumber(median, 1), faded, total))
    }
    case 'hrDrift': {
      const average = number(values, 'similarAverage')
      return t.drift(signedNumber(number(values, 'drift') ?? 0, 1)) + (average === null ? '' : t.driftAverage(signedNumber(average, 1)))
    }
    case 'startPace': {
      const start = number(values, 'todayStart') ?? 0
      const limit = number(values, 'limitPace') ?? start
      return (
        t.startPace(paceClock(start), DETAILED_TEXT.startKilometers) +
        t.startGroups(paceClock(limit), number(values, 'fastEarlyFade') ?? 0, number(values, 'fastTotal') ?? 0, number(values, 'slowEarlyFade') ?? 0, number(values, 'slowTotal') ?? 0, number(values, 'earlyFadeKm') ?? 0)
      )
    }
    case 'readiness': {
      const limit = number(values, 'limit') ?? 0
      const low = number(values, 'lowAverage')
      const high = number(values, 'highAverage')
      return (
        t.readiness(number(values, 'today') ?? 0) +
        (low === null ? '' : t.readinessLow(limit, percent(low), number(values, 'lowCount') ?? 0)) +
        (high === null ? '' : t.readinessHigh(limit, percent(high), number(values, 'highCount') ?? 0))
      )
    }
    case 'weekLoad':
      return (
        t.week(kmNumber(number(values, 'weekKm') ?? 0, 1), signedNumber(number(values, 'percent') ?? 0), kmNumber(number(values, 'averageKm') ?? 0, 1)) +
        (values.hadIntervals === true ? t.weekIntervals : t.weekNoIntervals)
      )
    case 'hrAtPace':
      return t.hrAtPace(signedNumber(number(values, 'deltaBpm') ?? 0, 1), dayMonth(text(values, 'sinceDay')), number(values, 'runs') ?? 0)
    case 'pauses': {
      const count = number(values, 'pauses') ?? 0
      return count === 0 ? t.pausesNone(kmNumber(number(values, 'totalKm') ?? 0, 2)) : t.pauses(count, kmNumber(number(values, 'longestContinuousKm') ?? 0, 2))
    }
    case 'repsConsistency': {
      const drop = number(values, 'recoveryDrop')
      return t.reps(kmNumber(number(values, 'spreadSeconds') ?? 0, 1), number(values, 'reps') ?? 0) + (drop === null ? '' : t.repsRecovery(drop))
    }
    case 'goal': {
      const pace = number(values, 'pace')
      if (text(values, 'kind') === 'continuousLong') {
        const met = values.met
        return t.goalLong(kmNumber(number(values, 'targetKm') ?? 0, 1), kmNumber(number(values, 'continuousKm') ?? 0, 2), pace === null ? null : paceClock(pace), typeof met === 'boolean' ? met : null)
      }
      return t.goalTime(kmNumber(number(values, 'targetKm') ?? 0, 1), paceClock(number(values, 'targetPace') ?? 0), paceClock(pace ?? 0), signedNumber(number(values, 'gapSeconds') ?? 0, 1))
    }
  }
}

export function adviceText(recommendation: DetailedRecommendation): string {
  const t = DETAILED_TEXT.advice
  switch (recommendation.key) {
    case 'startPace':
      return t.startPace(paceClock(recommendation.value), DETAILED_TEXT.startKilometers)
    case 'gel':
      return t.gel(recommendation.value)
    case 'swapDay':
      return t.swapDay(recommendation.value)
    case 'easeWeek':
      return t.easeWeek(Math.round(recommendation.value))
  }
}

const fadeLabel = (value: number) => DETAILED_TEXT.fadeValue(Number(kmNumber(value, 1).replace(',', '.'))).replace('.', ',')

export function detailedKpis(analysis: DetailedAnalysisView) {
  const { completion, fadeKm, hrDrift } = analysis.kpis
  const share = (value: number | null) => (value === null ? null : `${kmNumber(value, 1)}%`)
  const drift = (value: number | null) => (value === null ? null : `${signedNumber(value, 1)}%`)
  return [
    { key: 'completion', value: share(completion.value) ?? '—', average: share(completion.similarAverage) },
    { key: 'fadeKm', value: fadeKm.value === null ? DETAILED_TEXT.noFade : fadeLabel(fadeKm.value), average: fadeKm.similarAverage === null ? null : fadeLabel(fadeKm.similarAverage) },
    { key: 'hrDrift', value: drift(hrDrift.value) ?? '—', average: drift(hrDrift.similarAverage) },
  ] as const
}

export function detailedBars(analysis: DetailedAnalysisView) {
  const t = DETAILED_TEXT
  const today = analysis.kpis.completion.value
  const scale = Math.max(100, today ?? 0, ...analysis.similar.map((item) => item.completion ?? 0))
  const width = (completion: number | null) => (completion === null ? 0 : (completion / scale) * 100)
  const rows = analysis.similar.map((item) => ({
    key: item.activityId,
    day: item.day,
    current: false,
    completion: item.completion,
    width: width(item.completion),
    detail: [
      item.fadeKm === null ? null : t.barFade(item.fadeKm),
      item.complete === null ? null : item.complete ? t.barComplete : t.barIncomplete,
      item.noPauses === null ? null : item.noPauses ? t.barNoPauses : t.barPauses,
    ]
      .filter((part): part is string => part !== null)
      .join(' · '),
  }))
  return [...rows, { key: 0, day: '', current: true, completion: today, width: width(today), detail: analysis.fadeKm === null ? '' : t.barFade(analysis.fadeKm) }]
}
