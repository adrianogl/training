import { describe, expect, it } from 'vitest'
import { stepRows } from '../src/trainerSteps'
import { dayLine, defaultDay, goalCaption, parseTrainerPlan, strengthTags, triggerText, weekCells } from '../src/trainerView'
import type { TrainerPlan, TrainerStep, TrainerWorkout } from '../src/types'

const step = (overrides: Partial<TrainerStep>): TrainerStep => ({ kind: 'work', repeats: 1, meters: 1000, restSeconds: null, paceLow: null, paceHigh: null, method: null, ...overrides })
const workout = (kind: TrainerWorkout['kind'], steps: TrainerStep[]): TrainerWorkout => ({
  day: '2026-11-17', kind, title: 'Treino', totalMeters: 10000, steps, paceLow: null, paceHigh: null, note: null, rationale: '', method: null, edited: false, variant: null,
})
const rows = (value: TrainerWorkout) => stepRows(value).map((row) => [row.title, row.detail, row.header, row.nested])

const raw = {
  target: { kind: 'race', name: 'Meia de SP', date: '2027-01-17', distanceMeters: 21097.5, goalSeconds: 5940 },
  paces: { easy: 330, long: 340, threshold: 285, vo2max: 260, race: 281 },
  weeks: [
    { index: 2, start: '2026-11-23', phase: 'build', isRecovery: true, plannedMeters: 30000, longMeters: 12000, thresholdFocus: '', vo2Focus: '' },
    { index: 1, start: '2026-11-16', phase: 'futura', isRecovery: false, plannedMeters: 40000, longMeters: 16000 },
  ],
  workouts: [
    { day: '2026-11-18', kind: 'easy', title: 'Rodagem', totalMeters: 8000, steps: [], rationale: 'base', edited: true },
    { day: '2026-11-17', kind: 'threshold', title: 'Limiar', totalMeters: 11800, steps: [{ kind: 'warmup', meters: 3000 }, { kind: 'bad' }], paceLow: 285, paceHigh: 290, note: 'descanso 1:00', rationale: 'limiar', method: 'cruiseIntervals' },
    { day: 'quebrado', kind: 'easy', title: 'x' },
  ],
  versions: [
    { number: 2, createdAt: '2026-11-18T10:00:00Z', trigger: { workout: { activityId: 9, day: '2026-11-17' } }, summary: 'ajuste', changes: [{ kind: 'changed', title: 'Terça', before: '10 km', after: '8 km', reason: 'fadiga' }] },
    { number: 1, createdAt: '2026-11-16T10:00:00Z', trigger: { created: {} }, summary: 'novo', changes: [] },
  ],
  strength: [{ id: 'A', weekday: 2, group: 'lower', legLoad: 'heavy', name: 'MMII' }],
  structure: [1, 'easy'],
}

describe('plano do treinador', () => {
  it('lê o JSON do app, ordena e descarta o que está quebrado', () => {
    const plan = parseTrainerPlan(raw)

    expect(plan?.weeks.map((week) => [week.index, week.phase])).toEqual([[1, 'base'], [2, 'build']])
    expect(plan?.workouts.map((item) => item.day)).toEqual(['2026-11-17', '2026-11-18'])
    expect(plan?.workouts[0]).toMatchObject({ steps: [{ kind: 'warmup', repeats: 1, restSeconds: null }], method: 'cruiseIntervals', edited: false })
    expect(plan?.workouts[1]?.edited).toBe(true)
    expect(plan?.versions.map((version) => version.number)).toEqual([1, 2])
    expect(plan?.longMode).toBe('continuous')
    expect(parseTrainerPlan({ weeks: [] })).toBeNull()
    expect(parseTrainerPlan('x')).toBeNull()
  })

  it('traduz o gatilho das versões', () => {
    const versions = parseTrainerPlan(raw)?.versions ?? []

    expect(versions.map((version) => triggerText(version.trigger))).toEqual(['plano criado', 'depois do treino de terça'])
    expect(triggerText({ kind: 'weekEnded', day: null, number: 3 })).toBe('fim da semana 3')
  })

  it('monta a faixa de semanas, a meta e o dia inicial', () => {
    const plan = parseTrainerPlan(raw)
    if (plan === null) throw new Error('plano')

    const cells = weekCells(plan, '2026-11-24')

    expect(cells.map((cell) => [cell.title, cell.kilometers, cell.detail, cell.current, cell.past])).toEqual([
      ['S1 · 16/11', '40 km', 'longão 16', false, true],
      ['S2 · 23/11', '30 km', 'recup. 12', true, false],
      ['17/1', '21,1', 'prova', false, false],
    ])
    expect(goalCaption(plan, '2026-11-24')).toBe('meta 1:39:00 · 8 semanas · versão 2')
    expect(defaultDay(plan, '2026-11-18')).toBe('2026-11-18')
    expect(defaultDay(plan, '2027-02-01')).toBe('2026-11-18')
  })

  it('mostra a força no dia da semana certo', () => {
    const plan = parseTrainerPlan(raw)
    if (plan === null) throw new Error('plano')

    expect(strengthTags(plan, '2026-11-17')).toEqual(['+ MMII'])
    expect(strengthTags(plan, '2026-11-18')).toEqual([])
  })
})

