import { describe, expect, it } from 'vitest'
import type { BlockStatus, Finding, FindingKind, WorkoutBlock } from '../src/analysis/analysisTypes.js'
import { evolutionText, findingEvidence, findingText, findingWhy, narrate } from '../src/analysis/narrative.js'
import { NARRATIVE } from '../src/analysis/narrativeConstants.js'
import { block, distance, speed, step } from './analysisHelpers.js'

const f = (group: Finding['group'], kind: FindingKind, blockOrdinal: number | null, facts: Record<string, number>): Finding => ({ group, kind, blockOrdinal, facts })

describe('texto da avaliação (paridade com NarratorTests, template)', () => {
  const blocks: WorkoutBlock[] = [
    block({ kind: 'warmup', ordinal: 0, label: 'Aquecimento', seconds: 360, distance: 1000, avgSpeed: 1000 / 360, avgHeartRate: 130, maxHeartRate: 136, dominantZone: 2 }),
    block({ ordinal: 1, label: 'Tiro 1', seconds: 245, distance: 1000, avgSpeed: 1000 / 245, avgHeartRate: 168, maxHeartRate: 174, dominantZone: 4, status: 'slower' }),
    block({ ordinal: 2, label: 'Recuperação 1', seconds: 245, distance: 1000, avgSpeed: 1000 / 245, avgHeartRate: 168, maxHeartRate: 174, dominantZone: 4, status: 'inTarget' }),
  ]

  it('cobre todos os tipos com os números dos fatos', () => {
    const cases: [Finding, string][] = [
      [f('positive', 'blockInTarget', null, { inTarget: 5, total: 6 }), '5 de 6'],
      [f('positive', 'steadyPace', 1, { spread: 4 }), '4 s/km'],
      [f('positive', 'lowerHeartRateThanBefore', 1, { delta: 5 }), '5 bpm'],
      [f('positive', 'goodRecovery', 2, { drop: 31 }), '31 bpm'],
      [f('negative', 'blockOffTarget', 1, { speed: 1000 / 245, targetLow: 1000 / 250, targetHigh: 1000 / 240 }), '4:05 /km'],
      [f('negative', 'stepIncomplete', 1, { distance: 800, seconds: 200, targetDistance: 1000 }), '800 m'],
      [f('negative', 'paceFade', 1, { fade: 9 }), '9 s/km'],
      [f('attention', 'cardiacDrift', 1, { rise: 0.06, fromHR: 150, toHR: 159 }), '159 bpm'],
      [f('attention', 'zoneAboveTarget', 0, { zone: 3 }), 'Z3'],
      [f('attention', 'hardOnLowReadiness', null, { readiness: 42 }), '42'],
      [f('attention', 'highAcuteChronic', null, { ratio: 1.62 }), '1,62'],
    ]
    expect(new Set(cases.map(([finding]) => finding.kind)).size).toBe(11)
    for (const [finding, number] of cases) expect(findingText(finding, blocks)).toContain(number)
    const off = findingText(cases[4]![0], blocks)
    expect(off).toContain('Tiro 1')
    expect(off).toContain('mais lento que o prescrito')
    expect(off).toContain('4:00–4:10')
  })

  it('mantém a ordem dos achados e escreve a evolução', () => {
    const narrated = narrate({ positives: [f('positive', 'blockInTarget', null, { inTarget: 2, total: 3 })], negatives: [f('negative', 'paceFade', 1, { fade: 9 })], attention: [] }, blocks)
    expect(narrated).toHaveLength(2)
    expect(narrated[0]?.text).toContain('2 de 3')
    expect(narrated[1]?.text).toContain('9 s/km')
    expect(evolutionText({ paceDelta: -5, heartRateDelta: 0.4, oldestDate: '1 de nov.' })).toBe('5 s/km mais rápido, FC igual, em relação a 1 de nov.')
    expect(evolutionText({ paceDelta: 0.3, heartRateDelta: null, oldestDate: '3 de out' })).toBe('Mesmo pace em relação a 3 de out.')
    expect(evolutionText({ paceDelta: 4, heartRateDelta: -3, oldestDate: 'x' })).toBe('4 s/km mais lento, FC 3 bpm menor, em relação a x.')
  })
})

