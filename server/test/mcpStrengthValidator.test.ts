import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { catalogExercise, parseResponse, validateResponse } from '../src/mcp/strengthValidator.js'
import type { StrengthContext, StrengthResponse } from '../src/mcp/strengthTypes.js'

const catalog = JSON.parse(readFileSync(new URL('./fixtures/strength-catalog.json', import.meta.url), 'utf8')) as string[]

function context(overrides: Partial<StrengthContext> = {}): StrengthContext {
  return {
    periodo: { inicio: '2026-11-23', fim: '2026-11-29', hoje: '2026-11-22' },
    prova: null,
    dias_do_treinador: [
      { dia_da_semana: 'ter', foco: 'core', intensidade: 'light', minutos: 25, local: 'home' },
      { dia_da_semana: 'qui', foco: 'lower', intensidade: 'heavy', minutos: 45, local: 'gym' },
    ],
    mfit: [{ dia_da_semana: 'seg', padroes: [] }, { dia_da_semana: 'qua', padroes: [] }, { dia_da_semana: 'sex', padroes: [] }],
    corrida: [],
    prontidao: [],
    dor: [],
    ultimas_cargas_kg: {},
    catalogo: catalog,
    regras: [],
    ...overrides,
  }
}

const mobility = [
  { id: 'WARM_UP/STRETCH_90_90', series: 2, reps: 8, descanso: 15 },
  { id: 'BANDED_EXERCISES/AB_TWIST', series: 3, reps: 10, descanso: 30 },
  { id: 'PLANK/SIDE_PLANK', series: 3, segundos: 30, descanso: 30 },
  { id: 'HIP_STABILITY/DEAD_BUG', series: 3, reps: 10, descanso: 30 },
  { id: 'WARM_UP/ANKLE_DORSIFLEXION_WITH_BAND', series: 2, reps: 8, descanso: 15 },
  { id: 'WARM_UP/OPPOSITE_ARM_AND_LEG_BALANCE', series: 3, reps: 10, descanso: 30 },
]

function response(treinos: StrengthResponse['treinos']): StrengthResponse {
  return { versao: 1, autor: 'claude', resumo: 'Semana leve', treinos }
}

const day = (dia: string, exercicios: StrengthResponse['treinos'][number]['exercicios'], foco = 'core', minutos = 25, local = 'home') => ({ dia, foco, minutos, local, porque: 'motivo', exercicios })

