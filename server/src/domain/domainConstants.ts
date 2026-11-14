export const READINESS = {
  weights: { hrv: 0.35, sleep: 0.25, bodyBattery: 0.2, load: 0.2 },
  hrvLowEdgeScore: 60,
  hrvBalancedTopScore: 100,
  loadIdealLow: 0.8,
  loadIdealHigh: 1.3,
  loadZeroLow: 0.5,
  loadZeroHigh: 1.8,
  moderateThreshold: 40,
  hardThreshold: 70,
  bodyBatteryWindowMs: 3 * 3600 * 1000,
  normalMinimumDays: 14,
  normalWindowDays: 30,
  historyDays: 30,
} as const

export const COMPONENTS = ['hrv', 'sleep', 'bodyBattery', 'load'] as const

export const LOAD = {
  fitnessDays: 42,
  fatigueDays: 7,
  acuteDays: 7,
  chronicDays: 28,
} as const

export const LOAD_FOCUS_TARGET = { low: [0.6, 0.75], high: [0.2, 0.35], anaerobic: [0.05, 0.1] } as const

export const WEEK = { previousWeeks: 4, historyWeeks: 12, daysPerWeek: 7, metersPerKm: 1000 } as const