describe('evidência e porquê (paridade com FindingDetailTests)', () => {
  const active = (ordinal: number, label: string, status: BlockStatus, seconds = 240) =>
    block({ ordinal, label, status, seconds, distance: 1000, avgSpeed: 1000 / seconds, avgHeartRate: 172, maxHeartRate: 178, dominantZone: 5, prescribed: step(ordinal, 'active', distance(1000), speed(1000 / 245, 1000 / 235)) })
  const recovery = (ordinal: number, heartRate: number) => block({ kind: 'recovery', ordinal, label: `Recuperação ${ordinal}`, seconds: 120, distance: 300, avgSpeed: 2.5, avgHeartRate: heartRate, maxHeartRate: heartRate + 6, dominantZone: 3 })
  const blocks = [active(0, 'Tiro 1', 'inTarget', 238), recovery(1, 140), active(2, 'Tiro 2', 'inTarget', 241), recovery(3, 146), active(4, 'Tiro 3', 'slower', 248)]

  it('blocos no alvo listam os paces', () => {
    const finding = f('positive', 'blockInTarget', null, { inTarget: 2, total: 3 })
    expect(findingEvidence(finding, blocks)).toBe('3:58 · 4:01 /km')
    expect(findingWhy(finding, blocks)).toBe(NARRATIVE.why.someInTarget)
  })

  it('bloco lento depois da recuperação mais alta explica o cansaço', () => {
    const finding = f('negative', 'blockOffTarget', 4, { speed: 1000 / 248, heartRate: 172, targetLow: 1000 / 245, targetHigh: 1000 / 235, recoveryHeartRate: 146, recoveryHighest: 1 })
    expect(findingEvidence(finding, blocks)).toBe('4:08 /km · alvo 3:55–4:05 /km · FC 172 bpm')
    expect(findingWhy(finding, blocks)).toContain('146 bpm')
    expect(findingWhy(finding, blocks)).toContain('a mais alta do treino')
  })

  it('todo tipo tem porquê e a evidência usa os fatos', () => {
    const cases: [Finding, string][] = [
      [f('positive', 'steadyPace', 0, { spread: 4, fastestPace: 298, slowestPace: 302 }), 'voltas de 4:58 a 5:02 /km'],
      [f('positive', 'lowerHeartRateThanBefore', 0, { delta: 4, heartRate: 171, beforeHeartRate: 175, speed: 1000 / 241 }), '171 bpm vs. 175 bpm · 4:01 /km'],
      [f('positive', 'goodRecovery', 1, { drop: 38, peak: 178, recovered: 140 }), 'pico 178 bpm → média 140 bpm'],
      [f('negative', 'stepIncomplete', 4, { distance: 800, seconds: 200, targetDistance: 1000 }), 'feito 800 m de 1,00 km'],
      [f('negative', 'paceFade', 0, { fade: 9, lastPace: 317, medianPace: 308 }), 'última volta 5:17 · mediana 5:08 /km'],
      [f('attention', 'cardiacDrift', 0, { rise: 0.06, fromHR: 150, toHR: 159 }), 'FC 150 → 159 bpm · +6%'],
      [f('attention', 'zoneAboveTarget', 1, { zone: 3, speed: 2.5, heartRate: 146 }), '6:40 /km · FC 146 bpm'],
      [f('attention', 'hardOnLowReadiness', null, { readiness: 42 }), 'prontidão 42 de 100 · limite 50'],
      [f('attention', 'highAcuteChronic', null, { ratio: 1.62 }), 'razão 1,62 · limite 1,50'],
    ]
    for (const [finding, evidence] of cases) {
      expect(findingEvidence(finding, blocks)).toBe(evidence)
      expect(findingWhy(finding, blocks)).not.toBe('')
    }
    expect(findingEvidence(f('positive', 'steadyPace', 0, { spread: 4 }), blocks)).toBeNull()
  })
})
