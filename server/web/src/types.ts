export interface User {
  email: string
  name: string
  emailVerified: boolean
  role: 'member' | 'guest'
  admin: boolean
}

export interface AuthResult {
  token: string
  user: User
}

export interface SessionInfo {
  id: string
  device: string
  lastSeenAt: string
  current: boolean
}

export type ApiResult<T> = { ok: true; value: T } | { ok: false; error: string; status: number }

export type Route =
  | 'login'
  | 'signup'
  | 'forgot'
  | 'reset'
  | 'confirm'
  | 'today'
  | 'workouts'
  | 'races'
  | 'goals'
  | 'evolution'
  | 'settings'
  | 'password'
  | 'admin'
  | 'invite'

export interface NavItem {
  route: Route
  label: string
  icon: string
}

export interface GarminStatus {
  connected: boolean
  connectedAt: string | null
}

export interface GarminStep {
  status: 'connected' | 'needs_code'
  method?: string
}

export type GarminModalStep = 'credentials' | 'code' | 'done'

export type InviteChannel = 'email' | 'whatsapp' | 'link'

export interface InviteRow {
  id: string
  name: string
  email: string | null
  channel: InviteChannel
  status: 'pending' | 'accepted' | 'expired' | 'canceled'
  createdAt: string
  expiresAt: string
  acceptedAt: string | null
}

export interface InviteResult {
  invite: InviteRow
  link: string
  message: string
  mailed: boolean
}

export interface InvitePreview {
  name: string
  email: string | null
  inviterName: string | null
  expiresAt: string
}

export interface AdminUser {
  id: string
  name: string
  email: string
  role: 'member' | 'guest'
  admin: boolean
  garminConnected: boolean
  lastSeenAt: string | null
  dataBytes: number
}

export interface AdminOverview {
  accounts: number
  maxAccounts: number
  pendingInvites: number
  expiringInvites: number
  activeAccounts: number
  garminConnected: number
  requests24h: number
  errors24h: number
  requestsByHour: { hour: string; count: number }[]
  requestsByRoute: { route: string; count: number }[]
  databaseBytes: number | null
}

export interface InviteRequest {
  id: string
  name: string
  email: string
  watch: 'garmin' | 'other' | 'none'
  message: string
  createdAt: string
}

export interface AdminData {
  overview: AdminOverview
  users: AdminUser[]
  invites: InviteRow[]
  requests: InviteRequest[]
}

export interface HealthDay {
  day: string
  restingHeartRate: number | null
  averageStress: number | null
  steps: number | null
  bodyBattery: { highest: number | null; lowest: number | null; atWake: number | null; charged: number | null; drained: number | null }
  sleep: { seconds: number; score: number | null; deep: number; light: number; rem: number; awake: number; start: string | null; end: string | null } | null
  hrv: { lastNight: number | null; weeklyAvg: number | null; status: string | null; lowUpper: number | null; balancedLow: number | null; balancedUpper: number | null } | null
  readiness: { score: number; level: string | null; sleepScore: number | null; recoveryMinutes: number | null; acuteLoad: number | null } | null
}

export interface Activity {
  id: number
  name: string
  type: string
  startLocal: string
  day: string
  distanceMeters: number | null
  durationSeconds: number | null
  movingSeconds: number | null
  elevationGain: number | null
  averageSpeed: number | null
  maxSpeed: number | null
  averageHeartRate: number | null
  maxHeartRate: number | null
  cadence: number | null
  trainingLoad: number | null
  aerobicEffect: number | null
  anaerobicEffect: number | null
  vo2max: number | null
  zoneSeconds: number[]
  fastestKmSeconds: number | null
  laps: number | null
  workoutId: number | null
}

export interface SyncProgress {
  done: boolean
  days: number
  activities: number
  oldestDay: string | null
}

export type SyncState = { kind: 'idle' } | { kind: 'running'; days: number } | { kind: 'done'; at: Date } | { kind: 'error'; message: string } | { kind: 'disconnected' }