describe('estrutura do treino', () => {
  it('agrupa a série em N× com o bloco e o descanso logo depois', () => {
    const value = workout('threshold', [
      step({ kind: 'warmup', meters: 3000, paceLow: 330, paceHigh: 340 }),
      step({ repeats: 3, meters: 2000, paceLow: 285, paceHigh: 290 }),
      step({ kind: 'recovery', repeats: 2, meters: 0, restSeconds: 120 }),
      step({ kind: 'cooldown', meters: 2000 }),
    ])

    expect(rows(value)).toEqual([
      ['Aquecimento', '3 km · 5:30–5:40/km', false, false],
      ['3×', '', true, false],
      ['Limiar', '2 km · 4:45–4:50/km', false, true],
      ['Descanso parado', '2:00', false, true],
      ['Desaquecimento', '2 km', false, false],
    ])
  })

  it('o descanso de transição igual ao da série some', () => {
    const value = workout('vo2max', [
      step({ repeats: 4, meters: 1000, paceLow: 260, paceHigh: 260 }),
      step({ kind: 'recovery', repeats: 3, meters: 0, restSeconds: 90 }),
      step({ kind: 'recovery', repeats: 1, meters: 0, restSeconds: 90 }),
      step({ kind: 'work', meters: 200, paceLow: 240, paceHigh: 240, method: 'repetition' }),
    ])

    expect(rows(value).map((row) => row[0])).toEqual(['4×', 'VO2 máx', 'Descanso parado', 'Repetição R'])
  })

  it('mantém o descanso de transição quando é diferente, com o nome próprio', () => {
    const value = workout('threshold', [
      step({ repeats: 2, meters: 2000 }),
      step({ kind: 'recovery', repeats: 1, meters: 0, restSeconds: 120 }),
      step({ kind: 'recovery', repeats: 1, meters: 0, restSeconds: 180 }),
      step({ kind: 'work', meters: 1000 }),
    ])

    expect(rows(value).map((row) => row[0])).toEqual(['2×', 'Limiar', 'Descanso parado', 'Descanso antes da próxima série', 'Limiar'])
  })

  it('trote em metros e descanso parado em m:ss', () => {
    const value = workout('vo2max', [step({ kind: 'recovery', repeats: 3, meters: 200 }), step({ kind: 'recovery', meters: 0, restSeconds: 75 })])

    expect(rows(value)).toEqual([
      ['3× Trote', '200 m', false, false],
      ['Descanso parado', '1:15', false, false],
    ])
  })

  it('longão em blocos repete a pausa parada com água e gel', () => {
    const block = step({ kind: 'steady', meters: 4000, paceLow: 340, paceHigh: 340 })
    const pause = step({ kind: 'recovery', meters: 0, restSeconds: 60 })
    const value = workout('long', [block, pause, block, pause, block])

    expect(rows(value)).toEqual([
      ['3×', '', true, false],
      ['Longão', '4 km · 5:40/km', false, true],
      ['Pausa parada · água e gel', '1:00', false, true],
    ])
    expect(rows(workout('long', [block, pause, step({ kind: 'steady', meters: 6000, paceLow: 340, paceHigh: 340 })])).map((row) => row[0])).toEqual(['Longão', 'Pausa parada · água e gel', 'Longão'])
  })
})

