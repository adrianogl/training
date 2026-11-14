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

export const PREDICTION = {
  riegelExponent: 1.06,
  effortWindowDays: 150,
  raceEffortWindowDays: 365,
  kindWeight: { race: 1, split5k: 0.7, split1k: 0.3 },
  sameRaceDistanceLogTolerance: 0.1,
  distances: [
    { key: 'prediction5k', meters: 5000, label: '5 km' },
    { key: 'prediction10k', meters: 10000, label: '10 km' },
    { key: 'predictionHalf', meters: 21097.5, label: '21,1 km' },
    { key: 'predictionFull', meters: 42195, label: '42,2 km' },
  ],
} as const

export const EVOLUTION = {
  vo2SmoothingDays: 2,
  volumeWindowDays: 30,
  focusWindowDays: 28,
  movingAverageDays: 7,
  lowZoneCount: 2,
  raceDistanceTolerance: 0.02,
  intervalAnaerobicEffect: 2,
  periods: [42, 91, 182, 365],
  defaultPeriod: 91,
} as const

export const PROJECTION = {
  windowDays: 90,
  minimumPoints: 10,
  bandZ: 1.96,
  ceilingFactor: 0.5,
  targetTolerance: 1e-9,
} as const

export const RACE = {
  aggressiveGap: 0.06,
  challengingGap: 0.01,
  shortRaceLimit: 10_000,
  halfRaceLimit: 21_100,
  halfLongRunShare: 0.9,
  fullLongRunShare: 0.75,
  warmupKms: 2,
  warmupOffset: 5,
  finishKms: 3,
  finishOffset: -3,
  climbLabelGrade: 0.02,
  minettiGradeRange: [-0.45, 0.45],
  labels: { warmup: 'aquece', finish: 'final', climb: 'subida', descent: 'descida', flat: 'plano' },
  blockWeeks: 12,
  projectionWeeks: 4,
  earthRadiusMeters: 6_371_000,
  defaultRaceDistance: 21_097.5,
  yearDays: 365,
  goalHorizonDays: 365,
  raceProjectionFallbackDays: 60,
  distanceLabels: { 5000: '5 km', 10000: '10 km', 21097.5: '21,1 km', 42195: '42,2 km' } as Record<number, string>,
  kmSuffix: ' km',
} as const

export const HEAT = {
  bands: [
    [100, 0],
    [110, 0.005],
    [120, 0.01],
    [130, 0.02],
    [140, 0.03],
    [150, 0.045],
    [160, 0.06],
    [170, 0.08],
    [180, 0.1],
  ],
  maxSum: 180,
} as const

export const CHECKLIST = {
  weeklyVolumeTargets: [
    [5_500, 25],
    [11_000, 30],
    [22_000, 40],
    [Number.POSITIVE_INFINITY, 55],
  ],
  racePaceVolumeRatio: 0.7,
  racePaceFaster: 10,
  racePaceSlower: 5,
  fullSplitRatio: 0.99,
  tuneUpDistanceRatio: 0.95,
  tuneUpPaceMargin: 10,
  recentWeeks: 4,
} as const