export interface ReadinessFactor {
  component: 'hrv' | 'sleep' | 'bodyBattery' | 'load'
  todayScore: number | null
  normalScore: number | null
  points: number | null
  weight: number
}

export interface TodaySummary {
  day: string
  readiness: { score: number; normal: number | null; verdict: 'rest' | 'moderate' | 'hard'; factors: ReadinessFactor[] } | null
  raw: {
    hrvLastNight: number | null
    hrvBalancedLow: number | null
    hrvBalancedUpper: number | null
    sleepScore: number | null
    sleepSeconds: number | null
    bodyBatteryMorningMax: number | null
    acuteChronic: number | null
    restingHeartRate: number | null
    stress: number | null
  }
  recoveryMinutes: number | null
  garminReadiness: number | null
  fitness: { fitness: number; fatigue: number; form: number } | null
  week: { perDay: Record<string, number>; total: number; lastWeek: number; average4Weeks: number; recentWeeks: { start: string; kilometers: number }[] }
  focus: { lowAerobic: number; highAerobic: number; anaerobic: number } | null
}

export type SeriesPoint = [string, number]

export interface MetricSeries {
  key: string
  points: SeriesPoint[]
  movingAverage: SeriesPoint[]
  stats: { current: number | null; average: number | null; minimum: number | null; maximum: number | null; change: number | null }
  band: [number, number] | null
}

export interface Prediction {
  key: string
  label: string
  seconds: number | null
  change: number | null
}

export interface Evolution {
  day: string
  periodDays: number
  series: MetricSeries[]
  weeks: { start: string; kilometers: number; zoneSeconds: number[] }[]
  predictions: Prediction[]
  records: {
    fastestKm: { seconds: number; day: string; name: string } | null
    fastest5k: { seconds: number; day: string; name: string } | null
    longestRun: { meters: number; day: string; name: string } | null
    biggestWeek: { kilometers: number; start: string } | null
    races: { key: string; seconds: number; day: string; name: string }[]
  }
}

export interface ProjectionPoint {
  day: string
  mid: number
  low: number
  high: number
}

export interface KmPlan {
  index: number
  pace: number
  grade: number
  label: string
  manual: boolean
}

export type ChecklistStatus = 'ok' | 'attention' | 'missing'

export type ChecklistItem =
  | { kind: 'weeklyVolume'; status: ChecklistStatus; targetKm: number; averageKm: number | null }
  | { kind: 'racePace'; status: ChecklistStatus; targetKm: number; doneKm: number; pace: number | null }
  | { kind: 'tuneUp'; status: ChecklistStatus; distanceKm: number; best: { day: string; km: number; pace: number } | null }
  | { kind: 'course'; status: ChecklistStatus; km: number | null; gain: number | null }
  | { kind: 'goal'; status: ChecklistStatus; goalSeconds: number | null; priority: string }

export interface RaceView {
  id: string
  locked: boolean
  name: string | null
  day: string | null
  startTime: string | null
  distance: number | null
  goalSeconds: number | null
  priority: string | null
  city: string | null
  hasCourse: boolean
  manualPaces: [number, number][]
  status: 'upcoming' | 'done' | 'locked'
  daysUntil: number | null
  result: { activityId: number; seconds: number; distance: number; day: string } | null
  outlook: {
    distance: number
    label: string
    today: number | null
    raceDay: ProjectionPoint | null
    series: SeriesPoint[]
    projection: ProjectionPoint[]
    goalSeconds: number | null
    goalCrossing: { kind: 'on'; day: string } | { kind: 'alreadyBeaten' } | { kind: 'unreachable' } | { kind: 'noGoal' }
    assessment: 'easy' | 'challenging' | 'aggressive' | null
  } | null
  strategy: {
    target: { seconds: number; source: 'raceDayProjection' | 'todayPrediction' | 'goal' | 'frozen'; frozenOn: string | null } | null
    heat: { weather: { hour: number; temperature: number; dewPoint: number }; sumFahrenheit: number; fraction: number; tooHot: boolean; adjustedSeconds: number } | null
    weatherNote: 'tooFar' | 'noLocation' | 'unavailable' | null
    kms: KmPlan[]
  } | null
  block: { start: string; km: number; projected: boolean }[]
  checklist: ChecklistItem[]
}

