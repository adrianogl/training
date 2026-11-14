import { FORMAT_TEXT, READINESS_LEVELS } from './constants'

const TIME_ZONE = 'America/Sao_Paulo'

export function todayLocal(date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date)
}

export function shiftDay(day: string, delta: number): string {
  const date = new Date(`${day}T12:00:00Z`)
  date.setUTCDate(date.getUTCDate() + delta)
  return date.toISOString().slice(0, 10)
}

export function weekStart(day: string): string {
  const weekday = new Date(`${day}T12:00:00Z`).getUTCDay()
  return shiftDay(day, -((weekday + 6) % 7))
}

export function km(meters: number | null): string {
  return meters === null ? '—' : `${(meters / 1000).toFixed(1).replace('.', ',')} km`
}

export function pace(speed: number | null): string {
  if (speed === null || speed <= 0) {
    return '—'
  }
  const seconds = Math.round(1000 / speed)
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}/km`
}

export function duration(seconds: number | null): string {
  if (seconds === null) {
    return '—'
  }
  const total = Math.round(seconds)
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const rest = total % 60
  return hours > 0 ? `${hours}:${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}` : `${minutes}:${String(rest).padStart(2, '0')}`
}

export function hoursMinutes(seconds: number): string {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.round((seconds % 3600) / 60)
  return `${hours}h${String(minutes).padStart(2, '0')}`
}

export function longDate(day: string): string {
  return new Date(`${day}T12:00:00Z`).toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' })
}

export function shortDate(day: string): string {
  return new Date(`${day}T12:00:00Z`).toLocaleDateString('pt-BR', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' })
}

export function readinessLabel(level: string | null, score: number): string {
  if (level !== null && READINESS_LEVELS[level] !== undefined) {
    return READINESS_LEVELS[level] ?? ''
  }
  return score >= 70 ? FORMAT_TEXT.hard : score >= 40 ? FORMAT_TEXT.moderate : FORMAT_TEXT.rest
}

export function readinessColor(score: number): string {
  return score >= 70 ? 'var(--accent)' : score >= 40 ? 'var(--amber)' : 'var(--rest)'
}

export function isRun(activity: { type: string }): boolean {
  return activity.type.includes('running')
}

export function signedDuration(seconds: number): string {
  return `${seconds < 0 ? '−' : '+'}${duration(Math.abs(seconds))}`
}

export function dayMonth(day: string): string {
  return new Date(`${day}T12:00:00Z`).toLocaleDateString('pt-BR', { day: 'numeric', month: 'short', timeZone: 'UTC' }).replace('.', '').replace(' de ', ' ')
}

export function signedNumber(value: number, digits = 0): string {
  const rounded = Math.abs(value).toFixed(digits).replace('.', ',')
  return `${value < 0 ? '−' : '+'}${rounded}`
}
