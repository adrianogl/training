import { describe, expect, it } from 'vitest'
import type { Effort, KmPlan, ProfilePoint, SeriesPoint } from '../src/domain/domainTypes.js'
import { bestEfforts, predict, predictionSeries, riegel } from '../src/domain/prediction.js'
import { project } from '../src/domain/projection.js'
import { assessGoal, longRunTarget, raceBlock, raceOutlook, strategyTarget } from '../src/domain/race.js'
import { encodeManualPaces, gpxPoints, gpxProfile, kmLength, manualPaces, paceStrategy } from '../src/domain/raceStrategy.js'
import { weekStartOf } from '../src/domain/today.js'
import { addDays } from '../src/garminSync.js'

const metricsToday = '2026-11-04'
const total = (plan: KmPlan[], distance: number) => plan.reduce((sum, item) => sum + (item.pace * kmLength(item.index, Math.ceil(distance / 1000), distance)) / 1000, 0)
const strategy = (goal: number, distance: number, profile: [number, number][] | null, manual: [number, number][] = []) =>
  paceStrategy(goal, distance, profile?.map(([d, a]): ProfilePoint => ({ distance: d, altitude: a })) ?? null, new Map(manual))

describe('projeção (paridade com o Swift)', () => {
  const today = '2026-11-01'
  const linear = (count = 90, start = 40, slope = 0.1): SeriesPoint[] => Array.from({ length: count }, (_, i) => [addDays(today, -(count - 1) + i), start + i * slope])
  const pattern = [1, -2, 0.5, 2, -1.5, 0, 1.5, -0.5]
  const noisy: SeriesPoint[] = Array.from({ length: 90 }, (_, i) => [addDays(today, -89 + i), 40 + i * 0.1 + (pattern[i % pattern.length] ?? 0)])

  it('linha reta e faixa', () => {
    const p = project(linear(), today, 30)
    expect(p?.points).toHaveLength(30)
    expect(p?.points[0]?.day).toBe(addDays(today, 1))
    expect(p?.points.at(-1)?.mid).toBeCloseTo(51.9, 2)
    expect((p?.points.at(-1)?.high ?? 1) - (p?.points.at(-1)?.low ?? 0)).toBeLessThan(0.01)
    const wide = project(noisy, today, 60)
    const first = wide?.points[0]
    const last = wide?.points[59]
    expect((last?.high ?? 0) - (last?.low ?? 0)).toBeGreaterThan((first?.high ?? 0) - (first?.low ?? 0))
  })

  it('pontos mínimos, horizonte zero, janela e futuro', () => {
    expect(project(linear().slice(-9), today, 30)).toBeNull()
    expect(project(linear().slice(-10), today, 30)).not.toBeNull()
    expect(project(linear(), today, 0)).toBeNull()
    expect(project([...linear(), ...Array.from({ length: 30 }, (_, i): SeriesPoint => [addDays(today, -200 + i), 1000])], today, 30)?.points.at(-1)?.mid).toBeCloseTo(51.9, 2)
    expect(project([...linear(), ...Array.from({ length: 20 }, (_, i): SeriesPoint => [addDays(today, i + 1), 1000])], today, 30)?.points.at(-1)?.mid).toBeCloseTo(51.9, 2)
    expect(project(Array.from({ length: 20 }, (_, i): SeriesPoint => [today, 40 + i]), today, 30)).toBeNull()
  })

  it('cruzamento da meta', () => {
    const s: SeriesPoint[] = Array.from({ length: 90 }, (_, i) => [addDays(today, -89 + i), 6510 - 2 * (i - 89)])
    expect(project(s, today, 120, null, 6300)?.targetCrossing).toBe(addDays(today, 105))
    expect(project(linear(), today, 60, null, 30)?.targetCrossing).toBeNull()
    expect(project(linear(), today, 30, null, 48.9)?.targetCrossing).toBe(today)
    expect(project(linear(), today, 30, null, null, 60)?.points[0]?.mid).toBeCloseTo(60.1, 9)
    expect(project(linear(), today, 30, null, null, 60)?.points.at(-1)?.mid).toBeCloseTo(63, 9)
    expect(project(Array.from({ length: 90 }, (_, i): SeriesPoint => [addDays(today, -89 + i), 80 - i * 0.1]), today, 30, null, null, 60)?.points.every((point) => point.mid < 60)).toBe(true)
    const flat = project(Array.from({ length: 30 }, (_, i): SeriesPoint => [addDays(today, -29 + i), 50]), today, 30, null, 60)
    expect(flat?.targetCrossing).toBeNull()
  })

  it('teto suave', () => {
    expect(project(linear(), today, 60)?.points.at(-1)?.mid).toBeCloseTo(54.9, 2)
    const capped = project(linear(), today, 60, 52)
    expect(capped?.points.at(-1)?.mid).toBeCloseTo(53.45, 2)
    const step = project(linear(90, 40, 1), today, 2, 129.5)
    expect(step?.points[0]?.mid).toBeCloseTo(129.75, 9)
    expect(step?.points[1]?.mid).toBeCloseTo(130.25, 9)
  })
})

