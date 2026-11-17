import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { parseResponse, validateResponse } from '../src/mcp/strengthValidator.js'
import type { ContextExercise, StrengthContext, StrengthResponse } from '../src/mcp/strengthTypes.js'

const catalog = JSON.parse(readFileSync(new URL('./fixtures/strength-catalog.json', import.meta.url), 'utf8')) as ContextExercise[]

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
  { id: 'mobilidade-90-90', series: 2, reps: 8, descanso: 15 },
  { id: 'pallof-elastico', series: 3, reps: 10, descanso: 30 },
  { id: 'prancha-lateral', series: 3, segundos: 30, descanso: 30 },
  { id: 'dead-bug', series: 3, reps: 10, descanso: 30 },
  { id: 'mobilidade-tornozelo', series: 2, reps: 8, descanso: 15 },
  { id: 'passaro-cao', series: 3, reps: 10, descanso: 30 },
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

  it('recusa dias que não são do treinador', () => {
    const reports = validateResponse(response([day('2026-11-22', mobility), day('2026-12-03', mobility), day('2026-11-25', mobility), day('2026-11-28', mobility)]), context())
    expect(reports.map((item) => item.erros[0])).toEqual(['dia que já passou', 'fora do período pedido', 'dia do MFIT, não será aplicado', 'não é um dia de força do treinador'])
  })

  it('recusa exercício fora do catálogo, do local ou com dor', () => {
    const exercises = [
      { id: 'panturrilha-salto', series: 3, reps: 10, descanso: 30 },
      { id: 'agachamento-livre', series: 3, reps: 8, descanso: 90 },
      { id: 'panturrilha-degrau', series: 3, reps: 12, descanso: 45 },
    ]
    const [report] = validateResponse(response([day('2026-11-24', exercises)]), context({ dor: ['calfAchilles'] }))
    expect(report?.erros).toEqual(expect.arrayContaining(['"panturrilha-salto" não existe no catálogo', '"agachamento-livre" não cabe no local do dia', '"panturrilha-degrau" carrega uma região com dor marcada']))
  })

  it('recusa doses fora da faixa', () => {
    const exercises = [
      { id: 'dead-bug', series: 9, reps: 10, descanso: 30 },
      { id: 'prancha', series: 3, descanso: 30 },
      { id: 'passaro-cao', series: 3, reps: 10, descanso: 600 },
    ]
    const [report] = validateResponse(response([day('2026-11-24', exercises)]), context())
    expect(report?.erros.filter((issue) => issue.includes('fora da faixa'))).toHaveLength(3)
  })

  it('recusa perna pesada antes de qualidade e perto da prova', () => {
    const legs = [
      { id: 'agachamento-livre', series: 4, reps: 6, descanso: 150 },
      { id: 'terra-romeno', series: 3, reps: 8, descanso: 120 },
      { id: 'bulgaro-halteres', series: 3, reps: 8, descanso: 90 },
      { id: 'panturrilha-em-pe', series: 3, reps: 12, descanso: 60 },
    ]
    const entry = day('2026-11-26', legs, 'lower', 45, 'gym')
    const [quality] = validateResponse(response([entry]), context({ corrida: [{ dia: '2026-11-28', tipo: 'long', nome: 'Longão' }] }))
    expect(quality?.erros).toContain('perna pesada nas 48 h antes de limiar, VO2 ou longão')
    const [race] = validateResponse(response([entry]), context({ prova: { nome: 'Meia', dia: '2026-11-28' } }))
    expect(race?.erros).toContain('força nos 3 dias antes da prova')
  })

  it('avisa duração e salto de carga', () => {
    const [report] = validateResponse(
      response([day('2026-11-26', [{ id: 'agachamento-livre', series: 4, reps: 6, descanso: 150, kg: 70 }], 'lower', 45, 'gym')]),
      context({ ultimas_cargas_kg: { 'agachamento-livre': 60 } }),
    )
    expect(report?.erros).toEqual([])
    expect(report?.avisos).toEqual(expect.arrayContaining(['carga de "agachamento-livre" mais de 5% acima da última']))
    expect(report?.avisos.some((issue) => issue.includes('min estimados'))).toBe(true)
  })
})