export interface RaceInput {
  name: string
  day: string
  distance: number
  goalSeconds: number | null
  priority: string
  startTime: string | null
  city: string | null
}

export type BlockStatus = 'inTarget' | 'faster' | 'slower' | 'aboveTarget' | 'belowTarget' | 'noTarget' | 'incomplete' | 'notExecuted'

export interface WorkoutBlock {
  kind: 'warmup' | 'active' | 'recovery' | 'cooldown'
  ordinal: number
  label: string
  seconds: number
  distance: number
  avgSpeed: number | null
  avgHeartRate: number | null
  maxHeartRate: number | null
  dominantZone: number | null
  status: BlockStatus
}

export interface NarratedFinding {
  group: 'positive' | 'negative' | 'attention'
  kind: string
  blockOrdinal: number | null
  text: string
  evidence: string | null
  why: string
}

export interface ScoreItem {
  part: 'execution' | 'intent' | 'cost'
  points: number
  maximum: number
  reason: string | null
}

export interface ComparisonRow {
  activityId: number
  day: string
  isCurrent: boolean
  secondsPerKilometer: number | null
  heartRate: number | null
  inTarget: { done: number; total: number } | null
}

export interface WorkoutAnalysisView {
  isRun: boolean
  hasPrescription: boolean
  workoutName: string | null
  zoneSeconds: number[] | null
  blocks: WorkoutBlock[]
  kilometers: { block: number; rows: WorkoutBlock[] }[]
  splits: WorkoutBlock[]
  findings: NarratedFinding[]
  score: { value: number; items: ScoreItem[] } | null
  comparison: { rows: ComparisonRow[]; notice: string | null; evolution: string | null } | null
}

export interface PlannedStep {
  kind: 'warmup' | 'active' | 'recovery' | 'cooldown' | 'rest' | 'other'
  seconds: number | null
  meters: number | null
  target: { kind: 'pace'; fastest: number; slowest: number } | { kind: 'heartRate'; low: number; high: number } | { kind: 'zone'; zone: number } | null
  repeats: number
  children: PlannedStep[]
}

export interface PlannedWorkout {
  id: number
  day: string
  title: string
  estimatedSeconds: number | null
  estimatedMeters: number | null
  steps: PlannedStep[]
}

export type WorkoutSelection = { kind: 'done'; id: number } | { kind: 'planned'; id: number; day: string }

export type GoalKind = 'time' | 'continuousLong'

export type GoalCrossingView = { kind: 'on'; day: string } | { kind: 'alreadyBeaten' } | { kind: 'unreachable' } | { kind: 'noGoal' }

export interface TimeGoalProgressView {
  kind: 'time'
  todaySeconds: number | null
  gapSeconds: number | null
  crossing: GoalCrossingView
  achievedOn: string | null
}

export interface LongRunCheckView {
  activityId: number
  day: string
  distanceKm: number
  longestContinuousKm: number | null
  pauses: { km: number; seconds: number }[] | null
  paceSecondsPerKm: number | null
  met: boolean | null
}

export interface LongGoalProgressView {
  kind: 'continuousLong'
  runs: LongRunCheckView[]
  metCount: number
  bestContinuousKm: number | null
  achievedOn: string | null
}

export interface GoalView {
  id: string
  kind: GoalKind
  distanceKm: number
  targetSeconds: number | null
  deadline: string | null
  paceSecondsPerKm: number | null
  archived: boolean
  achievedAt: string | null
  createdAt: string
  updatedAt: string
  progress: TimeGoalProgressView | LongGoalProgressView | null
}

export interface GoalInput {
  kind: GoalKind
  distanceKm: number
  targetSeconds?: number
  deadline?: string | null
  paceSecondsPerKm?: number
  archived: boolean
}