describe('validador de força (paridade com ClaudeStrengthTests.swift)', () => {
  it('lê JSON dentro de bloco de código e recusa versão desconhecida', () => {
    const parsed = parseResponse('Aqui:\n```json\n' + JSON.stringify(response([day('2026-11-24', mobility)])) + '\n```')
    expect('error' in parsed).toBe(false)
    expect(parseResponse('{ "versao": 2, "treinos": [] }')).toEqual({ error: 'unsupported_version', version: 2 })
    expect(parseResponse('sem json')).toEqual({ error: 'invalid' })
  })

  it('dia válido passa', () => {
    const [report] = validateResponse(response([day('2026-11-24', mobility)]), context())
    expect(report?.erros).toEqual([])
  })

  it('dia de mobilidade com foco mobility passa', () => {
    const ctx = context({ dias_do_treinador: [{ dia_da_semana: 'ter', foco: 'mobility', intensidade: 'light', minutos: 25, local: 'home' }] })
    const [report] = validateResponse(response([day('2026-11-24', mobility, 'mobility')]), ctx)
    expect(report?.erros).toEqual([])
  })

  it('recusa foco desconhecido', () => {
    const [report] = validateResponse(response([day('2026-11-24', mobility, 'yoga')]), context())
    expect(report?.erros).toContain('foco "yoga" inválido; use upper, lower, fullBody, core ou mobility')
  })

  it('recusa dias que não são do treinador', () => {
    const reports = validateResponse(response([day('2026-11-22', mobility), day('2026-12-03', mobility), day('2026-11-25', mobility), day('2026-11-28', mobility)]), context())
    expect(reports.map((item) => item.erros[0])).toEqual(['dia que já passou', 'fora do período pedido', 'dia do MFIT, não será aplicado', 'não é um dia de força do treinador'])
  })

  it('aceita dia do MFIT só com substitui_mfit', () => {
    const entry = { ...day('2026-11-25', mobility), substitui_mfit: true }
    const [report] = validateResponse(response([entry]), context())
    expect(report?.erros).toEqual([])
    expect(report?.avisos).toContain('substitui o treino do MFIT neste dia')
  })

  it('recusa exercício fora do catálogo, do local ou com dor', () => {
    const exercises = [
      { id: 'panturrilha-salto', series: 3, reps: 10, descanso: 30 },
      { id: 'SQUAT/BARBELL_BACK_SQUAT', series: 3, reps: 8, descanso: 90 },
      { id: 'CALF_RAISE/SINGLE_LEG_STANDING_CALF_RAISE', series: 3, reps: 12, descanso: 45 },
    ]
    const [report] = validateResponse(response([day('2026-11-24', exercises)]), context({ dor: ['calfAchilles'] }))
    expect(report?.erros).toEqual(expect.arrayContaining(['"panturrilha-salto" não existe no catálogo', '"SQUAT/BARBELL_BACK_SQUAT" não cabe no local do dia', '"CALF_RAISE/SINGLE_LEG_STANDING_CALF_RAISE" carrega uma região com dor marcada']))
  })

  it('recusa doses fora da faixa', () => {
    const exercises = [
      { id: 'HIP_STABILITY/DEAD_BUG', series: 9, reps: 10, descanso: 30 },
      { id: 'PLANK/PLANK', series: 3, descanso: 30 },
      { id: 'WARM_UP/OPPOSITE_ARM_AND_LEG_BALANCE', series: 3, reps: 10, descanso: 600 },
    ]
    const [report] = validateResponse(response([day('2026-11-24', exercises)]), context())
    expect(report?.erros.filter((issue) => issue.includes('fora da faixa'))).toHaveLength(3)
  })

  it('recusa perna pesada antes de qualidade e perto da prova', () => {
    const legs = [
      { id: 'SQUAT/BARBELL_BACK_SQUAT', series: 4, reps: 6, descanso: 150 },
      { id: 'DEADLIFT/ROMANIAN_DEADLIFT', series: 3, reps: 8, descanso: 120 },
      { id: 'LUNGE/DUMBBELL_BULGARIAN_SPLIT_SQUAT', series: 3, reps: 8, descanso: 90 },
      { id: 'CALF_RAISE/STANDING_CALF_RAISE', series: 3, reps: 12, descanso: 60 },
    ]
    const entry = day('2026-11-26', legs, 'lower', 45, 'gym')
    const [quality] = validateResponse(response([entry]), context({ corrida: [{ dia: '2026-11-28', tipo: 'long', nome: 'Longão' }] }))
    expect(quality?.erros).toContain('perna pesada nas 48 h antes de limiar, VO2 ou longão')
    const [race] = validateResponse(response([entry]), context({ prova: { nome: 'Meia', dia: '2026-11-28' } }))
    expect(race?.erros).toContain('força nos 3 dias antes da prova')
  })

  it('avisa duração e salto de carga', () => {
    const [report] = validateResponse(
      response([day('2026-11-26', [{ id: 'SQUAT/BARBELL_BACK_SQUAT', series: 4, reps: 6, descanso: 150, kg: 70 }], 'lower', 45, 'gym')]),
      context({ ultimas_cargas_kg: { 'SQUAT/BARBELL_BACK_SQUAT': 60 } }),
    )
    expect(report?.erros).toEqual([])
    expect(report?.avisos).toEqual(expect.arrayContaining(['carga de "SQUAT/BARBELL_BACK_SQUAT" mais de 5% acima da última']))
    expect(report?.avisos.some((issue) => issue.includes('min estimados'))).toBe(true)
  })

  it('aceita o catálogo em objetos, como mandam as versões antigas do app', () => {
    const legacy = [{ id: 'dead-bug', nome: 'Dead bug', padrao: 'antiExtension', equipamento: 'bodyweight', regioes: [], focos: ['core'], unilateral: false, isometria: false }]
    const [report] = validateResponse(response([day('2026-11-24', [{ id: 'dead-bug', series: 3, reps: 10, descanso: 30 }])]), context({ catalogo: legacy }))
    expect(report?.erros).not.toContain('"dead-bug" não existe no catálogo')
  })

  it('lê a linha compacta do catálogo', () => {
    expect(catalogExercise('PLANK/SIDE_PLANK|lateralCore|bodyweight||core,fullBody|ui')).toEqual({
      id: 'PLANK/SIDE_PLANK', padrao: 'lateralCore', equipamento: 'bodyweight', regioes: [], focos: ['core', 'fullBody'], unilateral: true, isometria: true,
    })
    expect(catalogExercise('quebrada')).toBeNull()
  })
})
