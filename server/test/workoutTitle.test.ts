import { describe, expect, it } from 'vitest'
import { comparisonCandidates } from '../src/analysis/workoutAnalysis.js'
import { comparisonKey } from '../src/analysis/workoutTitle.js'

const run = (id: number, name: string, day: string, workoutId: number | null) => ({
  id,
  name,
  day,
  startLocal: `${day}T06:00:00`,
  distanceMeters: 10_000,
  workoutId,
  type: 'running',
})

describe('comparisonKey', () => {
  it('ignora o dia da semana e a data', () => {
    expect(comparisonKey('Corrida Corrida fácil seg 16/11')).toBe('corrida fácil')
    expect(comparisonKey('Corrida Longo sáb 15/11')).toBe(comparisonKey('Corrida Longo dom 03/05'))
  })

  it('tira o dia da semana cortado pelo limite do nome', () => {
    expect(comparisonKey('Corrida Ritmo de maratona ter 26')).toBe('corrida ritmo de maratona')
    expect(comparisonKey('Corrida Ritmo de meia maratona t')).toBe('corrida ritmo de meia maratona')
  })

  it('mantém treinos diferentes separados', () => {
    expect(comparisonKey('Corrida Ritmo de prova 10 Km qua')).toBe('corrida ritmo de prova 10 km')
    expect(comparisonKey('Corrida Longo sáb 15/11')).not.toBe(comparisonKey('Corrida Corrida fácil seg 16/11'))
  })
})

describe('comparisonCandidates', () => {
  it('compara treinos planejados com o mesmo nome em dias diferentes', () => {
    const current = run(3, 'Corrida fácil seg 16/11', '2026-11-16', 30)
    const all = [current, run(2, 'Corrida fácil qua 11/11', '2026-11-11', 20), run(1, 'Longo sáb 14/11', '2026-11-14', 10)]
    expect(comparisonCandidates(current, all, () => true).map((item) => item.id)).toEqual([2])
  })
})
