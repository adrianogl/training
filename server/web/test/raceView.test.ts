import { describe, expect, it } from 'vitest'
import { kmNumber, paceClock, parseClock } from '../src/format'
import { checklistLine, distanceText, parseDistance, stretches } from '../src/raceView'
import type { KmPlan } from '../src/types'

const km = (index: number, pace: number, label: string, manual = false): KmPlan => ({ index, pace, grade: 0, label, manual })

describe('provas no site', () => {
  it('lê meta e distância digitadas', () => {
    expect([parseClock('1:39:00'), parseClock('45:00'), parseClock('45'), parseClock('1:61:00'), parseClock('0:00')]).toEqual([5940, 2700, null, null, null])
    expect([parseDistance('21,1'), parseDistance('42 km'), parseDistance('15,5'), parseDistance('x')]).toEqual([21097.5, 42195, 15500, null])
    expect([distanceText(21097.5), distanceText(10000), distanceText(15500)]).toEqual(['21,1', '10', '15,5'])
    expect([paceClock(286.4), kmNumber(21.1), kmNumber(10)]).toEqual(['4:46', '21,1', '10'])
  })

  it('agrupa a estratégia em trechos com a passagem acumulada', () => {
    const plan = [km(0, 290, 'aquece'), km(1, 290, 'aquece'), km(2, 280, 'plano'), km(3, 280, 'plano'), km(4, 270, 'final')]
    const list = stretches(plan, 4500)
    expect(list.map((item) => [item.from, item.to, item.label])).toEqual([[1, 2, 'aquecimento'], [3, 4, ''], [5, 5, 'final']])
    expect(list.at(-1)?.split).toBeCloseTo(290 * 2 + 280 * 2 + 270 * 0.5, 6)
    expect(stretches(plan, 4500, 1.1)[0]?.pace).toBeCloseTo(319, 6)
  })

  it('pace manual vira trecho próprio', () => {
    const list = stretches([km(0, 280, 'plano'), km(1, 300, 'plano', true), km(2, 280, 'plano')], 3000)
    expect(list).toHaveLength(3)
  })

  it('textos do checklist', () => {
    expect(checklistLine({ kind: 'racePace', status: 'ok', targetKm: 15, doneKm: 16, pace: 281 })).toEqual({ title: 'Treino no pace de prova', detail: '16 km a 4:41/km no bloco. Alvo: 15 km.' })
    expect(checklistLine({ kind: 'course', status: 'missing', km: null, gain: null }).detail).toMatch(/Sem percurso/)
  })
})
