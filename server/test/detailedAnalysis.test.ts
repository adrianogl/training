import { describe, expect, it } from 'vitest'
import { detailedAnalysis } from '../src/analysis/detailedAnalysis.js'
import { classify, fadeKilometer, heartRateDrift } from '../src/analysis/detailedMetrics.js'
import type { KilometerPoint } from '../src/analysis/detailedTypes.js'
import type { FitSummary } from '../src/fit/fitTypes.js'
import { currentSpec, scenarioInput, scenarioRun } from './detailedScenario.js'

const points = (paces: number[], heartRate: number | null = null): KilometerPoint[] => paces.map((paceSeconds, index) => ({ km: index + 1, paceSeconds, levelPace: paceSeconds, climb: 0, descent: 0, heartRate }))

describe('análise detalhada: longão de 20 km feito até 12,66 km', () => {
  const result = detailedAnalysis(scenarioInput())

  it('classifica como longão e monta os km com pace estável e queda depois do km 9', () => {
    expect(result.kind).toBe('long')
    expect(result.splits).toHaveLength(12)
    expect(result.splits.slice(0, 9).every((point) => point.paceSeconds === 271)).toBe(true)
    expect(result.splits.slice(9).map((point) => point.paceSeconds)).toEqual([283, 291, 299])
    expect(result.splits[0]?.heartRate).toBe(159)
    expect(result.splits[11]?.heartRate).toBe(170)
    expect(result.fadeKm).toBe(10)
  })

  it('calcula os KPIs contra a média dos 8 parecidos', () => {
    expect(result.kpis.completion).toEqual({ value: 63.3, similarAverage: 85.2 })
    expect(result.kpis.fadeKm).toEqual({ value: 10, similarAverage: 9.3 })
    expect(result.kpis.hrDrift).toEqual({ value: 7.5, similarAverage: 6 })
  })

  it('lista só os 8 parecidos dentro de 90 dias, em ordem de data, sem o próprio treino', () => {
    expect(result.similar.map((item) => item.activityId)).toEqual([11, 12, 13, 14, 15, 16, 17, 18])
    expect(result.similar[1]).toEqual({ activityId: 12, day: '2026-09-05', completion: 70, fadeKm: 9, complete: false, noPauses: true })
    expect(result.similar[3]?.completion).toBe(94.1)
    expect(result.similar[6]?.complete).toBe(true)
  })

  it('gera de 3 a 5 achados na ordem da especificação, só com dados', () => {
    expect(result.findings.map((finding) => finding.key)).toEqual(['completion', 'fadeKm', 'hrDrift', 'startPace', 'readiness'])
    expect(result.findings[0]?.values).toEqual({ doneKm: 12.66, referenceKm: 20, percent: 63.3, source: 'plan', similarAverage: 85.2 })
    expect(result.findings[1]?.values).toEqual({ fadeKm: 10, similarMedian: 9, similarFaded: 3, similarTotal: 8 })
    expect(result.findings[3]?.values).toEqual({ todayStart: 271, limitPace: 275, fastTotal: 5, fastEarlyFade: 2, slowTotal: 3, slowEarlyFade: 0, earlyFadeKm: 10 })
    expect(result.findings[4]?.values).toEqual({ today: 55, limit: 60, lowAverage: 62.5, lowCount: 3, highAverage: 100, highCount: 3 })
  })

  it('recomenda gel antes da queda, trocar o dia com prontidão baixa e aliviar a semana', () => {
    expect(result.recommendations).toEqual([
      { key: 'gel', value: 9 },
      { key: 'swapDay', value: 55 },
      { key: 'easeWeek', value: 140 },
    ])
  })

  it('recomenda o pace dos primeiros 5 km quando a queda vem antes do km 10 depois de um início mais rápido', () => {
    const input = scenarioInput()
    input.current = scenarioRun({ ...currentSpec, paces: [262, 262, 262, 262, 262, 262, 262, 280, 290, 296], tailMeters: 0 })
    const rules = detailedAnalysis(input).recommendations
    expect(rules[0]).toEqual({ key: 'startPace', value: 275 })
    expect(rules[1]).toEqual({ key: 'gel', value: 7 })
  })

  it('cita a semana pesada e os tiros nos 7 dias anteriores quando o achado cabe', () => {
    const input = scenarioInput()
    input.days = []
    const week = detailedAnalysis(input).findings.find((finding) => finding.key === 'weekLoad')
    expect(week?.values).toEqual({ weekKm: 30, averageKm: 12.5, percent: 140, hadIntervals: true })
  })

  it('lista as fontes usadas', () => {
    expect(result.sources).toEqual([
      { key: 'fit', count: 12 },
      { key: 'plan', count: 1 },
      { key: 'similar', count: 8 },
      { key: 'readiness', count: 7 },
      { key: 'goal', count: 1 },
    ])
  })
})