describe('métricas de prova (paridade com o Swift)', () => {
  it('meta e longão', () => {
    expect([assessGoal(6300, 6510), assessGoal(6000, 6510), assessGoal(6500, 6510)]).toEqual(['challenging', 'aggressive', 'easy'])
    expect([assessGoal(6300, 0), assessGoal(0, 6510), assessGoal(Number.NaN, 6510)]).toEqual([null, null, null])
    expect([longRunTarget(10000), longRunTarget(21097.5), longRunTarget(42195)]).toEqual([10000, 21097.5 * 0.9, 42195 * 0.75])
  })

  it('estratégia plana bate a meta com aquecimento e final', () => {
    const p = strategy(6300, 21097.5, null)
    expect(p).toHaveLength(22)
    expect(total(p, 21097.5)).toBeCloseTo(6300, 0)
    expect((p[0]?.pace ?? 0) - (p[10]?.pace ?? 0)).toBeGreaterThan(4.9)
    expect([p[0]?.label, p.at(-1)?.label, p[10]?.label, p[19]?.label, p[18]?.label]).toEqual(['aquece', 'final', 'plano', 'final', 'plano'])
  })

  it('pace manual fica e o resto compensa', () => {
    const p = strategy(6300, 21097.5, null, [[5, 300]])
    expect(p[5]).toMatchObject({ pace: 300, manual: true })
    expect(p[4]?.manual).toBe(false)
    expect(total(p, 21097.5)).toBeCloseTo(6300, 6)
    expect(strategy(1500, 5000, null, [[0, 600], [1, 600], [2, 600]])).toEqual([])
    const outside = strategy(1500, 5000, null, [[-1, 100], [7, 100]])
    expect(outside.every((item) => !item.manual)).toBe(true)
    expect(total(outside, 5000)).toBeCloseTo(1500, 6)
    expect(strategy(1500, 5000, null, [0, 1, 2, 3, 4].map((i) => [i, i === 2 ? 0 : 300]))).toEqual([])
  })

  it('perfil marca subida e descida e limita a inclinação', () => {
    const p = strategy(3000, 10000, [[0, 100], [4000, 100], [5000, 150], [6000, 100], [10000, 100]])
    expect(p).toHaveLength(10)
    expect(p[4]?.grade).toBeCloseTo(0.05, 9)
    expect([p[4]?.label, p[5]?.label, p[3]?.label]).toEqual(['subida', 'descida', 'plano'])
    expect(p[4]!.pace).toBeGreaterThan(p[3]!.pace)
    expect(p[5]!.pace).toBeLessThan(p[3]!.pace)
    expect(total(p, 10000)).toBeCloseTo(3000, 6)
    const wall = strategy(1800, 5000, [[0, 100], [1000, 100], [2000, 900], [5000, 900]])
    const steep = strategy(1800, 5000, [[0, 100], [1000, 100], [2000, 550], [5000, 550]])
    expect(wall[1]?.grade).toBeCloseTo(0.8, 9)
    expect(wall[1]?.pace).toBeCloseTo(steep[1]?.pace ?? 0, 9)
  })

  it('bloco projeta as semanas futuras', () => {
    const week = weekStartOf(metricsToday)
    const km = new Map<string, number>()
    ;[20, 22, 24, 26, 28, 30].forEach((value, i) => km.set(addDays(week, -7 * (6 - i)), value))
    km.set(week, 12)
    const block = raceBlock(addDays(metricsToday, 42), metricsToday, km)
    expect(block).toHaveLength(12)
    expect(block.at(-1)?.start).toBe(weekStartOf(addDays(metricsToday, 42)))
    expect(block[0]?.start).toBe(addDays(week, -35))
    const projected = block.filter((item) => item.projected)
    expect(projected.length).toBe(6)
    expect(projected.every((item) => item.km === 27)).toBe(true)
    expect(block[5]).toEqual({ start: week, km: 12, projected: false })
    expect(block[0]?.km).toBe(22)
  })

  it('bloco de prova distante e de prova passada', () => {
    const km = new Map<string, number>()
    for (let offset = 1; offset <= 4; offset += 1) km.set(addDays(weekStartOf(metricsToday), -7 * offset), 40)
    expect(raceBlock(addDays(metricsToday, 140), metricsToday, km).every((item) => item.projected && item.km === 40)).toBe(true)
    const race = addDays(metricsToday, -30)
    const past = raceBlock(race, metricsToday, new Map([[weekStartOf(race), 21]]))
    expect(past.every((item) => !item.projected)).toBe(true)
    expect(past.at(-1)).toEqual({ start: weekStartOf(race), km: 21, projected: false })
  })

  it('provas: janela de 365 dias e distância mais próxima', () => {
    const at = (offset: number) => addDays(metricsToday, offset)
    expect(predict(10000, [{ distance: 10000, seconds: 2700, day: at(-300), kind: 'race' }], metricsToday)).not.toBeNull()
    expect(predict(10000, [{ distance: 5000, seconds: 1200, day: at(-300), kind: 'split5k' }], metricsToday)).toBeNull()
    const fastTen: Effort = { distance: 10000, seconds: 2400, day: at(-200), kind: 'race' }
    const marathon: Effort = { distance: 42195, seconds: 11600, day: at(-100), kind: 'race' }
    expect(bestEfforts([fastTen, marathon], 42195, metricsToday)).toEqual([marathon])
    expect(bestEfforts([fastTen, marathon], 10000, metricsToday)).toEqual([fastTen])
    const slower: Effort = { distance: 10080, seconds: 2460, day: at(-200), kind: 'race' }
    const faster: Effort = { distance: 10030, seconds: 2440, day: at(-170), kind: 'race' }
    expect(bestEfforts([slower, faster, marathon], 10000, metricsToday)).toEqual([faster])
  })
})

