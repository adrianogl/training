import { ANALYSIS } from './analysisConstants.js'
import type { BlockStatus, EvolutionFacts, Finding, NarratedFinding, WorkoutAssessment, WorkoutBlock } from './analysisTypes.js'
import { NARRATIVE } from './narrativeConstants.js'

const D = NARRATIVE.detail

export function clock(seconds: number): string {
  const total = Math.round(seconds)
  const hours = Math.trunc(total / 3600)
  const minutes = Math.trunc((total % 3600) / 60)
  const secs = total % 60
  const pad = (value: number) => String(value).padStart(2, '0')
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(secs)}` : `${minutes}:${pad(secs)}`
}

const integer = (value: number | undefined) => Math.round(value ?? 0)
const decimal = (value: number | undefined) => (value ?? 0).toFixed(2).replace('.', ',')
const percent = (value: number | undefined) => `${Math.round((value ?? 0) * 100)}%`
const temperatureText = (value: number | undefined) => `${integer(value)} °C`
const weatherText = (facts: Record<string, number>) =>
  facts.cold === 1 || facts.dewPoint === undefined ? temperatureText(facts.temperature) : `${temperatureText(facts.temperature)}, orvalho ${temperatureText(facts.dewPoint)}`
const weatherPercent = (facts: Record<string, number>) => `${((facts.weatherFactor ?? 0) * 100).toFixed(1).replace('.', ',')}%`
const hasWeather = (facts: Record<string, number>) => facts.temperature !== undefined
const PREVIOUS_DAY: Record<number, string> = { 1: 'limiar', 2: 'tiros', 3: 'longão', 4: 'treino de pernas' }
const listText = (items: string[]) => (items.length > 1 ? `${items.slice(0, -1).join(', ')} e ${items.at(-1) ?? ''}` : (items[0] ?? ''))
export function dayCause(facts: Record<string, number>): string | null {
  const state: string[] = []
  if (facts.sleepSeconds !== undefined) {
    const minutes = integer(facts.sleepSeconds / 60)
    state.push(`noite de ${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}`)
  } else if (facts.sleepScore !== undefined) state.push(`sono com nota ${integer(facts.sleepScore)}`)
  if (facts.hrvLow === 1) state.push('HRV abaixo da faixa')
  if (facts.bodyBattery !== undefined) state.push(`Body Battery ${integer(facts.bodyBattery)} de manhã`)
  const previous = facts.previousDay === undefined ? undefined : PREVIOUS_DAY[integer(facts.previousDay)]
  if (state.length === 0 && previous === undefined) return null
  return [state.length === 0 ? null : `Causa provável: ${listText(state)}.`, previous === undefined ? null : `Ontem teve ${previous}.`].filter((item) => item !== null).join(' ')
}
const formEvidence = (facts: Record<string, number>) => {
  const parts: string[] = []
  if (facts.cadenceFrom !== undefined && facts.cadenceTo !== undefined) parts.push(`cadência ${integer(facts.cadenceFrom)} → ${integer(facts.cadenceTo)} passos/min`)
  if (facts.stanceFrom !== undefined && facts.stanceTo !== undefined && facts.stanceFrom > 0) {
    parts.push(`contato com o solo ${integer(facts.stanceFrom)} → ${integer(facts.stanceTo)} ms (+${integer((facts.stanceTo / facts.stanceFrom - 1) * 100)}%)`)
  }
  return parts.join(' · ')
}
const kmh = (value: number | undefined) => `${integer(value)} km/h`
const paceClock = (speed: number | undefined) => (speed === undefined || speed <= 0 ? null : clock(ANALYSIS.metersPerKilometer / speed))
const pace = (speed: number | undefined) => {
  const value = paceClock(speed)
  return value === null ? null : `${value} ${NARRATIVE.paceUnit}`
}
const distanceText = (meters: number) => (meters < ANALYSIS.metersPerKilometer ? `${Math.round(meters)} m` : `${kilometers(meters)} ${NARRATIVE.distanceUnit}`)
const kilometers = (meters: number) => String(Number((meters / ANALYSIS.metersPerKilometer).toFixed(2))).replace('.', ',')
const durationText = (seconds: number) => {
  const total = Math.round(seconds)
  if (total < 60) return `${total} s`
  return total % 60 === 0 ? `${total / 60} min` : `${Math.trunc(total / 60)} min ${total % 60} s`
}
const labelOf = (finding: Finding, blocks: WorkoutBlock[]) => (finding.blockOrdinal === null ? null : (blocks[finding.blockOrdinal]?.label ?? null))
const statusOf = (finding: Finding, blocks: WorkoutBlock[]): BlockStatus | null => (finding.blockOrdinal === null ? null : (blocks[finding.blockOrdinal]?.status ?? null))

export const orderedFindings = (assessment: WorkoutAssessment) => [...assessment.positives, ...assessment.negatives, ...assessment.attention]

function offTargetDirection(status: BlockStatus | null): string {
  switch (status) {
    case 'aboveTarget':
      return 'acima do alvo'
    case 'belowTarget':
      return 'abaixo do alvo'
    case 'slower':
      return 'mais lento que o prescrito'
    case 'faster':
      return 'mais rápido que o prescrito'
    default:
      return 'fora do alvo prescrito'
  }
}

const isHeartRateTarget = (status: BlockStatus | null) => status === 'aboveTarget' || status === 'belowTarget'

function heartRateRange(facts: Record<string, number>): string | null {
  return facts.targetLow === undefined || facts.targetHigh === undefined ? null : `${integer(facts.targetLow)}–${integer(facts.targetHigh)} bpm`
}

function paceRange(facts: Record<string, number>): string | null {
  if (facts.targetLow === undefined || facts.targetHigh === undefined) return null
  const fast = paceClock(facts.targetHigh)
  const slow = paceClock(facts.targetLow)
  return fast === null || slow === null ? null : `${fast}–${slow} ${NARRATIVE.paceUnit}`
}

function incompleteProgress(finding: Finding, blocks: WorkoutBlock[]): { done: string; target: string; percent: number } | null {
  const facts = finding.facts
  const notExecuted = statusOf(finding, blocks) === 'notExecuted'
  if (facts.targetDistance !== undefined && facts.targetDistance > 0) {
    const done = notExecuted ? 0 : (facts.distance ?? 0)
    const shared = facts.targetDistance >= ANALYSIS.metersPerKilometer && done >= ANALYSIS.metersPerKilometer
    return { done: shared ? kilometers(done) : distanceText(done), target: distanceText(facts.targetDistance), percent: Math.round((done / facts.targetDistance) * 100) }
  }
  if (facts.targetSeconds !== undefined && facts.targetSeconds > 0) {
    const done = notExecuted ? 0 : (facts.seconds ?? 0)
    return { done: clock(done), target: clock(facts.targetSeconds), percent: Math.round((done / facts.targetSeconds) * 100) }
  }
  return null
}

function slowdownSentences(facts: Record<string, number>): string[] {
  const rise = facts.heartRateRise === undefined ? null : integer(facts.heartRateRise)
  if (facts.fadeKilometer === undefined || facts.slowdown === undefined) return rise === null ? [] : [D.heartRateRise(rise)]
  const kilometer = integer(facts.fadeKilometer)
  const held = D.slowdown(kilometer - 1, integer(facts.slowdown), kilometer)
  return [rise === null ? `${held}.` : `${held}${D.slowdownHeartRate(rise)}.`]
}

function pauseSentences(facts: Record<string, number>): string[] {
  if (facts.pauseCount === undefined || facts.pauseKilometer === undefined || facts.pauseSeconds === undefined) return []
  const start = (facts.pauseKilometer).toFixed(1).replace('.', ',')
  const total = durationText(facts.pauseSeconds)
  const count = integer(facts.pauseCount)
  return [count === 1 ? D.pauseOne(start, total) : D.pauseMany(count, start, total)]
}

function dayContextSentences(facts: Record<string, number>): string[] {
  return [facts.readiness === undefined ? null : D.dayReadiness(integer(facts.readiness)), facts.ratio === undefined ? null : D.dayRatio(decimal(facts.ratio))].filter((item): item is string => item !== null)
}

function incompleteWhy(finding: Finding, blocks: WorkoutBlock[]): string {
  const facts = finding.facts
  if (statusOf(finding, blocks) === 'notExecuted') return NARRATIVE.why.notExecuted
  const cause = dayCause(facts)
  const signals = [...slowdownSentences(facts), ...pauseSentences(facts), ...dayContextSentences(facts), ...(cause === null ? [] : [cause])]
  if (signals.length > 0) return signals.join(' ')
  if (facts.targetDistance === undefined || facts.distance === undefined || facts.targetDistance <= facts.distance) return NARRATIVE.why.incomplete
  return D.remaining(distanceText(facts.targetDistance - facts.distance))
}

function offTarget(finding: Finding, label: string, blocks: WorkoutBlock[]): string {
  const facts = finding.facts
  const status = statusOf(finding, blocks)
  const direction = offTargetDirection(status)
  if (isHeartRateTarget(status)) {
    const heartRate = facts.heartRate === undefined ? NARRATIVE.unknown : `${integer(facts.heartRate)} bpm`
    const range = heartRateRange(facts)
    return range === null ? `${label} com FC ${direction}: ${heartRate}.` : `${label} com FC ${direction}: ${heartRate} para ${range}.`
  }
  const value = pace(facts.speed) ?? NARRATIVE.unknown
  const range = paceRange(facts)
  return range === null ? `${label} ${direction}: ${value}.` : `${label} ${direction}: ${value} para ${range}.`
}

function incomplete(finding: Finding, label: string, blocks: WorkoutBlock[]): string {
  const state = statusOf(finding, blocks) === 'notExecuted' ? 'não executado' : 'não completado'
  const progress = incompleteProgress(finding, blocks)
  return progress === null ? `${label} ${state}.` : `${label} ${state}: ${progress.done} de ${progress.target} (${progress.percent}%).`
}

function kilometerRange(facts: Record<string, number>): string {
  const from = integer(facts.fromKilometer)
  const to = integer(facts.toKilometer)
  if (to <= from) return `km ${from}`
  return `km ${from} ${to === from + 1 ? 'e' : 'a'} ${to}`
}

function elevationText(facts: Record<string, number>): string {
  const climb = integer(facts.climb)
  const descent = integer(facts.descent)
  return [climb >= ANALYSIS.elevationMinimum ? `+${climb} m` : null, descent >= ANALYSIS.elevationMinimum ? `−${descent} m` : null]
    .filter((part): part is string => part !== null)
    .join(' e ')
}

const elevationSegment = (facts: Record<string, number>) => `${kilometerRange(facts)}: ${elevationText(facts)} a ${clockOf(facts.pace) ?? ''}${NARRATIVE.paceUnit}`

export function findingText(finding: Finding, blocks: WorkoutBlock[]): string {
  const facts = finding.facts
  const label = labelOf(finding, blocks) ?? NARRATIVE.genericBlock
  switch (finding.kind) {
    case 'blockInTarget': {
      const inTarget = integer(facts.inTarget)
      const total = integer(facts.total)
      if (total === 1) return 'O bloco ativo ficou dentro do alvo prescrito.'
      return inTarget === total ? `Todos os blocos ativos dentro do alvo prescrito: ${inTarget} de ${total}.` : `${inTarget} de ${total} blocos ativos dentro do alvo prescrito.`
    }
    case 'steadyPace':
      return `${label} com pace constante: ${integer(facts.spread)} s/km de diferença entre as voltas.`
    case 'lowerHeartRateThanBefore':
      return `${label} com FC ${integer(facts.delta)} bpm menor que da última vez, no mesmo pace.`
    case 'goodRecovery':
      return `${label}: a FC caiu ${integer(facts.drop)} bpm desde o pico do bloco anterior.`
    case 'blockOffTarget':
      return offTarget(finding, label, blocks)
    case 'stepIncomplete':
      return incomplete(finding, label, blocks)
    case 'paceFade': {
      const fade = `${label} perdeu ritmo no fim: a última volta saiu ${integer(facts.fade)} s/km mais lenta que a mediana.`
      return hasWeather(facts) ? `${fade} O calor de ${weatherText(facts)} pesou.` : fade
    }
    case 'cardiacDrift': {
      const drift = `${label} com desacoplamento: a FC subiu ${percent(facts.rise)} (${integer(facts.fromHR)} → ${integer(facts.toHR)} bpm) com o pace estável.`
      return hasWeather(facts) ? `${drift} Esperado com ${weatherText(facts)}.` : drift
    }
    case 'windAgainst':
      return `${kilometerRange(facts)} com vento contra de ${kmh(facts.headwind)}: ${clockOf(facts.pace) ?? ''}${NARRATIVE.paceUnit} equivale a ${clockOf(facts.mildPace) ?? ''}${NARRATIVE.paceUnit} sem o vento.`
    case 'runFormFade':
      return `${label} com a forma caindo no fim: ${formEvidence(facts)}.`
    case 'weatherSlower':
      return `Com ${weatherText(facts)}, o ritmo de ${clockOf(facts.pace) ?? ''}${NARRATIVE.paceUnit} equivale a ${clockOf(facts.mildPace) ?? ''}${NARRATIVE.paceUnit} em clima ameno.`
    case 'zoneAboveTarget':
      return `${label} em Z${integer(facts.zone)}, acima do esperado para um bloco leve.`
    case 'hardOnLowReadiness':
      return `Treino forte num dia de prontidão baixa: ${integer(facts.readiness)} de 100.`
    case 'highAcuteChronic':
      return `Carga aguda:crônica alta: ${decimal(facts.ratio)}.`
    case 'climbSlower':
    case 'descentFaster': {
      const plural = integer(facts.toKilometer) > integer(facts.fromKilometer)
      const subject = `${plural ? 'Os' : 'O'} ${kilometerRange(facts)}`
      return `${subject}, com ${elevationText(facts)}, ${plural ? 'saíram' : 'saiu'} a ${clockOf(facts.pace) ?? ''}${NARRATIVE.paceUnit}, o equivalente a ${clockOf(facts.flatPace) ?? ''}${NARRATIVE.paceUnit} no plano.`
    }
  }
}

const clockOf = (seconds: number | undefined) => (seconds === undefined || seconds <= 0 ? null : clock(seconds))
const joined = (parts: (string | null)[]) => {
  const text = parts.filter((part): part is string => part !== null).join(' · ')
  return text === '' ? null : text
}

function inTargetValues(blocks: WorkoutBlock[]): string | null {
  const inTarget = blocks.filter((block) => block.kind === 'active' && block.status === 'inTarget')
  if (inTarget.length === 0) return null
  if (inTarget.every((block) => block.prescribed?.target.kind === 'heartRateBpm')) {
    const values = inTarget.flatMap((block) => (block.avgHeartRate === null ? [] : [String(block.avgHeartRate)]))
    return values.length === 0 ? null : `${values.join(' · ')} bpm`
  }
  const values = inTarget.flatMap((block) => {
    const value = paceClock(block.avgSpeed ?? undefined)
    return value === null ? [] : [value]
  })
  return values.length === 0 ? null : `${values.join(' · ')} ${NARRATIVE.paceUnit}`
}

export function findingEvidence(finding: Finding, blocks: WorkoutBlock[]): string | null {
  const facts = finding.facts
  switch (finding.kind) {
    case 'blockInTarget':
      return inTargetValues(blocks)
    case 'steadyPace': {
      const fastest = clockOf(facts.fastestPace)
      const slowest = clockOf(facts.slowestPace)
      if (fastest === null || slowest === null) return null
      const range = `${D.lapsFrom} ${fastest} ${D.to} ${slowest} ${NARRATIVE.paceUnit}`
      return facts.flatAdjusted === 1 ? `${D.onLevel}, ${range}` : range
    }
    case 'lowerHeartRateThanBefore':
      if (facts.heartRate === undefined || facts.beforeHeartRate === undefined) return null
      return joined([`${integer(facts.heartRate)} bpm ${D.versus} ${integer(facts.beforeHeartRate)} bpm`, pace(facts.speed)])
    case 'goodRecovery':
      if (facts.peak === undefined || facts.recovered === undefined) return null
      return `${D.peak} ${integer(facts.peak)} bpm → ${D.average} ${integer(facts.recovered)} bpm`
    case 'blockOffTarget': {
      const heartRate = facts.heartRate === undefined ? null : `FC ${integer(facts.heartRate)} bpm`
      const paceText = pace(facts.speed)
      if (isHeartRateTarget(statusOf(finding, blocks))) {
        const range = heartRateRange(facts)
        return joined([heartRate, range === null ? null : `${D.target} ${range}`, paceText])
      }
      const range = paceRange(facts)
      return joined([paceText, range === null ? null : `${D.target} ${range}`, heartRate])
    }
    case 'stepIncomplete': {
      const progress = incompleteProgress(finding, blocks)
      return progress === null ? null : `${progress.done} ${D.of} ${progress.target} · ${progress.percent}%`
    }
    case 'paceFade': {
      const last = clockOf(facts.lastPace)
      const middle = clockOf(facts.medianPace)
      if (last === null || middle === null) return null
      const raw = clockOf(facts.pace)
      if (facts.flatAdjusted !== 1 || raw === null) return `${D.lastLap} ${last} · ${D.median} ${middle} ${NARRATIVE.paceUnit}`
      return `${D.lastLap} ${raw} (+${integer(facts.lastClimb)} m) · ${D.onLevel} ${last} · ${D.medianOnLevel} ${middle} ${NARRATIVE.paceUnit}`
    }
    case 'climbSlower':
    case 'descentFaster':
      return elevationSegment(facts)
    case 'windAgainst':
      return `${kmh(facts.windSpeed)} · ${clockOf(facts.pace) ?? ''} → ${clockOf(facts.mildPace) ?? ''} /km sem o vento`
    case 'runFormFade':
      return formEvidence(facts)
    case 'weatherSlower':
      return `${clockOf(facts.pace) ?? ''} → ${clockOf(facts.mildPace) ?? ''} ${NARRATIVE.paceUnit} · ${weatherText(facts)}`
    case 'cardiacDrift':
      return `FC ${integer(facts.fromHR)} → ${integer(facts.toHR)} bpm · +${percent(facts.rise)}`
    case 'zoneAboveTarget':
      return joined([pace(facts.speed), facts.heartRate === undefined ? null : `FC ${integer(facts.heartRate)} bpm`])
    case 'hardOnLowReadiness':
      return `${D.readiness} ${integer(facts.readiness)} ${D.of} 100 · ${D.limit} ${ANALYSIS.lowReadiness}`
    case 'highAcuteChronic':
      return `${D.ratio} ${decimal(facts.ratio)} · ${D.limit} ${decimal(ANALYSIS.highAcuteChronic)}`
  }
}

const CAUSE_KINDS = new Set(['blockOffTarget', 'paceFade', 'cardiacDrift'])

export function findingWhy(finding: Finding, blocks: WorkoutBlock[]): string {
  const base = baseWhy(finding, blocks)
  const cause = CAUSE_KINDS.has(finding.kind) ? dayCause(finding.facts) : null
  return cause === null ? base : `${base} ${cause}`
}

function baseWhy(finding: Finding, blocks: WorkoutBlock[]): string {
  const W = NARRATIVE.why
  const facts = finding.facts
  switch (finding.kind) {
    case 'blockInTarget':
      return facts.inTarget === facts.total ? W.allInTarget : W.someInTarget
    case 'steadyPace':
      return facts.flatAdjusted === 1 ? W.steadyLevel : W.steadyPace
    case 'lowerHeartRateThanBefore':
      return W.lowerHeartRate
    case 'goodRecovery':
      return W.goodRecovery
    case 'blockOffTarget': {
      const status = statusOf(finding, blocks)
      if (status === 'faster') return W.faster
      if (status === 'aboveTarget') return W.heartRateAbove
      if (status === 'belowTarget') return W.heartRateBelow
      if (facts.recoveryHeartRate === undefined) return W.slower
      const bpm = integer(facts.recoveryHeartRate)
      return facts.recoveryHighest === 1 ? W.slowerHighestRecovery(bpm) : W.slowerAfterRecovery(bpm)
    }
    case 'stepIncomplete':
      return incompleteWhy(finding, blocks)
    case 'paceFade': {
      const base = facts.flatAdjusted === 1 ? W.paceFadeLevel : W.paceFade
      return hasWeather(facts) ? base + W.paceFadeWeather(weatherText(facts)) : base
    }
    case 'climbSlower':
      return W.climb(clockOf(facts.flatPace) ?? '')
    case 'descentFaster':
      return W.descent(clockOf(facts.flatPace) ?? '')
    case 'windAgainst':
      return W.wind(kmh(facts.headwind), clockOf(facts.mildPace) ?? '')
    case 'runFormFade':
      return W.runForm
    case 'weatherSlower':
      return (facts.cold === 1 ? W.coldSlower : W.heatSlower)(weatherText(facts), weatherPercent(facts), clockOf(facts.mildPace) ?? '')
    case 'cardiacDrift':
      return hasWeather(facts) ? W.cardiacDriftWeather(weatherText(facts)) : W.cardiacDrift
    case 'zoneAboveTarget':
      return W.zoneAbove
    case 'hardOnLowReadiness':
      return W.lowReadiness
    case 'highAcuteChronic':
      return W.acuteChronic
  }
}

export function evolutionText(facts: EvolutionFacts): string {
  const seconds = Math.round(Math.abs(facts.paceDelta))
  const paceText = Math.abs(facts.paceDelta) < NARRATIVE.paceDeltaThreshold ? 'Mesmo pace' : facts.paceDelta < 0 ? `${seconds} s/km mais rápido` : `${seconds} s/km mais lento`
  const since = `em relação a ${facts.oldestDate.replace(/^\.+|\.+$/g, '')}`
  if (facts.heartRateDelta === null) return `${paceText} ${since}.`
  const beats = Math.round(Math.abs(facts.heartRateDelta))
  const heartRate = Math.abs(facts.heartRateDelta) < NARRATIVE.heartRateDeltaThreshold ? 'FC igual' : facts.heartRateDelta < 0 ? `FC ${beats} bpm menor` : `FC ${beats} bpm maior`
  return `${paceText}, ${heartRate}, ${since}.`
}

export function narrate(assessment: WorkoutAssessment, blocks: WorkoutBlock[]): NarratedFinding[] {
  return orderedFindings(assessment).map((finding) => ({
    group: finding.group,
    kind: finding.kind,
    blockOrdinal: finding.blockOrdinal,
    text: findingText(finding, blocks),
    evidence: findingEvidence(finding, blocks),
    why: findingWhy(finding, blocks),
  }))
}