describe('classificação do treino', () => {
  const base = scenarioRun({ ...currentSpec, name: 'Corrida', plannedMeters: null })
  const withFit = (change: (fit: FitSummary) => void) => {
    const fit = structuredClone(base.fit as FitSummary)
    change(fit)
    return { activity: base.activity, fit }
  }

  it('planejado com repetição vence o nome', () => {
    const run = withFit((fit) => {
      fit.structure.prescription = { name: null, description: null, steps: [{ index: 0, intensity: 'active', duration: { kind: 'distance', meters: 1000 }, target: { kind: 'open' } }, { index: 1, intensity: 'active', duration: { kind: 'repeatSteps', fromIndex: 0, count: 5 }, target: { kind: 'open' } }] }
    })
    expect(classify({ ...run, activity: { ...run.activity, name: 'Longão' } })).toBe('intervals')
  })

  it('usa o nome sem acento antes da zona e da distância', () => {
    expect(classify({ ...base, activity: { ...base.activity, name: 'Longão de domingo' } })).toBe('long')
    expect(classify({ ...base, activity: { ...base.activity, name: 'Tiros na pista' } })).toBe('intervals')
    expect(classify({ ...base, activity: { ...base.activity, name: 'Ritmo 10k' } })).toBe('tempo')
    expect(classify({ ...base, activity: { ...base.activity, name: 'Prova 10k' } })).toBe('race')
    expect(classify({ ...base, activity: { ...base.activity, name: 'Rodagem leve', distanceMeters: 20_000 } })).toBe('easy')
  })

  it('sem nome útil, zona 4 ou mais com metade do tempo é ritmo; senão a distância decide', () => {
    expect(classify({ ...base, activity: { ...base.activity, zoneSeconds: [0, 100, 200, 900, 400] } })).toBe('tempo')
    expect(classify({ ...base, activity: { ...base.activity, distanceMeters: 16_000 } })).toBe('long')
    expect(classify({ ...base, activity: { ...base.activity, distanceMeters: 8000 } })).toBe('easy')
  })
})

describe('queda de pace e deriva da FC', () => {
  it('exige 8 s/km acima da mediana anterior e o km seguinte ainda 4 s/km acima, a partir do km 3', () => {
    expect(fadeKilometer(points([270, 270, 270, 270, 279, 280, 290]))).toBe(5)
    expect(fadeKilometer(points([270, 270, 270, 270, 279, 270, 290, 270]))).toBeNull()
    expect(fadeKilometer(points([270, 290, 292, 270, 270]))).toBeNull()
    expect(fadeKilometer(points([270, 270, 270, 270, 270, 290]))).toBe(6)
    expect(fadeKilometer(points([270, 270, 270, 270, 280, 275, 270]))).toBe(5)
    expect(fadeKilometer(points([270, 270, 270, 270, 280, 273, 270]))).toBeNull()
  })

  it('compara a velocidade por batimento da segunda metade com a da primeira', () => {
    expect(heartRateDrift(points([300, 300, 300, 300, 300], 150))).toBe(0)
    const drift = heartRateDrift([{ km: 1, paceSeconds: 300, levelPace: 300, climb: 0, descent: 0, heartRate: 130 }, { km: 2, paceSeconds: 300, levelPace: 300, climb: 0, descent: 0, heartRate: 150 }, { km: 3, paceSeconds: 300, levelPace: 300, climb: 0, descent: 0, heartRate: 150 }, { km: 4, paceSeconds: 300, levelPace: 300, climb: 0, descent: 0, heartRate: 165 }, { km: 5, paceSeconds: 300, levelPace: 300, climb: 0, descent: 0, heartRate: 165 }])
    expect(drift).toBe(9.1)
    expect(heartRateDrift(points([300, 300, 300, 300], 150))).toBeNull()
  })
})

describe('sem plano e sem parecidos', () => {
  it('compara com a mediana dos parecidos quando a prescrição não existe', () => {
    const input = scenarioInput()
    input.current = scenarioRun({ ...currentSpec, plannedMeters: null })
    const result = detailedAnalysis(input)
    expect(result.findings[0]?.values.source).toBe('similar')
    expect(result.findings[0]?.values.referenceKm).toBe(17)
    expect(result.sources.some((source) => source.key === 'plan')).toBe(false)
  })

  it('devolve o que existe quando não há parecidos', () => {
    const input = scenarioInput()
    input.runs = []
    input.days = []
    const result = detailedAnalysis(input)
    expect(result.similar).toEqual([])
    expect(result.kpis.completion).toEqual({ value: 63.3, similarAverage: null })
    expect(result.findings.map((finding) => finding.key)).toEqual(['completion', 'fadeKm', 'hrDrift', 'pauses', 'goal'])
    expect(result.findings[3]?.values).toEqual({ pauses: 0, longestContinuousKm: 12.66, totalKm: 12.66 })
    expect(result.findings[4]?.values).toEqual({ kind: 'continuousLong', targetKm: 16, targetPace: 290, continuousKm: 12.66, pace: 277.2, met: false })
  })
})
