import { STRENGTH } from './strengthConstants.js'
import { ISSUE } from './strengthText.js'
import type { ContextExercise, DayReport, ResponseDay, ResponseExercise, StrengthContext, StrengthResponse } from './strengthTypes.js'

const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/
const MS_PER_DAY = 86_400_000

function toTime(iso: string): number | null {
  if (!DAY_PATTERN.test(iso)) return null
  const time = Date.parse(`${iso}T12:00:00Z`)
  return Number.isNaN(time) || new Date(time).toISOString().slice(0, 10) !== iso ? null : time
}

function addDays(iso: string, days: number): string {
  return new Date(Date.parse(`${iso}T12:00:00Z`) + days * MS_PER_DAY).toISOString().slice(0, 10)
}

function splitList(value: string | undefined): string[] {
  return value === undefined || value === '' ? [] : value.split(STRENGTH.catalogListSeparator)
}

export function catalogExercise(entry: ContextExercise | string): ContextExercise | null {
  if (typeof entry !== 'string') return isObject(entry) && typeof entry.id === 'string' ? entry : null
  const [id, padrao, equipamento, regioes, focos, marks = ''] = entry.split(STRENGTH.catalogSeparator)
  if (!id || !padrao || !equipamento) return null
  return {
    id, padrao, equipamento, regioes: splitList(regioes), focos: splitList(focos),
    unilateral: marks.includes(STRENGTH.catalogUnilateral), isometria: marks.includes(STRENGTH.catalogTimed),
  }
}

function weekday(iso: string): string {
  const index = (new Date(Date.parse(`${iso}T12:00:00Z`)).getUTCDay() + 6) % 7
  return STRENGTH.weekdays[index] ?? 'seg'
}

const inRange = (value: number, [low, high]: readonly [number, number]) => Number.isInteger(value) && value >= low && value <= high

function doseIsValid(item: ResponseExercise): boolean {
  if (!inRange(item.series, STRENGTH.sets) || !inRange(item.descanso ?? STRENGTH.defaultRest, STRENGTH.rest)) return false
  if (item.segundos !== undefined) return inRange(item.segundos, STRENGTH.seconds)
  return item.reps !== undefined && inRange(item.reps, STRENGTH.reps)
}

function estimatedSeconds(item: ResponseExercise, exercise: ContextExercise): number {
  const single = item.segundos ?? (item.reps ?? 0) * STRENGTH.secondsPerRep
  const work = exercise.unilateral ? single * 2 : single
  return item.series * (work + (item.descanso ?? STRENGTH.defaultRest))
}

export function parseResponse(text: string): StrengthResponse | { error: 'invalid' } | { error: 'unsupported_version'; version: number } {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start < 0 || end <= start) return { error: 'invalid' }
  let value: unknown
  try {
    value = JSON.parse(text.slice(start, end + 1))
  } catch {
    return { error: 'invalid' }
  }
  if (typeof value !== 'object' || value === null) return { error: 'invalid' }
  const body = value as Partial<StrengthResponse>
  if (typeof body.versao !== 'number') return { error: 'invalid' }
  if (body.versao !== STRENGTH.version) return { error: 'unsupported_version', version: body.versao }
  if (!Array.isArray(body.treinos)) return { error: 'invalid' }
  return body as StrengthResponse
}

const isObject = (value: unknown): boolean => typeof value === 'object' && value !== null && !Array.isArray(value)

export function validateResponse(response: StrengthResponse, context: StrengthContext): DayReport[] {
  return response.treinos.filter((entry): entry is ResponseDay => isObject(entry)).map((entry) => validateDay(entry, context))
}

function validateDay(entry: ResponseDay, context: StrengthContext): DayReport {
  const report: DayReport = { dia: String(entry.dia), erros: [], avisos: [], minutos_estimados: null }
  const time = toTime(String(entry.dia))
  if (time === null) {
    report.erros.push(ISSUE.invalidDate)
    return report
  }
  const day = String(entry.dia)
  const name = weekday(day)
  const session = context.dias_do_treinador.find((item) => item.dia_da_semana === name)
  const mfitDays = new Set(context.mfit.map((item) => item.dia_da_semana))
  if (day <= context.periodo.hoje) report.erros.push(ISSUE.pastDay)
  else if (day < context.periodo.inicio || day > context.periodo.fim) report.erros.push(ISSUE.outOfPeriod)
  else if (mfitDays.has(name)) {
    if (entry.substitui_mfit === true) report.avisos.push(ISSUE.replacesMFIT)
    else report.erros.push(ISSUE.mfitDay)
  }
  else if (session === undefined) report.erros.push(ISSUE.notTrainerDay)

  if (entry.foco !== undefined && !(STRENGTH.groups as readonly string[]).includes(String(entry.foco))) report.erros.push(ISSUE.invalidFocus(String(entry.foco)))

  const place = entry.local ?? session?.local ?? 'gym'
  const allowed = STRENGTH.equipmentByPlace[place] ?? []
  const exercises = Array.isArray(entry.exercicios) ? entry.exercicios.filter((item): item is ResponseExercise => isObject(item) && typeof item.id === 'string') : []
  if (exercises.length === 0) report.erros.push(ISSUE.noExercises)
  if (exercises.length > STRENGTH.maxExercises) report.erros.push(ISSUE.tooManyExercises)
  const catalog = new Map(context.catalogo.map(catalogExercise).filter((exercise): exercise is ContextExercise => exercise !== null).map((exercise) => [exercise.id, exercise]))
  const known: ContextExercise[] = []
  let seconds = 0
  for (const item of exercises) {
    const exercise = catalog.get(item.id)
    if (exercise === undefined) {
      report.erros.push(ISSUE.unknownExercise(item.id))
      continue
    }
    if (!allowed.includes(exercise.equipamento)) report.erros.push(ISSUE.wrongPlace(item.id))
    if (exercise.regioes.some((region) => context.dor.includes(region))) report.erros.push(ISSUE.painRegion(item.id))
    if (!doseIsValid(item)) report.erros.push(ISSUE.doseOutOfRange(item.id))
    const last = context.ultimas_cargas_kg[item.id]
    if (item.kg !== undefined && last !== undefined && item.kg > last * STRENGTH.loadJumpShare) report.avisos.push(ISSUE.loadJump(item.id))
    known.push(exercise)
    seconds += estimatedSeconds(item, exercise)
  }
  const heavy = known.filter((exercise) => (STRENGTH.legPatterns as readonly string[]).includes(exercise.padrao) && (STRENGTH.loadedEquipment as readonly string[]).includes(exercise.equipamento)).length >= STRENGTH.heavyLegExercises
  const quality = [1, 2].some((offset) => {
    const run = context.corrida.find((item) => item.dia === addDays(day, offset))
    return run !== undefined && (STRENGTH.qualityKinds as readonly string[]).includes(run.tipo)
  })
  if (heavy && quality) report.erros.push(ISSUE.heavyLegsBeforeQuality)
  if (context.prova) {
    const until = Math.round((Date.parse(`${context.prova.dia}T12:00:00Z`) - time) / MS_PER_DAY)
    if (until >= 0 && until <= STRENGTH.raceRestDays) report.erros.push(ISSUE.nearRace)
  }
  const estimated = Math.round(seconds / 60)
  const planned = entry.minutos ?? session?.minutos ?? STRENGTH.defaultMinutes
  if (Math.abs(estimated - planned) > STRENGTH.durationToleranceMinutes) report.avisos.push(ISSUE.durationOff(estimated, planned))
  report.minutos_estimados = estimated
  return report
}