describe('panorama da prova (paridade com o Swift)', () => {
  const today = '2026-11-12'
  const improving = (over = 120, todaySplit = 1500, slope = 2): Effort[] => {
    const list: Effort[] = []
    for (let offset = over; offset >= 0; offset -= 2) list.push({ distance: 5000, seconds: todaySplit + slope * offset, day: addDays(today, -offset), kind: 'split5k' })
    return list
  }

  it('cruza a meta depois da prova', () => {
    const outlook = raceOutlook(5000, addDays(today, 30), 1400, improving(), today)
    expect(outlook.raceDay?.day).toBe(addDays(today, 30))
    expect(Math.abs((outlook.raceDay?.mid ?? 0) - 1440)).toBeLessThan(5)
    expect(outlook.projection.at(-1)?.day).toBe(outlook.raceDay?.day)
    expect(outlook.goalCrossing.kind).toBe('on')
    const crossing = outlook.goalCrossing.kind === 'on' ? outlook.goalCrossing.day : today
    expect(crossing > (outlook.raceDay?.day ?? '')).toBe(true)
    expect(outlook.assessment).toBe('challenging')
    expect(outlook.today).toBeCloseTo(1500, 6)
    expect(outlook.series.at(-1)?.[0]).toBe(today)
    expect(outlook.longProjection).toHaveLength(365)
    expect(outlook.projection).toHaveLength(30)
  })

  it('meta já batida, inalcançável e prova hoje', () => {
    expect(raceOutlook(5000, addDays(today, 30), 1550, improving(), today)).toMatchObject({ goalCrossing: { kind: 'alreadyBeaten' }, assessment: 'easy' })
    expect(raceOutlook(5000, addDays(today, 30), 1100, improving(120, 1500, -2), today)).toMatchObject({ goalCrossing: { kind: 'unreachable' }, assessment: 'aggressive' })
    const onDay = raceOutlook(5000, today, 1400, improving(), today)
    expect(onDay.raceDay?.mid).toBe(onDay.today)
    expect(onDay.projection).toEqual([])
  })

  it('sem prova usa a meia', () => {
    const outlook = raceOutlook(0, null, null, improving(400), today)
    expect([outlook.distance, outlook.label, outlook.goalSeconds, outlook.raceDay, outlook.assessment]).toEqual([21097.5, '21,1 km', null, null, null])
    expect(outlook.goalCrossing).toEqual({ kind: 'noGoal' })
    expect(outlook.projection.length).toBeGreaterThan(0)
    expect(outlook.today).toBeCloseTo(riegel(1500, 5000, 21097.5), 6)
    expect(outlook.yearAgo).toBeCloseTo(riegel(1500 + 2 * 366, 5000, 21097.5), 6)
    expect(raceOutlook(5000, null, null, [], today).longProjection).toEqual([])
  })

  it('alvo da estratégia: congelado, dia da prova, hoje, meta', () => {
    const outlook = raceOutlook(5000, addDays(today, 30), 1400, improving(), today)
    expect(strategyTarget({ frozenTargetSeconds: 1450, frozenTargetDay: '2026-11-11' }, outlook)).toEqual({ seconds: 1450, source: 'frozen', frozenOn: '2026-11-11' })
    expect(strategyTarget({}, outlook)?.source).toBe('raceDayProjection')
    expect(strategyTarget({ goalSeconds: 1400 }, raceOutlook(5000, addDays(today, 30), 1400, [], today))).toEqual({ seconds: 1400, source: 'goal', frozenOn: null })
    expect(strategyTarget({}, raceOutlook(5000, null, null, [], today))).toBeNull()
  })

  it('série de previsão igual em blocos ou direto', () => {
    expect(predictionSeries(10000, improving(), addDays(today, -30), today).length).toBeGreaterThan(0)
  })
})

describe('GPX e paces manuais', () => {
  it('lê pontos com altitude e calcula a distância acumulada', () => {
    const xml = '<gpx><trk><trkseg><trkpt lat="-19.9" lon="-43.9"><ele>850</ele></trkpt><trkpt lat="-19.91" lon="-43.9"><ele>860.5</ele></trkpt><trkpt lat="-19.92" lon="-43.9"/></trkseg></trk></gpx>'
    const points = gpxPoints(xml)
    expect(points).toHaveLength(2)
    const profile = gpxProfile(points)
    expect(profile[0]).toEqual({ distance: 0, altitude: 850 })
    expect(profile[1]?.distance).toBeCloseTo(1112, -1)
  })

  it('paces manuais no formato do JSONEncoder do Swift', () => {
    const swift = Buffer.from(JSON.stringify([5, 300, 12, 280.5])).toString('base64')
    expect([...manualPaces(swift).entries()]).toEqual([[5, 300], [12, 280.5]])
    expect(manualPaces(encodeManualPaces(new Map([[3, 290]])))).toEqual(new Map([[3, 290]]))
    expect(manualPaces(null).size).toBe(0)
    expect(encodeManualPaces(new Map())).toBeNull()
  })
})