describe('linha do dia', () => {
  const plan = { strength: [{ weekday: 3, name: 'Full body' }], longStage: 1 } as unknown as TrainerPlan
  const line = (value: TrainerWorkout) => {
    const result = dayLine(plan, value)
    return [result.title, result.detail, ...result.tags.map((tag) => tag.text)]
  }
  const make = (kind: TrainerWorkout['kind'], totalMeters: number, steps: TrainerStep[], overrides: Partial<TrainerWorkout> = {}): TrainerWorkout => ({
    ...workout(kind, steps), totalMeters, note: 'só se a prontidão ≥ 60', ...overrides,
  })

  it('rodagem mostra só o pace', () => {
    expect(line(make('easy', 10000, [], { paceLow: 290, paceHigh: 304 }))).toEqual(['Rodagem · 10 km', '4:50–5:04/km'])
  })

  it('limiar mostra blocos e pace sem descanso', () => {
    const steps = [step({ kind: 'warmup', meters: 3000 }), step({ repeats: 8, meters: 1000, paceLow: 243, paceHigh: 249 }), step({ kind: 'recovery', repeats: 7, meters: 0, restSeconds: 60 })]
    expect(line(make('threshold', 11000, steps, { paceLow: 243, paceHigh: 249 }))).toEqual(['Limiar · 11 km', '8 × 1 km a 4:03–4:09'])
  })

  it('VO2 com fecho mostra a etiqueta do fecho', () => {
    const steps = [
      step({ kind: 'warmup', meters: 3000 }),
      step({ repeats: 3, meters: 1500, paceLow: 233, paceHigh: 239, method: 'intervals' }),
      step({ kind: 'recovery', repeats: 2, meters: 0, restSeconds: 240 }),
      step({ repeats: 3, meters: 200, paceLow: 219, paceHigh: 225, method: 'repetition' }),
    ]
    expect(line(make('vo2max', 8500, steps, { paceLow: 233, paceHigh: 239 }))).toEqual(['VO2 máx · 8,5 km', '3 × 1,5 km a 3:53–3:59', '+ 3 × 200 m'])
  })

  it('séries diferentes ficam na mesma linha', () => {
    const steps = [step({ repeats: 3, meters: 1500, paceLow: 233, paceHigh: 239 }), step({ kind: 'recovery', repeats: 2, meters: 0, restSeconds: 240 }), step({ repeats: 2, meters: 1000, paceLow: 233, paceHigh: 239 })]
    expect(line(make('vo2max', 10500, steps, { paceLow: 233, paceHigh: 239 }))[1]).toBe('3 × 1,5 km + 2 × 1 km a 3:53–3:59')
  })

  it('longão contínuo mostra só o pace', () => {
    expect(line(make('long', 21000, [step({ kind: 'steady', meters: 21000 })], { paceLow: 268, paceHigh: 282 }))).toEqual(['Longão · 21 km', '4:28–4:42/km'])
  })

  it('longão em blocos mostra blocos, etapa e editado', () => {
    const steps: TrainerStep[] = []
    for (let index = 0; index < 4; index += 1) {
      steps.push(step({ kind: 'steady', meters: 2000, paceLow: 273, paceHigh: 287 }), step({ kind: 'steady', meters: 2000, paceLow: 268, paceHigh: 282 }), step({ kind: 'recovery', meters: 0, restSeconds: 60 }))
    }
    steps.push(step({ kind: 'steady', meters: 5000, paceLow: 268, paceHigh: 282 }))
    expect(line(make('long', 21000, steps, { edited: true }))).toEqual(['Longão · 21 km', '4 × 4 km + 5 km a 4:28–4:47', 'etapa 1 de 6', 'editado'])
  })

  it('listagem mostra só o tipo: média-longa, fartlek e limiar progressivo sem subtipo', () => {
    expect(line(make('easy', 14000, [], { paceLow: 290, paceHigh: 304, variant: 'mediumLong', title: 'Média-longa 14 km' }))[0]).toBe('Média-longa · 14 km')
    expect(line(make('optionalEasy', 9000, [], { paceLow: 290, paceHigh: 304, variant: 'fartlek', title: 'Fartlek 6 × 500 m' })).slice(0, 3)).toEqual(['Fartlek · 9 km', '4:50–5:04/km', 'opcional'])
    const blocks = [0, 1, 2].map((index) => step({ meters: 2000, paceLow: 250 - 5 * index, paceHigh: 256 - 5 * index }))
    expect(line(make('threshold', 9000, blocks, { paceLow: 240, paceHigh: 256, variant: 'progressiveThreshold' })).slice(0, 2)).toEqual(['Limiar · 9 km', '3 × 2 km a 4:00–4:16'])
    expect(rows(make('vo2max', 6000, [step({ repeats: 8, meters: 200, method: 'intervals' })], { variant: 'hills' }))[0]?.[0]).toBe('8× Subida')
  })

  it('lê a variante do JSON e ignora variante desconhecida', () => {
    const plan = parseTrainerPlan({ ...raw, workouts: [{ ...raw.workouts[0], variant: 'mediumLong' }, { ...raw.workouts[1], variant: 'nova' }] })
    expect(plan?.workouts.map((item) => item.variant)).toEqual([null, 'mediumLong'])
  })

  it('rodagem opcional com força e folga', () => {
    expect(line(make('optionalEasy', 7000, [], { day: '2026-11-18', paceLow: 290, paceHigh: 304 }))).toEqual(['Rodagem · 7 km', '4:50–5:04/km', 'opcional', '+ Full body'])
    expect(line(make('off', 0, [], { day: '2026-11-18', edited: true }))).toEqual(['Folga', '', '+ Full body'])
  })
})
