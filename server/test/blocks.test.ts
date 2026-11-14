import { describe, expect, it } from 'vitest'
import type { BlockStatus, HeartRateZones } from '../src/analysis/analysisTypes.js'
import { buildBlocks, hasPrescription } from '../src/analysis/blocks.js'
import type { StepTarget } from '../src/fit/fitTypes.js'
import { bpm, distance, hrZone, lap, laps, open, openDuration, percentMax, repeat, singleStep, speed, step, structure, time, zones, type Plan } from './analysisHelpers.js'

const range = (n: number, prefix: string) => Array.from({ length: n }, (_, i) => `${prefix} ${i + 1}`)

describe('blocos (paridade com BlocksTests)', () => {
  it('agrupa voltas por passo', () => {
    const steps = [step(0, 'warmup', distance(3000), speed(3, 3.2)), step(1, 'active', distance(7000), speed(3.9, 4.15)), step(2, 'recovery', time(240)), step(3, 'active', distance(3000), speed(3.9, 4.15))]
    const executed = [...laps([[0, 'warmup', 3, 320, 1000], [1, 'active', 7, 250, 1000], [2, 'recovery', 1, 240, 500], [3, 'active', 1, 250, 1000]]), lap({ trigger: 'session_end', startOffset: 4130, timerSeconds: 2, distance: 4 })]
    const blocks = buildBlocks(structure(steps, executed, 'Fartlek sintético'), null)
    expect(blocks.map((b) => b.kind)).toEqual(['warmup', 'active', 'recovery', 'active'])
    expect(blocks.map((b) => b.label)).toEqual(['Aquecimento', 'Bloco 1', 'Recuperação 1', 'Bloco 2'])
    expect([blocks[1]?.laps.length, blocks[1]?.distance, blocks[1]?.seconds, blocks[1]?.prescribed?.index]).toEqual([7, 7000, 1750, 1])
    expect(blocks.map((b) => b.status)).toEqual(['inTarget', 'inTarget', 'noTarget', 'incomplete'])
    expect(blocks.every((b) => b.dominantZone === null)).toBe(true)
    expect(hasPrescription(structure(steps, executed))).toBe(true)
  })

  it('desenrola repetições', () => {
    const steps = [step(0, 'warmup', time(600)), step(1, 'active', distance(800), speed(4.4, 4.7)), step(2, 'recovery', time(120)), step(3, 'active', repeat(1, 6)), step(4, 'cooldown', time(600))]
    const plan: Plan[] = [[0, 'warmup', 1, 600, 1800]]
    for (let i = 0; i < 6; i += 1) plan.push([1, 'active', 1, 176, 800], [2, 'recovery', 1, 120, 250])
    plan.push([4, 'cooldown', 1, 600, 1700])
    const blocks = buildBlocks(structure(steps, laps(plan)), null)
    const active = blocks.filter((b) => b.kind === 'active')
    expect(blocks).toHaveLength(14)
    expect([blocks[0]?.label, blocks.at(-1)?.label]).toEqual(['Aquecimento', 'Desaquecimento'])
    expect(active.map((b) => b.label)).toEqual(range(6, 'Tiro'))
    expect(blocks.filter((b) => b.kind === 'recovery').map((b) => b.label)).toEqual(range(6, 'Recuperação'))
    expect(active.map((b) => b.ordinal)).toEqual([1, 2, 3, 4, 5, 6])
    expect(blocks.every((b) => b.prescribed?.index !== 3)).toBe(true)
    expect(active.every((b) => b.status === 'inTarget' && b.laps.length === 1)).toBe(true)
  })

  it('status contra alvo de pace e velocidade como distância sobre tempo', () => {
    const status = (seconds: number, meters: number) => buildBlocks(singleStep(speed(3.9, 4.15), seconds, meters), null)[0]?.status
    expect([status(250, 1000), status(1000, 4300), status(1000, 3700), status(1000, 3900), status(1000, 4150)]).toEqual(['inTarget', 'faster', 'slower', 'inTarget', 'inTarget'])
    expect(buildBlocks(singleStep(speed(3.9, 4.15), 250, 1000), null)[0]?.avgSpeed).toBe(4)
    const block = buildBlocks(structure([step(0, 'active', openDuration, speed(3.9, 4.15))], laps([[0, 'active', 1, 200, 1000], [0, 'active', 1, 300, 1000]])), null)[0]
    expect([block?.seconds, block?.distance, block?.avgSpeed, block?.status]).toEqual([500, 2000, 4, 'inTarget'])
  })

  it('status contra zona, bpm e % da máxima', () => {
    const status = (target: StepTarget, heartRate: number, z: HeartRateZones | null) => buildBlocks(singleStep(target, 600, 2000, heartRate), z)[0]?.status
    expect([status(hrZone(2), 130, zones), status(hrZone(2), 150, zones), status(hrZone(2), 110, zones), status(hrZone(2), 120, zones), status(hrZone(2), 139, zones), status(hrZone(2), 140, zones), status(hrZone(5), 210, zones), status(hrZone(2), 130, null)])
      .toEqual(['inTarget', 'aboveTarget', 'belowTarget', 'inTarget', 'inTarget', 'aboveTarget', 'inTarget', 'noTarget'])
    expect([status(bpm(145, 160), 145, null), status(bpm(145, 160), 160, null), status(bpm(145, 160), 161, null), status(bpm(145, 160), 144, null)]).toEqual(['inTarget', 'inTarget', 'aboveTarget', 'belowTarget'])
    expect([status(percentMax(70, 80), 140, zones), status(percentMax(70, 80), 160, zones), status(percentMax(70, 80), 120, zones), status(percentMax(70, 80), 140, { floors: zones.floors, maxHeartRate: null })]).toEqual(['inTarget', 'aboveTarget', 'belowTarget', 'noTarget'])
  })

  it('FC ponderada pelo tempo dá a zona dominante', () => {
    const s = structure([step(0, 'active', openDuration)], [lap({ stepIndex: 0, startOffset: 0, timerSeconds: 300, distance: 1000, avgHeartRate: 130, maxHeartRate: 140 }), lap({ stepIndex: 0, startOffset: 300, timerSeconds: 100, distance: 400, avgHeartRate: 170, maxHeartRate: 178 })])
    const block = buildBlocks(s, zones)[0]
    expect([block?.avgHeartRate, block?.maxHeartRate, block?.dominantZone, block?.status]).toEqual([140, 178, 3, 'noTarget'])
    expect(buildBlocks(s, null)[0]?.dominantZone).toBeNull()
  })

  it('incompleto, não executado e limite de 95%', () => {
    const steps = [step(0, 'warmup', distance(1000)), step(1, 'active', distance(2000), speed(3.9, 4.15)), step(2, 'recovery', time(120)), step(3, 'cooldown', distance(1000))]
    const blocks = buildBlocks(structure(steps, laps([[0, 'warmup', 1, 320, 1000], [1, 'active', 1, 300, 1200]])), null)
    expect(blocks.map((b) => b.status)).toEqual(['noTarget', 'incomplete', 'notExecuted', 'notExecuted'])
    expect([blocks[2]?.laps, blocks[3]?.laps]).toEqual([[], []])
    expect(blocks.map((b) => b.label)).toEqual(['Aquecimento', 'Bloco 1', 'Recuperação 1', 'Desaquecimento'])
    const two = [step(0, 'active', distance(1000)), step(1, 'recovery', time(100))]
    expect(buildBlocks(structure(two, laps([[0, 'active', 1, 240, 950], [1, 'recovery', 1, 95, 200]])), null).map((b) => b.status)).toEqual(['noTarget', 'noTarget'])
    expect(buildBlocks(structure(two, laps([[0, 'active', 1, 240, 949], [1, 'recovery', 1, 94, 200]])), null).map((b) => b.status)).toEqual(['incomplete', 'incomplete'])
  })

  it('descarta volta de fim de sessão e volta curta sem passo', () => {
    const steps = [step(0, 'active', distance(2000))]
    const blocks = buildBlocks(structure(steps, [...laps([[0, 'active', 2, 250, 1000]]), lap({ trigger: 'session_end', startOffset: 500, timerSeconds: 2, distance: 4 })]), null)
    expect([blocks.length, blocks[0]?.laps.length, blocks[0]?.distance]).toEqual([1, 2, 2000])
    const short = buildBlocks(structure(steps, [...laps([[0, 'active', 2, 250, 1000]]), lap({ trigger: 'manual', startOffset: 500, timerSeconds: 6, distance: 15 })]), null)
    expect([short.length, short[0]?.distance]).toEqual([1, 2000])
  })

  it('corrida livre usa as voltas', () => {
    const s = structure(null, laps([[null, null, 5, 300, 1000]]))
    const blocks = buildBlocks(s, zones)
    expect(blocks).toHaveLength(5)
    expect(blocks.every((b) => b.kind === 'active' && b.status === 'noTarget' && b.laps.length === 1)).toBe(true)
    expect(blocks.map((b) => b.label)).toEqual(range(5, 'Volta'))
    expect(blocks.map((b) => b.ordinal)).toEqual([1, 2, 3, 4, 5])
    expect(blocks[0]?.dominantZone).toBe(3)
    expect(hasPrescription(s)).toBe(false)
  })

  it('passo pulado vira não executado', () => {
    const blocks = buildBlocks(structure([step(0, 'warmup', openDuration), step(1, 'active', openDuration), step(2, 'rest', openDuration)], laps([[0, 'warmup', 1, 300, 1000], [2, 'rest', 1, 120, 300]])), null)
    expect(blocks.map((b) => b.status)).toEqual(['noTarget', 'notExecuted', 'noTarget'])
    expect(blocks.map((b) => b.label)).toEqual(['Aquecimento', 'Bloco 1', 'Recuperação 1'])
    expect(blocks[2]?.kind).toBe('recovery')
  })

  it('repetição de passo único', () => {
    const repeatOf = (lastRepMeters: number) =>
      structure([step(0, 'warmup', time(600)), step(1, 'active', distance(800), speed(4.4, 4.7)), step(2, 'active', repeat(1, 6)), step(3, 'cooldown', time(600))], laps([[0, 'warmup', 1, 600, 1800], [1, 'active', 5, 176, 805], [1, 'active', 1, lastRepMeters / 4.5, lastRepMeters], [3, 'cooldown', 1, 600, 1700]]))
    const blocks = buildBlocks(repeatOf(800), null)
    expect(blocks.map((b) => b.label)).toEqual(['Aquecimento', ...range(6, 'Tiro'), 'Desaquecimento'])
    const tiros = blocks.filter((b) => b.kind === 'active')
    expect(tiros.every((b) => b.laps.length === 1 && b.distance >= 800 && b.distance <= 805 && b.status === 'inTarget')).toBe(true)
    const short = buildBlocks(repeatOf(500), null).filter((b) => b.kind === 'active')
    expect(short).toHaveLength(6)
    expect(short.slice(0, 5).every((b) => b.status === 'inTarget')).toBe(true)
    expect([short[5]?.distance, short[5]?.status]).toEqual([500, 'incomplete'])
    const openRepeat = buildBlocks(structure([step(0, 'active', openDuration), step(1, 'active', repeat(0, 3))], laps([[0, 'active', 4, 60, 250]])), null)
    expect(openRepeat.map((b) => b.label)).toEqual(['Tiro 1', 'Tiro 2', 'Tiro 3'])
    expect(openRepeat.map((b) => b.laps.length)).toEqual([1, 1, 2])
  })

  it('alvo de um lado só ignora o limite que falta', () => {
    const status = (target: StepTarget, meters = 1000, heartRate: number | null = 150): BlockStatus | undefined => buildBlocks(singleStep(target, 250, meters, heartRate), zones)[0]?.status
    expect([status(speed(3.3, 0)), status(speed(3.3, 0), 750), status(speed(0, 4.5)), status(speed(0, 3.5)), status(bpm(0, 160)), status(bpm(0, 140)), status(bpm(145, 0), 1000, 170), status(percentMax(0, 80))])
      .toEqual(['inTarget', 'slower', 'inTarget', 'faster', 'inTarget', 'aboveTarget', 'inTarget', 'inTarget'])
  })

  it('volta sem passo depois do último passo vira volta extra', () => {
    const steps = [step(0, 'warmup', distance(3000)), step(1, 'active', distance(6000), speed(3.9, 4.2)), step(2, 'recovery', time(240)), step(3, 'active', distance(3000), speed(4.2, 4.3))]
    const executed = [
      ...laps([[0, 'warmup', 3, 310, 1000], [1, 'active', 6, 245, 1000], [2, 'recovery', 1, 240, 100], [3, 'active', 3, 233, 1000]]),
      lap({ trigger: 'manual', startOffset: 3000, timerSeconds: 631, distance: 1000, avgSpeed: 1000 / 631, avgHeartRate: 98 }),
      lap({ trigger: 'manual', startOffset: 3631, timerSeconds: 300, distance: 500, avgSpeed: 500 / 300, avgHeartRate: 95 }),
    ]
    const blocks = buildBlocks(structure(steps, executed), null)
    expect(blocks.map((b) => b.label)).toEqual(['Aquecimento', 'Bloco 1', 'Recuperação 1', 'Bloco 2', 'Volta extra 1', 'Volta extra 2'])
    expect(blocks[3]).toMatchObject({ distance: 3000, status: 'inTarget' })
    expect(blocks[4]).toMatchObject({ kind: 'cooldown', status: 'noTarget', distance: 1000 })
  })

  it('volta sem passo no meio do treino continua no bloco anterior', () => {
    const steps = [step(0, 'active', distance(2000)), step(1, 'recovery', time(120))]
    const executed = [...laps([[0, 'active', 1, 250, 1000]]), lap({ trigger: 'manual', startOffset: 250, timerSeconds: 250, distance: 1000 }), ...laps([[1, 'recovery', 1, 120, 300]])]
    const blocks = buildBlocks(structure(steps, executed), null)
    expect(blocks.map((b) => [b.label, b.distance])).toEqual([['Bloco 1', 2000], ['Recuperação 1', 300]])
  })

  it('treino que termina em repetição: volta sem passo no meio fica no bloco, no fim vira extra', () => {
    const steps = [step(0, 'active', distance(1000), speed(4, 4.4)), step(1, 'recovery', time(120)), step(2, 'active', repeat(0, 3))]
    const middle = [...laps([[0, 'active', 1, 240, 1000], [1, 'recovery', 1, 100, 250]]), lap({ trigger: 'manual', startOffset: 340, timerSeconds: 20, distance: 50 }), ...laps([[0, 'active', 1, 240, 1000], [1, 'recovery', 1, 120, 300], [0, 'active', 1, 240, 1000], [1, 'recovery', 1, 120, 300]])]
    const ending = [...middle, lap({ trigger: 'manual', startOffset: 2000, timerSeconds: 400, distance: 900 })]
    expect(buildBlocks(structure(steps, middle), null).map((b) => b.label)).toEqual(['Tiro 1', 'Recuperação 1', 'Tiro 2', 'Recuperação 2', 'Tiro 3', 'Recuperação 3'])
    expect(buildBlocks(structure(steps, middle), null)[1]).toMatchObject({ seconds: 120, distance: 300 })
    expect(buildBlocks(structure(steps, ending), null).map((b) => b.label).at(-1)).toBe('Volta extra 1')
  })
})
