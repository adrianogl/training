import { describe, expect, it } from 'vitest'
import { duration, km, pace, readinessLabel, shiftDay, todayLocal, weekStart } from '../src/format'

describe('formatação', () => {
  it('pace, distância e tempo', () => {
    expect(pace(2.88)).toBe('5:47/km')
    expect(pace(null)).toBe('—')
    expect(km(9902.8)).toBe('9,9 km')
    expect(duration(3439)).toBe('57:19')
    expect(duration(5136)).toBe('1:25:36')
  })

  it('dias e semana começando na segunda', () => {
    expect(todayLocal(new Date('2026-11-15T01:00:00Z'))).toBe('2026-11-14')
    expect(weekStart('2026-11-14')).toBe('2026-11-09')
    expect(weekStart('2026-11-09')).toBe('2026-11-09')
    expect(shiftDay('2026-11-01', -1)).toBe('2026-10-31')
  })

  it('rótulo da prontidão pelo nível da Garmin ou pela nota', () => {
    expect(readinessLabel('LOW', 25)).toBe('Pegue leve hoje')
    expect(readinessLabel(null, 75)).toBe('Pode treinar forte')
    expect(readinessLabel(null, 50)).toBe('Treino moderado')
  })
})
